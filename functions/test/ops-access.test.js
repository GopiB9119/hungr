const test = require("node:test");
const assert = require("node:assert/strict");
const { requireOpsAdmin } = require("../ops-access");

class HttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

test("operational calls require an authenticated admin role claim", () => {
  assert.throws(() => requireOpsAdmin({}, HttpsError), { code: "unauthenticated" });
  for (const token of [undefined, {}, { role: "customer" }, { role: "driver" }]) {
    assert.throws(() => requireOpsAdmin({ auth: { uid: "staff", token } }, HttpsError),
      { code: "permission-denied" });
  }
  assert.doesNotThrow(() => requireOpsAdmin({ auth: { uid: "staff", token: { role: "admin" } } }, HttpsError));
});

test("the missed-meal callable checks the admin claim before forwarding the request", async () => {
  const entry = require.resolve("../index");
  const load = require("node:module").createRequire(entry);
  const db = new (require("../test-support/memory-db").MemoryDB)({});
  const stubs = {
    "firebase-admin": { initializeApp() {}, firestore: () => db },
    "firebase-functions": { https: { HttpsError, onCall: (fn) => fn },
      pubsub: { schedule() { return this; }, timeZone() { return this; }, onRun: (fn) => fn },
      storage: { object: () => ({ onFinalize: (fn) => fn }) } },
  };
  const callables = {};
  require("node:vm").compileFunction(require("node:fs").readFileSync(entry, "utf8"), ["require", "exports"])(
    (id) => stubs[id] || load(id), callables);
  const data = { ticketId: "absent", placement: "NEXT_DAY" };
  for (const [context, code] of [[{}, "unauthenticated"],
    [{ auth: { uid: "rider", token: { role: "driver" } } }, "permission-denied"],
    [{ auth: { uid: "ops", token: { role: "admin" } } }, "not-found"]]) {
    await assert.rejects(callables.replaceMissedMeal(data, context), { code });
  }
  assert.equal(db.writes, 0);
});
