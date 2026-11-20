const test = require("node:test");
const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const { MemoryDB } = require("../test-support/memory-db");
const { PAYMENT_PROVIDER, checkCheckoutTerms, createCheckoutSettlement } = require("../checkout-settlement");

const request = { orderId: "order-7", provider: "razorpay", paymentId: "pay/1" };
const { orderId, provider, paymentId } = request;
const orderPath = `checkout_orders/${orderId}`;
const terms = { orderId, provider, uid: "customer", merchantOrderRef: "merchant/order-7", amountMinor: 123, currency: "INR" };
const ms = Date.parse("2030-01-30T00:00:00Z");
const held = {
  ...terms, status: "HELD", clusterId: "gate", comboSelection: "B",
  serviceDates: ["2030-01-31", "2030-02-02"], hardExpiryDate: "2030-02-02", holdExpiresAtMs: ms + 1,
};
const capture = { ...terms, status: "CAPTURED", paymentId };
function setup({ order = held, lookupCapture = async () => capture, rows = {} } = {}) {
  const db = new MemoryDB({ [orderPath]: order, ...rows });
  const clock = { ms };
  const settle = createCheckoutSettlement({ db, lookupCapture, now: () => clock.ms, serverTimestamp: () => "stamp" });
  return { db, clock, settle };
}

test("hold writer and settlement share strict term validation independent of lifecycle", () => {
  const { status, ...draft } = held;
  assert.doesNotThrow(() => checkCheckoutTerms(draft));
  for (const patch of [{ orderId: "../other" }, { provider: "" }, { merchantOrderRef: null },
    { uid: "customer " }, { amountMinor: 1.5 }, { amountMinor: 0 }, { currency: ["INR"] },
    { serviceDates: ["2030-01-31T12:00:00Z"] }]) {
    assert.throws(() => checkCheckoutTerms({ ...draft, ...patch }));
  }
});

test("only Razorpay terms can reserve an order", () => {
  assert.throws(() => checkCheckoutTerms({ ...held, provider: "phonepe" }));
  assert.doesNotThrow(() => checkCheckoutTerms({ ...held, provider: PAYMENT_PROVIDER }));
});

test("a non-Razorpay settlement reference never reaches capture lookup", async () => {
  let lookups = 0;
  const { db, settle } = setup({ lookupCapture: async () => { lookups++; return capture; } });
  await assert.rejects(settle({ ...request, provider: "phonepe" }), /Invalid checkout reference/);
  assert.equal(lookups, 0);
  assert.equal(db.writes, 0);
});

test("overlapping captures issue one pass for exactly the held dates; lost response replays after expiry", async () => {
  let lookups = 0;
  const { db, settle, clock } = setup({ lookupCapture: async (ref) => {
    assert.deepEqual(ref, { provider, paymentId });
    lookups++;
    return capture;
  } });
  const [a, b] = await Promise.all([settle(request), settle(request)]);
  assert.deepEqual(a, b);
  assert.ok(db.retries > 0);
  assert.equal(lookups, 2, "provider is not called again inside transaction retry");
  assert.deepEqual(a, { orderId, passId: `checkout-${orderId}` });
  assert.deepEqual(db.rows.get(`passes/${a.passId}`), {
    passId: a.passId, userId: terms.uid, orderId, hardExpiryDate: held.hardExpiryDate, createdAt: "stamp",
  });
  for (const date of held.serviceDates) {
    const ticketId = `${a.passId}_${date}`;
    assert.deepEqual(db.rows.get(`meal_tickets/${ticketId}`), {
      ticketId, passId: a.passId, userId: terms.uid, deliveryDate: `${date}T00:00:00.000Z`, status: "SCHEDULED",
      clusterId: held.clusterId, comboSelection: held.comboSelection, addOns: [], slot: "MORNING", createdAt: "stamp",
    });
  }
  assert.deepEqual(db.rows.get(orderPath), { ...held, status: "SETTLED", passId: a.passId, paymentId, settledAt: "stamp" });
  const claims = [...db.rows].filter(([path]) => path.startsWith("checkout_payment_claims/"));
  assert.deepEqual(claims.map(([, data]) => data), [{ orderId, provider, paymentId }]);
  clock.ms = held.holdExpiresAtMs;
  assert.deepEqual(await settle(request), a);
  assert.equal(db.writes, 5);
  assert.equal(db.rows.size, 5);
});

