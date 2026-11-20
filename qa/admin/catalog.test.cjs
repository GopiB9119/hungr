const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const adminFile = name => fs.readFileSync(path.join(__dirname, '..', '..', 'web_admin', name), 'utf8');
// index.html loads pricing.js before app.js.
const sources = [adminFile('pricing.js'), adminFile('app.js')];

function element(tag = 'div') {
  const classes = new Set(), listeners = new Map();
  return {
    tag, value: '', style: {}, text: '', children: [],
    classList: { add: c => classes.add(c), remove: c => classes.delete(c), contains: c => classes.has(c) },
    set textContent(text) { this.text = String(text); this.html = ''; this.children = []; },
    get textContent() { return this.text + this.children.map(child => child.textContent).join(''); },
    set innerHTML(html) { this.html = html; this.text = ''; this.children = []; },
    get innerHTML() { return this.html || ''; },
    appendChild(child) { this.children.push(child); },
    replaceChildren(...children) { this.textContent = ''; this.children = children; },
    addEventListener(type, fn) { listeners.set(type, fn); },
    setAttribute(name, value) { this[name] = String(value); },
    focus() {},
    click() {
      assert.equal(this.tag, 'button');
      if (!this.disabled) return listeners.get('click')?.({ currentTarget: this, target: this });
    },
  };
}

function find(node, match) {
  if (match(node)) return node;
  for (const child of node.children) {
    const found = find(child, match);
    if (found) return found;
  }
}

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

// Run only the local classic script. No HTML loader, SDK, network, timers or real storage.
function portal(mode, write = async () => {}) {
  const elements = new Map(), storage = new Map(), streams = new Map();
  const messages = [], writes = [], broadcasts = [];
  let start;
  function el(id) {
    if (!elements.has(id)) {
      for (const root of elements.values()) {
        const child = find(root, node => node.id === id);
        if (child) return child;
      }
      elements.set(id, element());
    }
    return elements.get(id);
  }
  const db = {
    collection(name) {
      return {
        onSnapshot(...args) {
          const [next, error] = args.slice(-2);
          streams.set(name, { next, error });
        },
        doc(id) {
          function send(method, data) {
            writes.push({ name, id, method, data });
            return write();
          }
          return { set: data => send('set', data), update: data => send('update', data), delete: () => send('delete') };
        },
      };
    },
  };
  const ctx = vm.createContext({
    window: { addEventListener(type, fn) { if (type === 'DOMContentLoaded') start = fn; } },
    setInterval() {},
    document: { getElementById: el, createElement: element, querySelectorAll: () => [] },
    console: { log() {}, warn() {}, error() {} },
    localStorage: { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, value) },
    alert: msg => messages.push(msg), confirm: () => true,
    BroadcastChannel: class { postMessage(msg) { broadcasts.push(msg); } },
    isFirebaseConfigured: mode !== 'preview', isFirebaseAvailable: mode === 'cloud',
    db: mode === 'cloud' ? db : null,
  });
  for (const source of sources) vm.runInContext(source, ctx);
  start();
  function snapshot(name, rows, flags = {}) {
    streams.get(name).next({
      docs: rows.map(([id, data]) => ({ id, data: () => data })), empty: !rows.length,
      metadata: { fromCache: false, hasPendingWrites: false, ...flags },
    });
  }
  function draftOffer() {
    ctx.openAddOfferModal();
    el('offer-code').value = 'sample';
    el('offer-description').value = 'Sample breakfast discount';
    el('offer-type').value = 'flat';
    el('offer-value').value = '5';
    el('offer-min-order').value = '50';
  }
  return { ctx, el, storage, messages, writes, broadcasts, streams, snapshot, draftOffer,
    read: expression => vm.runInContext(expression, ctx) };
}

