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