test("unconfirmed, unavailable, mismatched and malformed provider results cannot be overridden by client fields", async () => {
  for (const result of [null, { status: "DECLINED" }, { status: "AUTHORIZED" }, { paymentId: "wrong" },
    { orderId: "wrong" }, { provider: "wrong" }, { uid: "wrong" }, { merchantOrderRef: "wrong" },
    { amountMinor: 124 }, { currency: "USD" }, { amountMinor: "123" }, { amountMinor: 0 },
    { amountMinor: Number.MAX_SAFE_INTEGER + 1 }, { uid: "" }, { currency: "inr" }]) {
    const { db, settle } = setup({ lookupCapture: async () => result && { ...capture, ...result } });
    await assert.rejects(settle(capture));
    assert.equal(db.writes, 0);
  }
  const { db, settle } = setup({ lookupCapture: async () => { throw new Error("offline"); } });
  await assert.rejects(settle(capture), /offline/);
  assert.equal(db.writes, 0);
});

test("missing or malformed holds issue nothing", async () => {
  for (const patch of [{ orderId: "different-doc" }, { status: "SETTLED" },
    { holdExpiresAtMs: String(ms + 1) }, { clusterId: "" }, { comboSelection: "C" },
    { serviceDates: [] }, { serviceDates: "2030-01-31" }, { serviceDates: ["2030-02-30"] },
    { serviceDates: Array(498).fill("2030-01-31") }, { serviceDates: ["2030-01-31", "2030-01-31"] },
    { serviceDates: [...held.serviceDates].reverse() }, { hardExpiryDate: "2030-02-01" }]) {
    const { settle, db } = setup({ order: { ...held, ...patch } });
    await assert.rejects(settle(request));
    assert.equal(db.writes, 0);
  }
  const { settle, db } = setup();
  db.rows.delete(orderPath);
  await assert.rejects(settle(request), /reserved order/);
  assert.equal(db.writes, 0);
});

const claimKey = (id) => createHash("sha256").update(JSON.stringify([provider, id])).digest("hex");
function assertCredit(db, id, result, reason) {
  const creditId = claimKey(id);
  assert.deepEqual(result, { orderId, passId: null, creditId, status: "CREDITED" });
  assert.deepEqual(db.rows.get(`checkout_payment_claims/${creditId}`), {
    orderId, provider, paymentId: id, outcome: "CREDIT", creditId,
  });
  assert.deepEqual(db.rows.get(`customer_credits/${creditId}`), {
    creditId, userId: terms.uid, amountMinor: terms.amountMinor, currency: terms.currency,
    provider, paymentId: id, orderId, reason, status: "AVAILABLE", createdAt: "stamp",
  });
}

test("an expired hold credits the captured amount once, without changing the order or issuing meals", async () => {
  const { db, clock, settle } = setup();
  clock.ms = held.holdExpiresAtMs;
  const [a, b] = await Promise.all([settle(request), settle(request)]);
  assertCredit(db, paymentId, a, "HOLD_NOT_ACTIVE");
  assert.deepEqual(a, b);
  assert.ok(db.retries > 0);
  assert.equal(db.rows.get(orderPath), held);
  assert.equal(db.writes, 2);
  assert.equal(db.rows.size, 3);
});

test("an amount mismatch on an inactive order writes nothing and does not consume the verified claim", async () => {
  let amountMinor = terms.amountMinor + 1;
  const { db, settle } = setup({ order: { ...held, status: "RELEASED" },
    lookupCapture: async () => ({ ...capture, amountMinor }) });
  await assert.rejects(settle(request), /does not match reserved order/);
  assert.equal(db.writes, 0);
  amountMinor = terms.amountMinor;
  assertCredit(db, paymentId, await settle(request), "HOLD_NOT_ACTIVE");
  assert.equal(db.writes, 2);
});