test('creating a preview offer persists it only in this browser and says so', async () => {
  const p = portal('preview');
  p.draftOffer();
  await p.ctx.saveNewOffer(element());
  assert.equal(JSON.parse(p.storage.get('hungr_admin_offers')).at(-1).code, 'SAMPLE');
  assert.match(p.messages.at(-1), /browser only/i);
  assert.doesNotMatch(p.el('offers-container').children.at(-1).textContent, /active on app/i);
  assert.equal(p.writes.length, 0);
});

test('configured but unavailable Firestore never falls back to saving a preview', async () => {
  const p = portal('unavailable');
  p.draftOffer();
  await p.ctx.saveNewOffer(element());
  assert.equal(p.storage.size, 0);
  assert.equal(p.read('offers.length'), 0);
  assert.ok(p.el('add-offer-modal').classList.contains('open'));
  assert.match(p.messages.at(-1), /not saved/i);
});

test('cloud offer waits for acknowledgement; only a server snapshot changes the list', async () => {
  let acknowledge;
  const p = portal('cloud', () => new Promise(resolve => { acknowledge = resolve; }));
  p.snapshot('offers', []);
  p.draftOffer();
  const button = element();
  const saving = p.ctx.saveNewOffer(button);
  await p.ctx.saveNewOffer(button);
  assert.equal(p.writes.length, 1);
  assert.ok(button.disabled);
  assert.equal(p.messages.length, 0);
  assert.ok(p.el('add-offer-modal').classList.contains('open'));
  const { id, data } = p.writes[0];
  p.snapshot('offers', [[id, data]], { hasPendingWrites: true });
  assert.equal(p.read('offers.length'), 0);
  acknowledge();
  await saving;
  assert.match(p.messages.at(-1), /saved to Firestore/i);
  assert.ok(!p.el('add-offer-modal').classList.contains('open'));
  p.snapshot('offers', [[id, data]]);
  assert.equal(p.read('offers.length'), 1);
  p.snapshot('offers', []);
  assert.equal(p.read('offers.length'), 0);
  assert.equal(p.storage.size, 0);
});

test('a denied kitchen edit keeps the draft open, the confirmed prices intact and sends no event', async () => {
  const p = portal('cloud', async () => { throw new Error('permission-denied'); });
  const shop = { name: 'Sample kitchen', status: 'open', dishes: [{ name: 'Breakfast', price: 40 }] };
  p.snapshot('tiffin_shops', [['sample', shop]]);
  p.ctx.openEditShopModal('sample');
  p.el('edit-shop-status').value = 'closedToday';
  p.el('dish-price-0').value = '50';
  await p.ctx.saveShopChanges();
  assert.equal(p.writes.length, 1);
  assert.equal(p.read('shops[0].dishes[0].price'), 40);
  assert.equal(p.read('shops[0].status'), 'open');
  assert.equal(p.storage.size, 0);
  assert.equal(p.broadcasts.length, 0);
  assert.ok(p.el('edit-shop-modal').classList.contains('open'));
  assert.match(p.messages.at(-1), /not saved/i);
});

test('an unreadable catalog is not displayed as live from cache or demo data', () => {
  const p = portal('cloud');
  p.snapshot('offers', [['sample', { code: 'SAMPLE' }]], { fromCache: true });
  p.streams.get('offers').error(new Error('permission-denied'));
  p.snapshot('tiffin_shops', []);
  assert.equal(p.read('offers.length + shops.length'), 0);
  assert.match(p.el('firebase-status-pill').textContent, /unavailable/i);
});

test('public zone cards and manifests work without carrying driver contact records', () => {
  const p = portal('preview');
  assert.ok(p.read("ZONES.every(z => !('phone' in z || 'driver' in z || 'vehicle' in z))"));
  p.ctx.renderZones();
  const cards = p.el('zones-container').children;
  assert.ok(cards.length > 0);
  for (const card of cards) {
    assert.ok(!find(card, n => n.tag === 'button' && n.textContent === 'Call'));
    find(card, n => n.tag === 'button' && n.textContent.includes('Manifest')).click();
    const body = p.el('manifest-modal-body');
    assert.ok(body.children.some(stop => stop.innerHTML.includes('Breakfast Bags')));
    assert.ok(!body.innerHTML.includes('Phone:') && !body.innerHTML.includes('undefined'));
  }
});

