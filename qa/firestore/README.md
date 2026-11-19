# Firestore permission contract

Use Node 20+ and a **dedicated, disposable official Firestore emulator** bound to
IPv4 loopback, project `demo-hungr-policy`, database `(default)`, with the checkout's
root `firestore.rules` loaded. The coordinator starts/stops it. From the repo root,
substitute its actual port:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:<port>'
node --test .\qa\firestore\permissions.test.cjs
```

No installation, credentials, Auth emulator or Firebase login. The suite checks
the emulator's rule-coverage source before writing isolated synthetic fixtures.
It does not load rules, clear databases, or follow redirects. The owner-combo
test reports the **emulator's** current IST edit window; a run covers that side
of the nightly boundary, not a simulated clock.

## Required before launch

- **Provision staff roles in Firebase Auth** from a separately verified roster:
  the custom claim is `role: 'admin'` or `role: 'driver'`. Refresh ID tokens after
  provisioning. Do **not** copy `users.role` into claims; it was client-writable.
  The admin portal needs an authenticated admin, not just public catalog access.
- **Reconcile existing passes, tickets and driver assignments** against trusted
  purchase/dispatch records. Quarantine unverifiable records before exposing the
  ledger. A verified server issuer is required for purchases; the repository's
  client-side pass state is not an issuer. Neither customers nor admin clients
  can mint passes or tickets. Server SDK writes bypass rules: callable ownership,
  dates, payment verification and authorization need their own checks.
- Issue tickets with trusted `userId`, `deliveryDate` in the canonical UTC ISO format
  emitted by `functions/meal-scheduling.js`, and the actual `assignedDriverId` UID for
  dispatched tickets. For owner edits, a date-only `YYYY-MM-DD` or a Dart ISO
  date-time with no timezone suffix names the IST service day directly. A UTC ISO
  date-time ending in `Z` or a Firestore Timestamp represents an instant: convert
  it to IST before taking the date. For example, `2026-01-08T19:00:00Z` is a
  January 9 service day. Convert legacy numeric-offset strings to equivalent UTC
  instants before enabling owner edits; the rules do not accept those strings.
  Review assignments; don't grant all drivers access if an assignment is missing.
  Owners can switch A/B on scheduled tickets only, never change paid `addOns`.
  Both the nightly freeze and the previous-night deadline
  apply, so a missed kitchen lock cannot reopen yesterday's tickets.
- No driver manifest assignment schema or partner-to-shop binding was found.
  Those client roles have **no** manifest access or partner catalog writes,
  respectively; do not enable such workflows without trusted scoping. The portal's
  admin catalog writes and public menu reads remain available.
- The mobile profile sync writes **`clusterName`**, not a trusted routing
  `clusterId` or `fcmToken`. Before enabling cluster notifications, verify those
  server-consumed fields and clear any unverified legacy routing data. Do not
  broaden profile writes or customer profile listings for the notification job.