test("clock and hold terms are read anew on a Firestore retry", async () => {
  for (const expired of [true, false]) {
    const { db, clock, settle } = setup();
    const changed = { ...held, status: expired ? "HELD" : "RELEASED", touched: true };
    db.beforeCommit = () => {
      db.rows.set(orderPath, changed);
      if (expired) clock.ms = held.holdExpiresAtMs;
    };
    assertCredit(db, paymentId, await settle(request), "HOLD_NOT_ACTIVE");
    assert.equal(db.rows.get(orderPath), changed);
    assert.equal(db.retries, 1);
    assert.equal(db.writes, 2);
    assert.equal(db.rows.size, 3);
  }
});

test("competing captures issue one pass and one duplicate credit; neither can be claimed twice", async () => {
  const otherOrder = { ...held, orderId: "other", merchantOrderRef: "merchant/other" };
  let owner = terms;
  const { db, clock, settle } = setup({
    rows: { "checkout_orders/other": otherOrder },
    lookupCapture: async (ref) => ({ ...capture, ...owner, status: "CAPTURED", paymentId: ref.paymentId }),
  });
  const attempts = [request, { ...request, paymentId: "pay/2" }];
  const receipts = await Promise.all(attempts.map(settle));
  const order = db.rows.get(orderPath);
  const winner = attempts.findIndex((ref) => order.paymentId === ref.paymentId);
  assert.deepEqual(receipts[winner], { orderId, passId: `checkout-${orderId}` });
  const i = 1 - winner;
  assertCredit(db, attempts[i].paymentId, receipts[i], "DUPLICATE_PAYMENT");
  clock.ms = held.holdExpiresAtMs;
  assert.deepEqual(await settle(attempts[i]), receipts[i]);
  assert.equal(db.rows.get(orderPath), order);
  assert.equal([...db.rows.keys()].filter((p) => p.startsWith("passes/")).length, 1);
  assert.equal([...db.rows.keys()].filter((p) => p.startsWith("meal_tickets/")).length, held.serviceDates.length);
  owner = otherOrder;
  for (const ref of attempts) await assert.rejects(settle({ ...ref, orderId: "other" }), /Payment already claimed/);
  assert.equal(db.rows.get("checkout_orders/other"), otherOrder);
  assert.equal(db.writes, 7);
});

test("an existing claim must match the capture and credit outcome before replay", async () => {
  const creditId = claimKey(paymentId);
  const order = { ...held, status: "SETTLED", paymentId, passId: `checkout-${orderId}` };
  for (const patch of [{ creditId: "wrong" }, { paymentId: "wrong" }, { orderId: "wrong" },
    { provider: "wrong" }, { outcome: "UNKNOWN" }]) {
    const claim = { orderId, provider, paymentId, creditId, outcome: "CREDIT", ...patch };
    const { db, settle } = setup({ order, rows: { [`checkout_payment_claims/${creditId}`]: claim } });
    await assert.rejects(settle(request));
    assert.equal(db.writes, 0);
  }
});

test("an invalid clock cannot issue a credit or acknowledge a settled payment", async () => {
  const { db, clock, settle } = setup({ lookupCapture: async (ref) => ({ ...capture, paymentId: ref.paymentId }) });
  await settle(request);
  for (const invalid of [-1, 0.5, NaN, Number.MAX_SAFE_INTEGER + 1]) {
    clock.ms = invalid;
    for (const id of [paymentId, "pay/2"]) await assert.rejects(settle({ ...request, paymentId: id }));
  }
  assert.equal(db.writes, 5);
});

test("a deterministic ticket collision aborts the whole transaction without overwriting existing data", async () => {
  const path = `meal_tickets/checkout-${orderId}_${held.serviceDates[1]}`;
  const { db, settle } = setup({ rows: { [path]: { original: true } } });
  await assert.rejects(settle(request));
  assert.equal(db.writes, 0);
  assert.equal(db.rows.size, 2);
  assert.deepEqual(db.rows.get(path), { original: true });
  assert.deepEqual(db.rows.get(orderPath), held);
});
