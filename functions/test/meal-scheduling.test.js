const test = require("node:test");
const assert = require("node:assert/strict");
const { createSkipMealTicket, scheduleKitchenSplit, failoverKitchenUnit } = require("../meal-scheduling");
const { MemoryDB } = require("../test-support/memory-db");

class HttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const stamp = (iso) => ({ toDate: () => new Date(iso) });
const serverTimestamp = () => "server-time";

const ticket = (fields = {}) => ({
  userId: "customer", passId: "short", status: "SCHEDULED", deliveryDate: "2030-01-31",
  clusterId: "gate", comboSelection: "A", ...fields,
});
const source = "meal_tickets/one", pass = "passes/short";
function setup(rows = {}) {
  const db = new MemoryDB({
    [pass]: { userId: "customer", hardExpiryDate: "2030-02-03" }, [source]: ticket(), ...rows,
  });
  const clock = { ms: Date.parse("2030-01-30T15:29:59.999Z") }; // 20:59:59.999 IST
  const handler = createSkipMealTicket({ db, HttpsError, serverTimestamp, now: () => clock.ms });
  return { db, clock, skip: (id = "one") => handler({ ticketId: id }, { auth: { uid: "customer" } }) };
}
const scheduled = (db) => [...db.rows.values()].filter((row) => row.status === "SCHEDULED");

test("overlapping skips and a lost-response retry receive the same paid replacement", async () => {
  const { db, clock, skip } = setup({ [source]: ticket({
    deliveryDate: "2030-01-31T23:40:00.123456", slot: "EVENING", addOns: ["coffee"],
    companionMeals: 1, specialtyName: "Dosa", bagToken: "#01", assignedDriverId: "old-route",
  }) });
  const [a, b] = await Promise.all([skip(), skip()]);
  assert.ok(db.retries > 0);
  assert.deepEqual(a, b);
  assert.equal(a.newScheduledDate, "2030-02-01T00:00:00.000Z");
  assert.equal(db.rows.get(source).rescheduledToTicketId, a.newTicketId);
  assert.equal(db.rows.get(source).status, "SKIPPED");
  assert.deepEqual(scheduled(db), [{
    ticketId: a.newTicketId, passId: "short", userId: "customer", clusterId: "gate",
    comboSelection: "A", addOns: ["coffee"], slot: "EVENING", companionMeals: 1,
    specialtyName: "Dosa", bagToken: "#01", deliveryDate: a.newScheduledDate,
    createdAt: "server-time", status: "SCHEDULED",
  }]);
  clock.ms += 60_000;
  assert.deepEqual(await skip(), a, "replay across cutoff does not spend a second credit");
  assert.equal(db.writes, 2);
});

test("concurrent skips from the same pass take consecutive days, not another pass's tail", async () => {
  const { db, skip } = setup({
    "meal_tickets/two": ticket({ deliveryDate: "2030-02-01" }),
    "meal_tickets/long": ticket({ passId: "other-pass", deliveryDate: "2030-02-25" }),
    "meal_tickets/other": ticket({ userId: "other", deliveryDate: "2030-02-20" }),
    "meal_tickets/skipped": ticket({ status: "SKIPPED", deliveryDate: "2030-02-28" }),
  });
  const receipts = await Promise.all([skip("one"), skip("two")]);
  assert.ok(db.retries > 0);
  assert.deepEqual(receipts.map((r) => r.newScheduledDate).sort(),
    ["2030-02-02T00:00:00.000Z", "2030-02-03T00:00:00.000Z"]);
  assert.equal(scheduled(db).filter((t) => t.userId === "customer" && t.passId === "short").length, 2);
});

