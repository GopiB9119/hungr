// Security-rules tests for the founder's delivery-proof and credit rules.
// Runs only inside the local emulators (demo project, no real Firebase):
//   firebase emulators:exec --only firestore,storage --project demo-hungr "node --test qa/rules-test/"
const test = require("node:test");
const assert = require("node:assert/strict");

const PROJECT = "demo-hungr";
const BUCKET = "hungr-app.appspot.com";
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const ST_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
if (!FS_HOST || !ST_HOST) throw new Error("Run through firebase emulators:exec (see header).");
const FS = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents`;
const ST = `http://${ST_HOST.replace(/^https?:\/\//, "")}/v0/b/${BUCKET}/o`;

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
function token(uid, claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  return `${b64({ alg: "none", typ: "JWT" })}.${b64({
    iss: `https://securetoken.google.com/${PROJECT}`, aud: PROJECT, iat: now, exp: now + 3600,
    auth_time: now, sub: uid, user_id: uid, firebase: { sign_in_provider: "custom", identities: {} }, ...claims,
  })}.`;
}
const customer = token("cust1", { role: "customer" });
const otherCustomer = token("cust2", { role: "customer" });
const rider = token("drv1", { role: "driver" });
const otherRider = token("drv2", { role: "driver" });
const admin = token("ops1", { role: "admin" });

const enc = (v) => (typeof v === "string" ? { stringValue: v } : { integerValue: String(v) });
const body = (o) => JSON.stringify({ fields: Object.fromEntries(Object.entries(o).map(([k, v]) => [k, enc(v)])) });
const auth = (t) => (t ? { Authorization: `Bearer ${t}` } : {});

async function seed(path, data) {
  const res = await fetch(`${FS}/${path}`, {
    method: "PATCH", headers: { Authorization: "Bearer owner", "Content-Type": "application/json" }, body: body(data),
  });
  assert.equal(res.status, 200, await res.text());
}
async function fsGet(path, t) {
  return (await fetch(`${FS}/${path}`, { headers: auth(t) })).status;
}
async function fsPatch(path, data, t) {
  const mask = Object.keys(data).map((k) => `updateMask.fieldPaths=${k}`).join("&");
  const res = await fetch(`${FS}/${path}?${mask}`, {
    method: "PATCH", headers: { ...auth(t), "Content-Type": "application/json" }, body: body(data),
  });
  return res.status;
}
async function upload(name, t, contentType = "image/jpeg", bytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9])) {
  const boundary = "hungr-proof";
  const payload = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=utf-8\r\n\r\n` +
      `${JSON.stringify({ name, contentType })}\r\n--${boundary}\r\nContent-Type: ${contentType}\r\n\r\n`),
    bytes, Buffer.from(`\r\n--${boundary}--`),
  ]);
  const res = await fetch(`${ST}?name=${encodeURIComponent(name)}`, {
    method: "POST", body: payload, headers: {
      ...(t ? { Authorization: `Firebase ${t}` } : {}),
      "Content-Type": `multipart/related; boundary=${boundary}`, "X-Goog-Upload-Protocol": "multipart",
    },
  });
  return res.status;
}
async function download(name, t) {
  const res = await fetch(`${ST}/${encodeURIComponent(name)}?alt=media`, {
    headers: t ? { Authorization: `Firebase ${t}` } : {},
  });
  return res.status;
}

const ticket = (id, status) => ({
  ticketId: id, passId: "p1", userId: "cust1", assignedDriverId: "drv1", status,
  deliveryDate: "2026-11-21T00:00:00.000Z", comboSelection: "A", clusterId: "c1",
});
// Storage keeps objects for the whole emulator run, and each ticket has one
// fixed proof name, so every upload test uses its own fresh ticket.
let fresh = 0;
async function lockedTicket() {
  const id = `t${Date.now()}x${++fresh}`;
  await seed(`meal_tickets/${id}`, ticket(id, "LOCKED"));
  return id;
}
const proof = (ticketId) => `delivery_proofs/${ticketId}/proof`;

