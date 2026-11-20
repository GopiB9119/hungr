const test = require("node:test");
const assert = require("node:assert/strict");
const { MemoryDB } = require("../test-support/memory-db");
const { checkCheckoutTerms, createCheckoutSettlement } = require("../checkout-settlement");

const request = { orderId: "order-7", provider: "test-account", paymentId: "pay/1" };
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
  assert.equal(a.orderId, orderId);
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

test("missing, released, expired or malformed holds issue nothing", async () => {
  for (const patch of [{ orderId: "different-doc" }, { status: "RELEASED" }, { status: "SETTLED" },
    { holdExpiresAtMs: ms }, { holdExpiresAtMs: String(ms + 1) }, { clusterId: "" }, { comboSelection: "C" },
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

test("clock and hold terms are read anew on a Firestore retry", async () => {
  const { db, clock, settle } = setup();
  db.beforeCommit = () => {
    db.rows.set(orderPath, { ...held, touched: true });
    clock.ms = held.holdExpiresAtMs;
  };
  await assert.rejects(settle(request), /Hold not active/);
  assert.equal(db.retries, 1);
  assert.equal(db.writes, 0);

  clock.ms = ms;
  db.beforeCommit = () => db.rows.set(orderPath, { ...held, status: "RELEASED" });
  await assert.rejects(settle(request), /Order not held/);
  assert.equal(db.writes, 0);
});

test("two captures cannot settle one order, and a claimed payment cannot settle a different order", async () => {
  const otherOrder = { ...held, orderId: "other", merchantOrderRef: "merchant/other" };
  let owner = terms;
  const { db, settle } = setup({
    rows: { "checkout_orders/other": otherOrder },
    lookupCapture: async (ref) => ({ ...capture, ...owner, status: "CAPTURED", paymentId: ref.paymentId }),
  });
  const attempts = [request, { ...request, paymentId: "pay/2" }];
  const results = await Promise.allSettled(attempts.map(settle));
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const winner = attempts[results.findIndex((r) => r.status === "fulfilled")];
  assert.equal(db.rows.get(orderPath).paymentId, winner.paymentId);
  owner = otherOrder;
  await assert.rejects(settle({ ...winner, orderId: "other" }), /Payment already claimed/);
  assert.equal(db.rows.get("checkout_orders/other").status, "HELD");
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
