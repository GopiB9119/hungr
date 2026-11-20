'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createRequire } = require('node:module');
const { join } = require('node:path');
const { actor, expect, get, id, verifyEmulator, write } = require('./emulator.cjs');
const { createCheckoutHold } = require('../../functions/checkout-hold');
const { createCheckoutSettlement } = require('../../functions/checkout-settlement');

test('one available portion yields one hold and one private, retry-safe pass on Firestore', async t => {
  await verifyEmulator();
  const fromFunctions = createRequire(join(__dirname, '../../functions/package.json'));
  const { Firestore, FieldValue } = fromFunctions('firebase-admin/firestore');
  const db = new Firestore({
    projectId: 'demo-hungr-policy', host: process.env.FIRESTORE_EMULATOR_HOST, ssl: false,
  });
  t.after(() => db.terminate());
  const buyers = [actor('one'), actor('two')];
  const day = '2030-01-31', now = () => Date.parse('2030-01-30T06:00:00Z');
  const capacity = db.collection('checkout_capacity').doc(day);
  // Requires a new disposable emulator. Never overwrite another run's inventory.
  await capacity.create({ remainingPortions: 1 });
  const hold = createCheckoutHold({ db, now });
  const quotes = buyers.map(({ uid }, i) => ({
    uid, orderId: id(`order-${i}`), merchantOrderRef: id(`ref-${i}`), provider: 'offline-store',
    currency: 'INR', amountMinor: 1234, hardExpiryDate: day, serviceDates: [day],
    comboSelection: 'A', clusterId: 'fixture-gate', holdExpiresAtMs: now() + 60000,
  }));
  const results = await Promise.allSettled(quotes.map(hold));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.match(results.find(r => r.status === 'rejected').reason.message, /capacity/i);
  const i = results.findIndex(r => r.status === 'fulfilled'), q = quotes[i];
  const ref = { orderId: q.orderId, provider: q.provider, paymentId: id('payment') };
  const settle = createCheckoutSettlement({
    db, now, serverTimestamp: () => FieldValue.serverTimestamp(),
    lookupCapture: async () => ({ ...ref, status: 'CAPTURED', amountMinor: q.amountMinor,
      currency: q.currency, merchantOrderRef: q.merchantOrderRef, uid: q.uid }),
  });
  const [receipt, retry] = await Promise.all([settle(ref), settle(ref)]);
  assert.deepEqual(retry, receipt);
  const snapshot = await db.collection('meal_tickets').where('passId', '==', receipt.passId).get();
  assert.equal(snapshot.size, 1);
  assert.equal(snapshot.docs[0].data().userId, q.uid);
  assert.equal((await capacity.get()).data().remainingPortions, 0);
  await expect(get(buyers[i], `passes/${receipt.passId}`));
  await expect(get(buyers[1 - i], `passes/${receipt.passId}`), 403);
  await expect(get(buyers[i], `checkout_orders/${q.orderId}`), 403);
  await expect(write(buyers[i], `checkout_capacity/${day}`, { remainingPortions: '1' }), 403);
});
