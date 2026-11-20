const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { customerPriceForHotelPrice, hotelPriceForCustomerPrice, isPassEligible } = require('./pricing.js');

test('add the margin once per dish; editing a saved price does not add it again', () => {
  for (const [hotel, customer] of [[5, 10], [44, 49], [45, 50], [46, 51], [295, 300]]) {
    assert.equal(customerPriceForHotelPrice(String(hotel)), customer);
    assert.equal(hotelPriceForCustomerPrice(customer), hotel);
    assert.equal(customerPriceForHotelPrice(hotelPriceForCustomerPrice(customer)), customer);
  }
});

test('reject missing, malformed, fractional and out-of-range hotel price entries', () => {
  for (const value of ['', ' ', null, undefined, true, '4', '296', '-5', '12.5', '12abc',
    '1e2', '0x10', 'Infinity', NaN]) {
    assert.throws(() => customerPriceForHotelPrice(value), /whole number.*5.*295/i, String(value));
  }
});

test('pass hint uses the customer price, including the margin', () => {
  assert.equal(isPassEligible(customerPriceForHotelPrice('45')), true);
  assert.equal(isPassEligible(customerPriceForHotelPrice('46')), false);
  assert.equal(isPassEligible(0), false);
});

// Exercise the real modal handlers and local script order with no SDK or network.
function priceForm(cloud = false) {
  const nodes = new Map(), storage = new Map(), alerts = [], writes = [];
  function element() {
    return {
      value: '', textContent: '', style: {}, classList: { add() {}, remove() {} },
      set id(id) { nodes.set(id, this); this._id = id; }, get id() { return this._id; },
      addEventListener(type, cb) { this[`on${type}`] = cb; },
      appendChild() {}, replaceChildren() {}, setAttribute() {}, focus() {},
    };
  }
  function el(id) {
    if (!nodes.has(id)) nodes.set(id, element());
    return nodes.get(id);
  }
  const ctx = vm.createContext({
    document: { createElement: element, getElementById: el, querySelectorAll: () => [] },
    window: { addEventListener() {} }, alert: msg => alerts.push(msg),
    localStorage: { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, value) },
    isFirebaseConfigured: cloud, isFirebaseAvailable: cloud,
    db: { collection: name => ({ doc: id => ({ set: data => writes.push({ name, id, data }) }) }) },
  });
  const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  for (const [, file] of html.matchAll(/<script src="(pricing\.js|app\.js)"><\/script>/g)) {
    vm.runInContext(fs.readFileSync(path.join(__dirname, file), 'utf8'), ctx);
  }
  return { ctx, el, alerts, storage, writes };
}

test('editing previews the inclusive cap live; a bad row blocks the entire preview save', async () => {
  const { ctx, el, alerts, storage } = priceForm();
  ctx.openEditShopModal('shop_venkateshwara');
  const input = el('dish-price-0'), hint = el('dish-price-0-hint');
  assert.equal(Number(input.value), 44); // Existing customer price: Rs 49.
  input.value = '45'; input.oninput();
  assert.match(hint.textContent, /Customer pays Rs 50.*Pass OK/);
  input.value = '46'; input.oninput();
  assert.match(hint.textContent, /Customer pays Rs 51.*Not on pass/);
  el('dish-price-1').value = '12.8';
  await ctx.saveShopChanges();
  assert.match(alerts.at(-1), /whole number.*5.*295/i);
  assert.equal(storage.has('hungr_admin_shops'), false);
  el('dish-price-1').value = '44';
  await ctx.saveShopChanges();
  const dishes = JSON.parse(storage.get('hungr_admin_shops'))[0].dishes;
  assert.equal(dishes[0].price, 51);
  assert.equal(dishes[1].price, 49);
  assert.ok(dishes.every(dish => !('hotelPrice' in dish)));
});

test('new shops require actual hotel prices for both starter dishes before a cloud write', async () => {
  const { ctx, el, alerts, writes } = priceForm(true);
  ctx.openAddShopModal();
  el('add-shop-name').value = 'Test kitchen';
  el('new-dish-price-0').value = '49';
  await ctx.saveNewShop();
  assert.equal(writes.length, 0);
  assert.match(alerts.at(-1), /whole number.*5.*295/i);
  el('new-dish-price-1').value = '45';
  await ctx.saveNewShop();
  assert.equal(writes.length, 1);
  assert.equal(writes[0].name, 'tiffin_shops');
  assert.deepEqual(Array.from(writes[0].data.dishes, dish => dish.price), [54, 50]);
  assert.ok(writes[0].data.dishes.every(dish => !('hotelPrice' in dish)));
});