test.beforeEach(async () => {
  const res = await fetch(`http://${FS_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    { method: "DELETE" });
  assert.equal(res.status, 200);
  await seed("meal_tickets/t1", ticket("t1", "LOCKED"));
  await seed("meal_tickets/t2", ticket("t2", "DELIVERED"));
  await seed("customer_credits/cr1", {
    creditId: "cr1", userId: "cust1", amountMinor: 35000, currency: "INR", status: "AVAILABLE",
  });
});

test("no app can mark a meal delivered; only the server photo trigger can", async () => {
  const delivered = { status: "DELIVERED", deliveredAt: "2026-11-21T07:40:00.000Z" };
  const oldUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/delivery_proofs%2Ft1%2Fdoor.jpg?alt=media&token=t0k`;
  for (const [who, t] of [["rider", rider], ["other rider", otherRider], ["customer", customer], ["admin", admin]]) {
    assert.equal(await fsPatch("meal_tickets/t1", delivered, t), 403, who);
    assert.equal(await fsPatch("meal_tickets/t1", { ...delivered, dropProofPath: proof("t1") }, t), 403, who);
    assert.equal(await fsPatch("meal_tickets/t1", { ...delivered, dropProofImageUrl: oldUrl }, t), 403, who);
  }
});

test("a ticket is visible only to its customer, its rider and admins", async () => {
  assert.equal(await fsGet("meal_tickets/t1", customer), 200);
  assert.equal(await fsGet("meal_tickets/t1", rider), 200);
  assert.equal(await fsGet("meal_tickets/t1", admin), 200);
  assert.equal(await fsGet("meal_tickets/t1", otherCustomer), 403);
  assert.equal(await fsGet("meal_tickets/t1", otherRider), 403);
  assert.equal(await fsGet("meal_tickets/t1", null), 403);
});

test("customer can read but never write their own payment credit", async () => {
  assert.equal(await fsGet("customer_credits/cr1", customer), 200);
  assert.equal(await fsGet("customer_credits/cr1", admin), 200);
  assert.equal(await fsGet("customer_credits/cr1", otherCustomer), 403);
  assert.equal(await fsPatch("customer_credits/cr1", { amountMinor: 99999 }, customer), 403);
  assert.equal(await fsPatch("customer_credits/cr2", { userId: "cust1", amountMinor: 500 }, customer), 403);
});

test("only the assigned rider can upload one image proof per ticket while the meal is out", async () => {
  const id = await lockedTicket();
  assert.equal(await upload(proof(id), otherRider), 403);
  assert.equal(await upload(proof(id), customer), 403);
  assert.equal(await upload(proof(id), null), 403);
  assert.equal(await upload(proof(id), rider, "text/plain"), 403);
  assert.equal(await upload(`delivery_proofs/${id}/door.jpg`, rider), 403); // Only the fixed name counts.
  assert.equal(await upload(`delivery_proofs/${id}/proof/extra.jpg`, rider), 403);
  assert.equal(await upload(proof("t2"), rider), 403); // Already delivered.
  assert.equal(await upload(proof(id), rider), 200);
  assert.equal(await upload(proof(id), rider), 403); // A proof photo cannot be replaced.
  assert.equal(await upload(proof(id), rider, "image/png"), 403);
});

test("proof photo is visible to the customer, rider and admin only", async () => {
  const id = await lockedTicket();
  assert.equal(await upload(proof(id), rider), 200);
  assert.equal(await download(proof(id), customer), 200);
  assert.equal(await download(proof(id), rider), 200);
  assert.equal(await download(proof(id), admin), 200);
  assert.equal(await download(proof(id), otherCustomer), 403);
  assert.equal(await download(proof(id), otherRider), 403);
  assert.equal(await download(proof(id), null), 403);
});
