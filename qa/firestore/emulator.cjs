'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { randomUUID } = require('node:crypto');

const project = 'demo-hungr-policy';
const documents = `projects/${project}/databases/(default)/documents`;
const run = randomUUID();
const id = label => `qa-${run}-${label}`;
const host = /^127\.0\.0\.1:([1-9]\d{0,4})$/.exec(process.env.FIRESTORE_EMULATOR_HOST || '');
assert.ok(host && Number(host[1]) <= 65535, 'Set FIRESTORE_EMULATOR_HOST to 127.0.0.1:<dedicated emulator port>');
const agent = new http.Agent({ proxyEnv: {} }); // No environment proxy, DNS, redirects or credential discovery.

function request(method, path, token, body) {
  return new Promise((resolve, reject) => {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const req = http.request({ hostname: '127.0.0.1', port: host[1], agent, method, path, headers }, res => {
      let text = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { text += chunk; });
      res.on('error', reject);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: text && JSON.parse(text), method, path }); }
        catch { reject(new Error('Expected JSON from the official Firestore emulator')); }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => req.destroy(new Error('Loopback emulator timed out')));
    req.end(body === undefined ? undefined : JSON.stringify(body));
  });
}

async function expect(response, status = 200) {
  const { status: actual, data, method, path } = await response;
  assert.equal(actual, status, `${method} ${path}: expected ${status}, received ${actual}`);
  const rows = Array.isArray(data) ? data : [data]; // runQuery is a streaming response.
  if (status === 403) assert.ok(rows.some(row => row?.error?.status === 'PERMISSION_DENIED'));
  if (status === 200) assert.ok(rows.every(row => !row?.error), 'Unexpected error in response');
  return data;
}

async function verifyEmulator() {
  // Read only: don't replace active rules or clear a database. Fail before any fixture writes.
  const coverage = await expect(request('GET', `/emulator/v1/projects/${project}:ruleCoverage`));
  const source = readFileSync(join(__dirname, '..', '..', 'firestore.rules'), 'utf8');
  const normalize = text => text.replaceAll('\r\n', '\n').trimEnd();
  assert.ok(coverage.rules?.files?.some(file => normalize(file.content) === normalize(source)),
    'Dedicated emulator must already be serving this checkout’s firestore.rules');
}

// Standard emulator mock-auth context. No Auth service, real user or signing key.
function actor(label, role) {
  const uid = id(label);
  const iat = Math.floor(Date.now() / 1000);
  const claims = { sub: uid, user_id: uid, aud: project, iss: `https://securetoken.google.com/${project}`,
    iat, exp: iat + 3600, auth_time: iat, firebase: { sign_in_provider: 'custom', identities: {} }, role };
  const encode = obj => Buffer.from(JSON.stringify(obj)).toString('base64url');
  return { uid, token: `${encode({ alg: 'none', typ: 'JWT' })}.${encode(claims)}.` };
}

function value(v) {
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  assert.equal(typeof v, 'string', 'Only string and string-list fixtures are used');
  return { stringValue: v };
}

const api = (method, suffix, who, body) => request(method, `/v1/${documents}${suffix}`, who?.token, body);
const get = (who, path) => api('GET', `/${path}`, who);
const remove = (who, path) => api('DELETE', `/${path}`, who);
const commit = (who, write) => api('POST', ':commit', who, { writes: [write] });

function write(who, path, data, { mode = 'update', timestamps = [] } = {}) {
  const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)]));
  const change = { update: { name: `${documents}/${path}`, fields } };
  if (mode === 'update') change.updateMask = { fieldPaths: Object.keys(fields) };
  if (mode !== 'seed') change.currentDocument = { exists: mode === 'update' };
  if (timestamps.length) change.updateTransforms = timestamps.map(fieldPath => ({ fieldPath, setToServerValue: 'REQUEST_TIME' }));
  return commit(who, change);
}

// Reserved emulator-only admin context for initial document fixtures, never a subject under test.
const seed = (path, data) => expect(write({ token: 'owner' }, path, data, { mode: 'seed' }));

function query(who, collection, field) {
  const structuredQuery = { from: [{ collectionId: collection }] };
  if (field) structuredQuery.where = { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: value(who.uid) } };
  return api('POST', ':runQuery', who, { structuredQuery });
}

module.exports = { id, actor, verifyEmulator, expect, seed, write, get, remove, query };
