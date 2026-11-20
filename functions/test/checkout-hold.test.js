const test = require("node:test");
const assert = require("node:assert/strict");
const { MemoryDB } = require("../test-support/memory-db");
const { createCheckoutHold } = require("../checkout-hold");
const { createCheckoutSettlement } = require("../checkout-settlement");
const { planKitchenBatch } = require("../kitchen-plan");

const dates = ["2030-02-01", "2030-02-03"];
const quote = (id = "alpha") => ({
  orderId: id, uid: `u-${id}`, provider: "razorpay", merchantOrderRef: `m-${id}`,
  amountMinor: 12345, currency: "INR", clusterId: "test-gate", comboSelection: "B",
  serviceDates: [...dates], hardExpiryDate: dates[1], holdExpiresAtMs: Date.parse("2030-01-30T06:10:00Z"),
});
const capacity = (day) => `checkout_capacity/${day}`;
function setup(second = 1) {
  const db = new MemoryDB({
    [capacity(dates[0])]: { remainingPortions: 1 },
    [capacity(dates[1])]: { remainingPortions: second },
  });
  const clock = { ms: Date.parse("2030-01-30T06:00:00Z") };
  const now = () => clock.ms;
  return { db, clock, now, hold: createCheckoutHold({ db, now }) };
}

test("two customers competing for the last portion cannot both reserve or consume a partial pass", async () => {
  const { db, hold } = setup();
  const results = await Promise.allSettled([hold(quote()), hold(quote("beta"))]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.match(results.find((r) => r.status === "rejected").reason.message, /capacity/i);
  assert.ok(db.retries >= 1);
  assert.equal([...db.rows.keys()].filter((p) => p.startsWith("checkout_orders/")).length, 1);
  for (const date of dates) assert.equal(db.rows.get(capacity(date)).remainingPortions, 0);
});

test("missing, corrupt or exhausted inventory on any service date changes nothing", async () => {
  for (const last of [null, 1.5, 0, 101]) {
    const { db, hold } = setup(last);
    if (last == null) db.rows.delete(capacity(dates[1]));
    await assert.rejects(hold(quote()), /capacity/i);
    assert.equal(db.writes, 0);
  }
});

test("hold retries cannot change terms, add unpaid extras, extend expiry or cross the kitchen cutoff", async () => {
  const { hold, db, clock } = setup();
  const q = quote();
  assert.deepEqual(await Promise.all([hold(q), hold(q)]), [0, 1].map(() => ({ orderId: q.orderId, status: "HELD" })));
  const before = db.writes;
  await assert.rejects(hold({ ...q, amountMinor: q.amountMinor + 1 }), /conflict/i);
  await assert.rejects(hold({ ...q, companionMeals: 1 }), /unsupported/i);
  clock.ms = q.holdExpiresAtMs;
  await assert.rejects(hold(q), /expir/i);
  await assert.rejects(hold({ ...quote("beta"), holdExpiresAtMs: Date.parse("2030-01-31T15:30:01Z") }), /cutoff/i);
  assert.equal(db.writes, before);
});

test("a test pass goes from hold to verified fixture capture to kitchen plan only once", async () => {
  const { db, now, clock, hold } = setup();
  const q = quote(), payment = { orderId: q.orderId, provider: q.provider, paymentId: "pay-test" };
  await hold(q);
  const settle = createCheckoutSettlement({
    db, now, serverTimestamp: now,
    lookupCapture: async () => ({ ...payment, uid: q.uid, merchantOrderRef: q.merchantOrderRef,
      currency: q.currency, amountMinor: q.amountMinor, status: "CAPTURED" }),
  });
  const issued = await settle(payment);
  const writes = db.writes;
  clock.ms = q.holdExpiresAtMs + 1; // both responses were lost; retry from the original durable order ID
  assert.deepEqual(await hold(q), { orderId: q.orderId, status: "SETTLED" });
  assert.deepEqual(await settle(payment), issued);
  assert.equal(db.writes, writes);
  const tickets = [...db.rows.entries()].filter(([key]) => key.startsWith("meal_tickets/"));
  assert.equal(tickets.length, dates.length);
  for (const date of dates) {
    const docs = tickets.filter(([, row]) => row.deliveryDate.startsWith(date))
      .map(([ref, row]) => ({ ref, data: () => row }));
    assert.equal(planKitchenBatch(date, undefined, docs).totals.totalUnits, 1);
    assert.equal(db.rows.get(capacity(date)).remainingPortions, 0);
  }
  assert.equal([...db.rows.keys()].filter((key) => key.startsWith("passes/")).length, 1);
});
