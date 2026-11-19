'use strict';

const assert = require('node:assert/strict');
const { before, test } = require('node:test');
const { id, actor, verifyEmulator, expect, seed, write, get, remove, query } = require('./emulator.cjs');

const customer = actor('customer'), neighbour = actor('neighbour'), driver = actor('driver', 'driver');
const otherDriver = actor('other-driver', 'driver'), admin = actor('operator', 'admin');
const create = { mode: 'create' };
const future = '2099-12-08T00:00:00.000Z';
const scheduled = { userId: customer.uid, deliveryDate: future, comboSelection: 'A', addOns: [], status: 'SCHEDULED' };
const deny = response => expect(response, 403);
before(verifyEmulator);

async function lists(response, path) {
  const rows = await expect(response);
  assert.ok(rows.some(row => row.document?.name.endsWith(`/documents/${path}`)), `Expected fixture ${path} in query`);
}

test('profile: owner bootstrap and contact sync, private get, admin-only list, owner deletion', async () => {
  const path = `users/${customer.uid}`;
  const contact = { name: 'Fixture customer', phoneNumber: 'fixture-phone', clusterName: '' };
  await expect(get(customer, path), 404); // syncUserProfile checks existence first.
  await expect(write(customer, path, { uid: customer.uid, role: 'customer', ...contact },
    { ...create, timestamps: ['createdAt', 'updatedAt'] }));
  await expect(write(customer, path, { ...contact, name: 'Updated fixture', clusterName: 'Gate A' },
    { timestamps: ['updatedAt'] }));
  assert.equal((await expect(get(customer, path))).fields.clusterName.stringValue, 'Gate A');
  for (const who of [null, neighbour, driver]) await deny(get(who, path));
  await deny(query(customer, 'users'));
  await lists(query(admin, 'users'), path);
  await deny(write(customer, path, { role: 'driver' }, { timestamps: ['updatedAt'] }));
  await deny(write(customer, path, { clusterId: 'routing-fixture' }, { timestamps: ['updatedAt'] }));
  await deny(remove(neighbour, path));
  await expect(remove(customer, path));
  await deny(write(customer, path, { uid: customer.uid, role: 'driver', ...contact },
    { ...create, timestamps: ['createdAt', 'updatedAt'] }));
});

test('only a provisioned admin, not a profile role or unscoped partner, can manage the public catalog', async () => {
  const legacy = actor('legacy'), partner = actor('partner', 'partner');
  await seed(`users/${legacy.uid}`, { uid: legacy.uid, role: 'admin' });
  const shop = `tiffin_shops/${id('shop')}`;
  await expect(write(admin, shop, { name: 'Fixture kitchen' }, create));
  await expect(get(null, shop));
  await deny(write(legacy, shop, { name: 'Fixture edit' }));
  await deny(write(partner, shop, { name: 'Fixture edit' }));
  await deny(write(partner, `${shop}/dishes/${id('dish')}`, { name: 'Fixture dish' }, create));
  const manifest = `driver_manifests/${id('manifest')}`;
  await seed(manifest, { name: 'Fixture manifest' });
  await deny(get(driver, manifest));
  await deny(write(driver, manifest, { name: 'Fixture edit' }));
});

test('issued passes and tickets: owner reads, no client issuance, transfer or paid add-on edits', async () => {
  const pass = `passes/${id('pass')}`, ticket = `meal_tickets/${id('ticket')}`;
  const terms = { userId: customer.uid, hardExpiryDate: future };
  for (const who of [customer, admin]) {
    await deny(write(who, pass, terms, create));
    await deny(write(who, ticket, scheduled, create));
  }
  await seed(pass, terms);
  await seed(ticket, scheduled);
  await expect(get(customer, pass));
  await expect(get(customer, ticket));
  await lists(query(customer, 'meal_tickets', 'userId'), ticket);
  for (const who of [neighbour, driver]) {
    await deny(get(who, pass));
    await deny(get(who, ticket));
  }
  await deny(write(customer, pass, { userId: neighbour.uid }));
  await deny(remove(customer, pass));
  await deny(write(customer, ticket, { status: 'SKIPPED' }));
  await deny(write(customer, ticket, { addOns: ['addon_filter_coffee'] }));
  await deny(write(admin, ticket, { userId: neighbour.uid }));
});

test('driver claim AND existing assignment; only locked-to-delivered completion and proof', async () => {
  const locked = `meal_tickets/${id('locked')}`, upcoming = `meal_tickets/${id('upcoming')}`;
  const notDriver = `meal_tickets/${id('not-driver')}`;
  await seed(locked, { ...scheduled, status: 'LOCKED', assignedDriverId: driver.uid });
  await seed(upcoming, { ...scheduled, assignedDriverId: driver.uid });
  await seed(notDriver, { ...scheduled, status: 'LOCKED', assignedDriverId: neighbour.uid });
  await expect(get(driver, locked));
  await deny(get(otherDriver, locked));
  await deny(get(neighbour, notDriver));
  await deny(query(driver, 'meal_tickets'));
  await lists(query(driver, 'meal_tickets', 'assignedDriverId'), locked);
  const completed = { status: 'DELIVERED', dropProofImageUrl: 'fixture-proof', deliveredAt: '2026-01-02T03:00:00.000Z' };
  await deny(write(otherDriver, locked, completed));
  await deny(write(neighbour, notDriver, completed));
  await deny(write(driver, upcoming, completed));
  await deny(write(driver, locked, { status: 'SKIPPED' }));
  await deny(write(driver, locked, { ...completed, assignedDriverId: otherDriver.uid }));
  await deny(write(driver, locked, { ...completed, deliveredAt: [] }));
  await expect(write(driver, locked, completed));
  await deny(write(driver, locked, { status: 'SCHEDULED' }));
});

test('owner combo: scheduled only, before both the server nightly cutoff and that service day’s deadline', async t => {
  const next = `meal_tickets/${id('open')}`, overdue = `meal_tickets/${id('overdue')}`;
  const hourIst = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', hourCycle: 'h23' });
  const open = time => Number(hourIst.format(new Date(time))) < 21;
  // The evaluator supplies request.time; clients cannot choose it. Bracket the write
  // with emulator commit times; repeat once if it crossed 21:00 or midnight IST.
  for (let attempt = 0; ; attempt++) {
    const start = await seed(next, scheduled);
    const result = await write(customer, next, { comboSelection: 'B' });
    const end = await seed(overdue, { ...scheduled, deliveryDate: '2001-01-08T00:00:00.000Z' });
    if (open(start.commitTime) !== open(end.commitTime) && !attempt) continue;
    await expect(result, open(start.commitTime) ? 200 : 403);
    t.diagnostic(`Emulator nightly window was ${open(start.commitTime) ? 'open' : 'closed'}`);
    break;
  }
  await deny(write(customer, overdue, { comboSelection: 'B' }));
  await deny(write(neighbour, next, { comboSelection: 'A' }));
  await deny(write(customer, next, { comboSelection: 'C' }));
  await seed(next, { ...scheduled, status: 'LOCKED' });
  await deny(write(customer, next, { comboSelection: 'B' }));
});