test('with no map library the preview still renders kitchens, offers and the fallback map', () => {
  const p = portal('preview');
  assert.ok(p.el('shops-container').children.length > 0);
  assert.ok(p.el('offers-container').children.length > 0);
  assert.ok(p.el('khammam-map').innerHTML.includes('<svg'));
  assert.match(p.el('firebase-status-pill').textContent, /this browser only/i);
});

test('shop selection preserves literal labels and saves edits against the selected document ID', async () => {
  const p = portal('cloud');
  const id = `chef's "A & B"`;
  const shop = {
    name: `A & B's "Breakfast"`, tagline: 'Fresh &amp; early', zone: 'East & West',
    status: 'closedToday', closureReason: `Chef's holiday`, reopenDate: 'Friday',
    dishes: [{ name: 'Tea & toast (< 10 min)', price: 45 }], deliveryWindow: '7:00 – 7:30',
  };
  p.snapshot('tiffin_shops', [['other', { ...shop, name: 'Another kitchen' }], [id, shop]]);
  const card = p.el('shops-container').children[1];
  for (const text of [shop.name, shop.tagline, shop.zone, shop.closureReason, shop.dishes[0].name, shop.deliveryWindow]) {
    assert.ok(card.textContent.includes(text));
  }
  find(card, n => n.tag === 'button').click();
  assert.equal(p.el('edit-shop-id').value, id);
  assert.ok(p.el('edit-shop-dishes').textContent.includes(shop.dishes[0].name));
  // Admins type the hotel's own price; customers pay that plus Rs 5.
  const price = find(p.el('edit-shop-dishes'), n => n.tag === 'input');
  assert.equal(String(price.value), '40');
  price.value = '50';
  p.el('edit-shop-reason').value = 'Friday & Saturday';
  await p.ctx.saveShopChanges();
  assert.equal(p.writes[0].id, id);
  assert.equal(p.writes[0].data.dishes[0].price, 55);
  assert.equal(p.writes[0].data.closureReason, 'Friday & Saturday');
});

test('a blank or broken hotel price is refused instead of silently keeping the old price', async () => {
  const p = portal('cloud');
  p.snapshot('tiffin_shops', [['sample', { name: 'Sample kitchen', status: 'open', dishes: [{ name: 'Idli', price: 45 }] }]]);
  for (const typed of ['', '0', '12.5', '-3', '296']) {
    p.ctx.openEditShopModal('sample');
    p.el('dish-price-0').value = typed;
    await p.ctx.saveShopChanges();
    assert.equal(p.writes.length, 0, typed);
    assert.match(p.messages.at(-1), /Idli: .*hotel price/, typed);
    assert.ok(p.el('edit-shop-modal').classList.contains('open'));
  }
  p.el('dish-price-0').value = ' 45 ';
  await p.ctx.saveShopChanges();
  assert.equal(p.writes[0].data.dishes[0].price, 50);
});

test('offer punctuation is plain text and pause/delete target the selected offer', async () => {
  const p = portal('cloud');
  const id = `week's "A & B" offer`;
  const offer = { code: 'A&B', description: `Chef's "tea &amp; toast"`, type: 'flat', value: 5, minOrder: 20, isActive: true };
  const rows = [['other', { ...offer, code: 'OTHER' }], [id, offer]];
  p.snapshot('offers', rows);
  const card = p.el('offers-container').children[1];
  assert.ok(card.textContent.includes(offer.code) && card.textContent.includes(offer.description));
  await find(card, n => n.tag === 'button' && n.textContent.includes('Pause')).click();
  assert.equal(p.writes[0].id, id);
  assert.equal(p.writes[0].data.isActive, false);
  p.snapshot('offers', [rows[0], [id, { ...offer, isActive: false }]]);
  await find(p.el('offers-container').children[1], n => n.tag === 'button' && n.textContent.includes('Delete')).click();
  assert.equal(p.writes[1].id, id);
  assert.equal(p.writes[1].method, 'delete');
});

