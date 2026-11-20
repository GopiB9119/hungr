const test = require("node:test");
const assert = require("node:assert/strict");
const { finalizeDeliveryProof } = require("../delivery-proof");
const { MemoryDB } = require("../test-support/memory-db");

const name = "delivery_proofs/t1/proof";
const ticket = (fields = {}) => ({ userId: "customer", assignedDriverId: "rider", status: "LOCKED", ...fields });
const photo = (fields = {}) => ({
  bucket: "hungr-app.appspot.com", name, contentType: "image/jpeg", size: "2048",
  metadata: { firebaseStorageDownloadTokens: "secret-link" }, ...fields,
});
function setup(row = ticket()) {
  const db = new MemoryDB({ "meal_tickets/t1": row });
  const cleared = [];
  const deps = {
    db, serverTimestamp: () => "server-time", log: { warn() {} },
    clearDownloadTokens: async (object) => { cleared.push(object.name); },
  };
  return { db, cleared, finalize: (object = photo()) => finalizeDeliveryProof(deps, object) };
}

test("the rider's stored photo, not the rider app, marks the meal delivered", async () => {
  const { db, cleared, finalize } = setup();
  assert.equal(await finalize(), "DELIVERED");
  assert.deepEqual(db.rows.get("meal_tickets/t1"),
    { ...ticket(), status: "DELIVERED", dropProofPath: name, deliveredAt: "server-time" });
  assert.deepEqual(cleared, [name]); // No public token link is left on the photo.
  assert.equal(await finalize(), "ALREADY_DELIVERED"); // Storage may deliver the event twice.
  assert.equal(db.writes, 1);
});

test("a photo for a meal that is not out for delivery changes nothing", async () => {
  for (const status of ["SCHEDULED", "SKIPPED", "MISSED", "DELIVERED"]) {
    const { db, cleared, finalize } = setup(ticket({ status, dropProofPath: "delivery_proofs/t1/other" }));
    assert.equal(await finalize(), "IGNORED", status);
    assert.equal(db.writes, 0, status);
    assert.deepEqual(cleared, [name], status);
  }
  const missing = new MemoryDB({});
  assert.equal(await finalizeDeliveryProof({ db: missing, serverTimestamp: () => 0, log: { warn() {} },
    clearDownloadTokens: async () => {} }, photo()), "IGNORED");
  assert.equal(missing.writes, 0);
});

test("other files, wrong types and empty or huge files never deliver a meal", async () => {
  for (const object of [
    photo({ name: "delivery_proofs/t1/door.jpg" }),
    photo({ name: "delivery_proofs/t1/proof/extra" }),
    photo({ name: "avatars/t1/proof" }),
    photo({ name: "delivery_proofs/t.1/proof" }),
    photo({ contentType: "text/plain" }),
    photo({ contentType: "image/svg+xml" }),
    photo({ size: "0" }),
    photo({ size: String(5 * 1024 * 1024) }),
    photo({ size: "abc" }),
  ]) {
    const { db, finalize } = setup();
    assert.notEqual(await finalize(object), "DELIVERED", JSON.stringify(object));
    assert.equal(db.writes, 0, JSON.stringify(object));
  }
});

test("a photo without a token link still delivers and is not touched", async () => {
  const { db, cleared, finalize } = setup();
  assert.equal(await finalize(photo({ metadata: {} })), "DELIVERED");
  assert.equal(db.rows.get("meal_tickets/t1").status, "DELIVERED");
  assert.deepEqual(cleared, []);
});