test("contention for the last valid day leaves the other original meal scheduled", async () => {
  const { db, skip } = setup({
    [pass]: { userId: "customer", hardExpiryDate: "2030-02-02" },
    "meal_tickets/two": ticket({ deliveryDate: "2030-02-01" }),
  });
  const results = await Promise.allSettled([skip("one"), skip("two")]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.match(results.find((r) => r.status === "rejected").reason.message, /CEILING_REACHED/);
  assert.equal(scheduled(db).length, 2);
  assert.equal(db.writes, 2);
});

test("a pass allows three skips; a fourth is refused, but replaying the third receipt still works", async () => {
  const used = (id, fields = {}) => ({ [`meal_tickets/${id}`]: ticket({ status: "SKIPPED", ...fields }) });
  const { db, skip } = setup({
    ...used("s1"), ...used("s2"),
    ...used("other-user", { userId: "other" }), ...used("other-pass", { passId: "other-pass" }),
  });
  const third = await skip();
  assert.equal(db.rows.get(source).status, "SKIPPED");
  assert.deepEqual(await skip(), third, "a lost response is not another skip");

  const writes = db.writes;
  await assert.rejects(skip(third.newTicketId), (err) =>
    err.code === "failed-precondition" && /SKIP_LIMIT_REACHED/.test(err.message));
  assert.equal(db.writes, writes);
  assert.equal(db.rows.get(`meal_tickets/${third.newTicketId}`).status, "SCHEDULED");
});

test("two concurrent skips cannot both spend the last allowed skip", async () => {
  const { db, skip } = setup({
    "meal_tickets/s1": ticket({ status: "SKIPPED" }), "meal_tickets/s2": ticket({ status: "SKIPPED" }),
    "meal_tickets/two": ticket({ deliveryDate: "2030-02-01" }),
  });
  const results = await Promise.allSettled([skip("one"), skip("two")]);
  assert.ok(db.retries > 0);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.match(results.find((r) => r.status === "rejected").reason.message, /SKIP_LIMIT_REACHED/);
  assert.equal([...db.rows.values()].filter((row) => row.status === "SKIPPED").length, 3);
});

test("source, pass and existing receipt must agree on ownership; broken links never mint credit", async () => {
  for (const [rows, code] of [
    [{ [source]: ticket({ userId: "other" }) }, "permission-denied"],
    [{ [pass]: { userId: "other", hardExpiryDate: "2030-02-04" } }, "permission-denied"],
    [{ [source]: ticket({ passId: "retired-pass" }) }, "not-found"],
    [{ [source]: ticket({ status: "LOCKED" }) }, "failed-precondition"],
    [{ [source]: ticket({ status: "SKIPPED", rescheduledToTicketId: "missing" }) }, "failed-precondition"],
    [{ [source]: ticket({ status: "SKIPPED", rescheduledToTicketId: "replacement" }),
      "meal_tickets/replacement": ticket({ passId: "different" }) }, "failed-precondition"],
  ]) {
    const { db, skip } = setup(rows);
    await assert.rejects(skip(), { code });
    assert.equal(db.writes, 0);
  }
});

test("Timestamp expiry is inclusive by IST service day; locked future meals reserve their day", async () => {
  const { skip } = setup({
    [pass]: { userId: "customer", hardExpiryDate: stamp("2030-02-01T18:30:00Z") }, // Feb 2 IST
    [source]: ticket({ deliveryDate: "2030-01-30T23:00:00Z" }), // Jan 31 IST
    "meal_tickets/tail": ticket({ status: "LOCKED", deliveryDate: stamp("2030-01-31T18:30:00Z") }),
  });
  assert.equal((await skip()).newScheduledDate, "2030-02-02T00:00:00.000Z");
});

test("exact cutoff, stale service days and invalid ledger dates fail without changing credits", async () => {
  for (const [instant, rows] of [
    ["2030-01-30T15:30:00.000Z", {}], // 21:00 IST
    ["2030-01-30T18:30:00.000Z", {}], // next IST midnight: Jan 31 is no longer editable
    ["2030-01-30T06:00:00Z", { [source]: ticket({ deliveryDate: "2030-01-29" }) }],
    ["2030-01-30T06:00:00Z", { [pass]: { userId: "customer", hardExpiryDate: "2030-02-30" } }],
    ["2030-01-30T06:00:00Z", { [pass]: { userId: "customer" } }],
    ["2030-01-30T06:00:00Z", { "meal_tickets/tail": ticket({ deliveryDate: null }) }],
  ]) {
    const { db, clock, skip } = setup(rows);
    clock.ms = Date.parse(instant);
    await assert.rejects(skip(), { code: "failed-precondition" });
    assert.equal(db.writes, 0);
  }
});

test("a transaction retried across 21:00 rechecks the server clock", async () => {
  const { db, clock, skip } = setup();
  db.beforeCommit = () => {
    db.rows.set(pass, { ...db.rows.get(pass), updatedAt: "now" });
    clock.ms++;
  };
  await assert.rejects(skip(), /CUTOFF_EXCEEDED/);
  assert.equal(db.retries, 1);
  assert.equal(db.writes, 0);
});

function register(db) {
  const config = {};
  const pubsub = {
    schedule(cron) { config.cron = cron; return this; },
    timeZone(zone) { config.zone = zone; return this; },
    onRun(handler) { return handler; },
  };
  return { config, run: scheduleKitchenSplit(pubsub, { db, serverTimestamp }) };
}
const event = { timestamp: "2030-01-30T15:31:00.000Z" };

test("next daily kitchen trigger is 21:01 Kolkata, not 15:31 Kolkata", () => {
  const { config } = register();
  assert.equal(config.zone, "Asia/Kolkata");
  const [minute, hour, ...days] = config.cron.split(" ");
  assert.deepEqual(days, ["*", "*", "*"]);
  const local = new Intl.DateTimeFormat("en-GB", {
    timeZone: config.zone, hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  });
  const target = `${hour.padStart(2, "0")}:${minute.padStart(2, "0")}`;
  let ms = Date.parse("2030-01-30T00:00:00Z");
  const end = ms + 86_400_000;
  while (ms < end && local.format(ms) !== target) ms += 60_000;
  assert.equal(new Date(ms).toISOString(), event.timestamp);
});

test("a daily split locks just the IST service day across stored formats and preserves its manifest on retry", async () => {
  const db = new MemoryDB({
    "meal_tickets/start": ticket({ deliveryDate: "2030-01-30T18:30:00.000Z" }),
    "meal_tickets/end": ticket({ deliveryDate: stamp("2030-01-31T18:29:59.999Z") }),
    "meal_tickets/local": ticket({ deliveryDate: "2030-01-31T23:59:59.999999", comboSelection: "B" }),
    "meal_tickets/offset": ticket({ deliveryDate: "2030-02-01T00:01:00+09:00", comboSelection: "B" }),
    "meal_tickets/next": ticket({ deliveryDate: "2030-01-31T18:30:00.000Z" }),
    "meal_tickets/prior": ticket({ deliveryDate: stamp("2030-01-30T18:29:59.999Z") }),
    "meal_tickets/skipped": ticket({ status: "SKIPPED" }),
  });
  const { run } = register(db);
  await Promise.all([run(event), run(event)]);
  assert.ok(db.retries > 0);
  const summary = db.rows.get("kitchen_batches/2030-01-31");
  assert.equal(summary.totalUnits, 4);
  assert.equal(summary.unit1.total, 2);
  assert.equal(summary.unit2.total, 2);
  assert.equal(summary.unit1.optionB + summary.unit2.optionB, 2);
  for (const id of ["start", "end", "local", "offset"]) {
    assert.equal(db.rows.get(`meal_tickets/${id}`).status, "LOCKED");
  }
  assert.equal(scheduled(db).length, 2);
  assert.equal(db.rows.get("meal_tickets/skipped").status, "SKIPPED");
  await run(event);
  assert.equal(db.rows.get("kitchen_batches/2030-01-31"), summary);
  assert.equal(db.writes, 5);
});

test("the kitchen cannot lock an original meal concurrently moved to the pass tail", async () => {
  const { db, skip } = setup();
  // The split has read tomorrow's meals when the pre-cutoff skip commits.
  db.beforeCommit = skip;
  await register(db).run(event);
  assert.equal(db.retries, 1);
  assert.equal(db.rows.get("kitchen_batches/2030-01-31").totalUnits, 0);
  assert.equal(db.rows.get(source).status, "SKIPPED");
  assert.deepEqual(scheduled(db).map((t) => t.deliveryDate), ["2030-02-01T00:00:00.000Z"]);
});

const manifest = "kitchen_batches/2030-02-01";
const locked = (deliveryDate, fields = {}) => ticket({
  status: "LOCKED", assignedVendorId: "aunty_1", deliveryDate, ...fields,
});
const reroute = (db, unit = "aunty_1") => failoverKitchenUnit({
  db, HttpsError, serverTimestamp, now: () => Date.parse("2030-01-31T16:00:00Z"), // 21:30 IST
}, unit);

test("failover and its retry reroute only tomorrow's locked meals from the selected kitchen", async () => {
  const db = new MemoryDB({
    [manifest]: { date: "2030-02-01", totalUnits: 3, isFailoverActive: false },
    "kitchen_batches/2030-01-31": { date: "2030-01-31", isFailoverActive: false },
    "meal_tickets/local": locked("2030-02-01"),
    "meal_tickets/instant": locked(stamp("2030-01-31T18:30:00Z")),
    "meal_tickets/prior": locked(stamp("2030-01-31T18:29:59.999Z")),
    "meal_tickets/later": locked("2030-02-01T18:30:00Z"),
    "meal_tickets/other-unit": locked("2030-02-01", { assignedVendorId: "aunty_2" }),
    "meal_tickets/served": locked("2030-02-01", { status: "DELIVERED" }),
  });
  const before = new Map(db.rows);
  const [first, retry] = await Promise.all([reroute(db), reroute(db)]);
  assert.ok(first.success);
  assert.deepEqual(first, retry);
  assert.equal(db.writes, 3);
  const summary = db.rows.get(manifest);
  assert.equal(summary.totalUnits, 3);
  assert.equal(summary.isFailoverActive, true);
  assert.equal(summary.failoverUnitId, "aunty_1");
  for (const [path, original] of before) {
    const updated = db.rows.get(path);
    if (path === "meal_tickets/local" || path === "meal_tickets/instant") {
      assert.equal(updated.status, "LOCKED");
      assert.equal(updated.assignedVendorId, "backup_hub");
      assert.equal(updated.pickupAddress, summary.backupCenterAddress);
    } else if (path !== manifest) {
      assert.equal(updated, original, path);
    }
  }
});

test("failover keeps both tickets and manifest untouched on missing batch, conflicting unit or commit failure", async () => {
  const db = new MemoryDB({ "meal_tickets/due": locked("2030-02-01") });
  const originalMeal = db.rows.get("meal_tickets/due");
  await assert.rejects(reroute(db), { code: "not-found" });
  assert.equal(db.rows.has(manifest), false);
  const originalSummary = { isFailoverActive: true, failoverUnitId: "aunty_2" };
  db.rows.set(manifest, originalSummary);
  await assert.rejects(reroute(db), { code: "failed-precondition" });
  assert.equal(db.rows.get(manifest), originalSummary);
  const ready = { isFailoverActive: false };
  db.rows.set(manifest, ready);
  db.beforeCommit = () => { throw new Error("commit unavailable"); };
  await assert.rejects(reroute(db), /commit unavailable/);
  assert.equal(db.rows.get(manifest), ready);
  assert.equal(db.rows.get("meal_tickets/due"), originalMeal);
  assert.equal(db.writes, 0);
});

test("no matching meals cannot consume the day's failover slot", async () => {
  const db = new MemoryDB({
    [manifest]: { isFailoverActive: false },
    "meal_tickets/due": locked("2030-02-01", { assignedVendorId: "aunty_2" }),
  });
  await assert.rejects(reroute(db), { code: "failed-precondition" });
  assert.equal(db.writes, 0);
  await reroute(db, "aunty_2");
  assert.equal(db.rows.get(manifest).failoverUnitId, "aunty_2");
});

test("the last nanosecond before IST midnight belongs to the ending service and expiry day", async () => {
  const seconds = Date.parse("2030-01-31T18:29:59Z") / 1000;
  const end = { seconds, nanoseconds: 999_999_999, toDate: () => new Date((seconds + 1) * 1000) };
  const { db, skip } = setup({ [pass]: { userId: "customer", hardExpiryDate: end } });
  await assert.rejects(skip(), /CEILING_REACHED/); // Feb 1 would be too late.
  db.rows.set(source, ticket({ deliveryDate: end }));
  await register(db).run(event);
  assert.equal(db.rows.get(source).status, "LOCKED");
});

const splitSummary = "kitchen_batches/2030-01-31";
test("empty or partial legacy summaries catch up without replacing locked, delivered or pinned assignments", async () => {
  for (const recorded of [0, 1]) {
    const db = new MemoryDB({
      [splitSummary]: { date: "2030-01-31", totalUnits: recorded, generatedAt: "original" },
      "meal_tickets/delivered": locked("2030-01-31", { status: "DELIVERED", companionMeals: 1 }),
      "meal_tickets/locked": locked("2030-01-31", { assignedVendorId: "aunty_2", comboSelection: "B" }),
      "meal_tickets/pinned": ticket({ assignedVendorId: "aunty_2", companionMeals: 1, comboSelection: "B" }),
      "meal_tickets/new": ticket({ companionMeals: 2 }),
    });
    const before = new Map(db.rows);
    const { run } = register(db);
    await run(event);
    const summary = db.rows.get(splitSummary);
    assert.equal(summary.totalUnits, 8);
    assert.deepEqual([summary.unit1.total, summary.unit2.total], [5, 3]);
    assert.deepEqual([summary.unit1.optionA, summary.unit2.optionB], [5, 3]);
    assert.equal(summary.generatedAt, "original");
    for (const name of ["locked", "delivered"]) {
      assert.equal(db.rows.get(`meal_tickets/${name}`), before.get(`meal_tickets/${name}`));
    }
    assert.equal(db.rows.get("meal_tickets/pinned").assignedVendorId, "aunty_2");
    assert.equal(scheduled(db).length, 0);
    await run(event);
    assert.equal(db.rows.get(splitSummary), summary);
  }
});

test("whole companion orders can fill 50/50 without splitting or dropping paid portions", async () => {
  // A greedy assignment of these five bundles can strand the last order.
  const sizes = [30, 25, 20, 15, 10];
  const db = new MemoryDB(Object.fromEntries(sizes.map((n, i) => [
    `meal_tickets/t${i}`, ticket({ companionMeals: n - 1, comboSelection: i % 2 ? "A" : "B" }),
  ])));
  await register(db).run(event);
  const summary = db.rows.get(splitSummary);
  assert.equal(summary.totalUnits, 100);
  for (const unit of [summary.unit1, summary.unit2]) {
    const meals = [...db.rows.values()].filter((m) => m.status === "LOCKED" && m.assignedVendorId === unit.vendorId);
    const portions = (rows) => rows.reduce((n, m) => n + m.companionMeals + 1, 0);
    assert.equal(portions(meals), 50);
    assert.equal(unit.total, 50);
    assert.equal(portions(meals.filter((m) => m.comboSelection === "A")), unit.optionA);
    assert.equal(unit.optionA + unit.optionB, 50);
  }
});

test("capacity shortages report the service date and leave every paid ticket and manifest untouched", async () => {
  for (const sizes of [[50, 50, 1], [34, 33, 33]]) { // over 100; exactly 100 but no whole-order split
    const db = new MemoryDB(Object.fromEntries(sizes.map((n, i) =>
      [`meal_tickets/t${i}`, ticket({ companionMeals: n - 1 })])));
    await assert.rejects(register(db).run(event), /KITCHEN_CAPACITY.*2030-01-31/);
    assert.equal(db.writes, 0);
    assert.equal(scheduled(db).length, sizes.length);
    assert.equal(db.rows.has(splitSummary), false);
  }
});

test("reconciliation stops on unsupported quantities, assignment conflicts or new orders during failover", async () => {
  for (const rows of [
    { [splitSummary]: { date: "2030-01-31", totalUnits: 2 }, [source]: ticket() },
    { [source]: locked("2030-01-31", { assignedVendorId: null }) },
    { [source]: ticket({ companionMeals: -1 }) },
    { [source]: locked("2030-01-31", { assignedVendorId: "backup_hub" }) },
    { [splitSummary]: { isFailoverActive: true, failoverUnitId: "aunty_1" },
      [source]: ticket(), "meal_tickets/assigned": locked("2030-01-31", { assignedVendorId: "backup_hub" }) },
  ]) {
    const db = new MemoryDB(rows);
    await assert.rejects(register(db).run(event), /KITCHEN_RECONCILE.*2030-01-31/);
    assert.equal(db.writes, 0);
  }
});

test("rebuilding portion totals preserves a verified failover and its original assignments", async () => {
  const db = new MemoryDB({
    [splitSummary]: { totalUnits: 1, isFailoverActive: true, failoverUnitId: "aunty_1", reroutedAt: "original" },
    [source]: locked("2030-01-31", { assignedVendorId: "backup_hub", companionMeals: 2 }),
  });
  const meal = db.rows.get(source);
  await register(db).run(event);
  const summary = db.rows.get(splitSummary);
  assert.equal(summary.totalUnits, 3);
  assert.equal(summary.unit1.total, 3);
  assert.equal(summary.isFailoverActive, true);
  assert.equal(summary.failoverUnitId, "aunty_1");
  assert.equal(summary.reroutedAt, "original");
  assert.equal(db.rows.get(source), meal);
});