for (const outcome of ['rejected', 'accepted']) {
  test(`deleting the last offer retains it until its ${outcome} write settles`, async () => {
    const write = deferred(), p = portal('cloud', () => write.promise);
    p.snapshot('tiffin_shops', []);
    p.snapshot('offers', [['last', { code: 'LAST', isActive: true }]]);
    const list = p.el('offers-container');
    const deleting = find(list, n => n.tag === 'button' && n.textContent.includes('Delete')).click();
    // A query with no remaining documents can have hasPendingWrites=false before delete() settles.
    p.snapshot('offers', []);
    assert.ok(list.textContent.includes('LAST'));
    assert.doesNotMatch(p.el('firebase-status-pill').textContent, /catalog confirmed/i);
    if (outcome === 'rejected') {
      write.reject(new Error('permission-denied'));
      await deleting;
      assert.ok(list.textContent.includes('LAST'));
      assert.match(p.messages.at(-1), /not saved/i);
      assert.ok(!find(list, n => n.tag === 'button' && n.textContent.includes('Delete')).disabled);
    } else {
      write.resolve();
      await deleting;
      assert.ok(!list.textContent.includes('LAST'));
      assert.match(p.messages.at(-1), /saved to Firestore/i);
    }
  });
}

test('a late kitchen save cannot close or unlock a later editor session', async () => {
  const a = deferred(), b = deferred(), queue = [a, b];
  const p = portal('cloud', () => queue.shift().promise);
  const shop = { status: 'open', dishes: [] };
  p.snapshot('tiffin_shops', [['a', { ...shop, name: 'First' }], ['b', { ...shop, name: 'Second' }]]);
  const button = p.el('edit-shop-save');
  p.ctx.openEditShopModal('a');
  const savingA = p.ctx.saveShopChanges();
  assert.ok(button.disabled);
  p.ctx.closeEditShopModal();
  p.ctx.openEditShopModal('b');
  assert.ok(!button.disabled);
  p.el('edit-shop-reason').value = 'Second draft';
  const savingB = p.ctx.saveShopChanges();

  a.resolve();
  await savingA;
  assert.ok(p.el('edit-shop-modal').classList.contains('open'));
  assert.equal(p.el('edit-shop-id').value, 'b');
  assert.equal(p.el('edit-shop-reason').value, 'Second draft');
  assert.ok(button.disabled);
  assert.match(button.textContent, /waiting/i);
  assert.equal(p.messages.length, 0);
  assert.deepEqual(p.writes.map(w => w.id), ['a', 'b']);

  b.reject(new Error('permission-denied'));
  await savingB;
  assert.ok(!button.disabled);
  assert.ok(p.el('edit-shop-modal').classList.contains('open'));
  assert.match(p.messages.at(-1), /not saved/i);
});

test('kitchen counts distinguish an unreadable catalog from confirmed zero', () => {
  const p = portal('cloud');
  assert.equal(p.el('total-shops-kpi').innerText, '—');
  p.snapshot('tiffin_shops', [], { fromCache: true });
  p.streams.get('tiffin_shops').error(new Error('permission-denied'));
  assert.equal(p.el('total-shops-kpi').innerText, '—');
  assert.equal(p.el('open-shops-kpi').innerText, '—');
  assert.match(p.el('firebase-status-pill').textContent, /unavailable/i);

  const ready = portal('cloud');
  ready.snapshot('tiffin_shops', []);
  assert.equal(ready.el('total-shops-kpi').innerText, '0 Shops');
  assert.equal(ready.el('open-shops-kpi').innerText, '0 Open • 0 Closed');
});
