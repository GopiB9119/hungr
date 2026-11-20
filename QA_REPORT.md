# Hungr launch review — 19 November 2026

**Decision: do not take real orders yet.** The app can show a menu and an
estimate. It cannot verify a payment or issue a purchased meal. Disabling false
success messages is a fix; it is not a payment integration.

## What changed

The starting point was `133824f` on `main`, not a merge commit. The repo had one
Flutter test file, no Functions dependency lock, and no open GitHub issues or
pull requests at intake. Five implementation owners reviewed identity, orders,
access rules, kitchen operations and the portal. Separate reviewers checked the
mobile, service and portal changes. Tests used local fixtures, never customers.

The table groups related symptoms by cause. “Fixed” refers to this checkout,
not any already-installed app, published website or deployed cloud project.

| Area | Normal input → original result | Result of this pass |
|---|---|---|
| Customer privacy and staff access | A signed-in customer could read unrelated profiles (`allow read: if isAuthenticated()`). Staff permissions trusted editable profile fields. | Owner/admin profile reads; staff authority comes from server-issued Auth claims. Confirmed with the [local permission suite](qa/firestore/permissions.test.cjs). |
| Meal credits and dispatch | Client writes could issue entitlements; driver access was not limited to assigned tickets. Operational callables did not check staff identity before using the server SDK. | The server must issue passes/tickets; driver updates are scoped. Broadcast and failover require an admin claim. See [rules](firestore.rules), [callable guard](functions/ops-access.js), and [staff migration notes](qa/firestore/README.md). |
| Sign-in and sign-out | The app treated a local sign-in flag as an alternative to a Firebase user (`currentUser != null \|\| isAuth`). | A cached flag is not an entitlement to customer screens. SMS failures are visible. Manual and automatic verification share a customer-profile path. See [identity tests](test/identity_session_test.dart). |
| Checkout and customer records | A checkout animation could confirm a purchase, and a new customer started with `hasActivePass: true`. History, tickets and referral rewards looked real. | Checkout is an estimate, the cart is retained, and fake passes, receipts and delivery proof are not issued. See [checkout](test/orders_checkout_test.dart) and [entitlement](test/orders_entitlements_test.dart) tests. |
| Rescheduling and kitchen time | Overlapping skip requests could create two replacement credits. The kitchen cron used `31 15` **and** `Asia/Kolkata`, locking tomorrow's meals at 15:31 local, not 21:01. Failover selected locked tickets without restricting their day. | [Scheduling](functions/meal-scheduling.js) uses transactions, per-pass checks, and the 21:01 IST schedule. The [kitchen plan](functions/kitchen-plan.js) counts companion portions, keeps households together, and stops without partial writes when the batch cannot fit. A failover is restricted to the intended kitchen and service day. The [index](firestore.indexes.json) is included. |
| Admin portal | A browser-only edit could look published. A rejected write looked saved. Contact/vehicle details were embedded in public assets. Punctuation in identifiers could break selection. | Cloud success waits for acknowledgment. Preview actions are labeled, identifying contact/vehicle fields were removed, and catalog text is rendered as text. [Offline tests](qa/admin/catalog.test.cjs) cover these flows. Removing source does not retract previously served copies. |
| Builds and cutoff edge cases | The production Dart query used JavaScript argument syntax; the original tests called APIs that did not exist. The countdown did not advance at the exact cutoff and the urgency threshold rounded too early. | Repaired query and tests, with deterministic IST boundaries, year rollover and an exact 30-minute threshold. The test for catalog events is not an end-to-end Firebase test. |
| Release configuration and claims | Functions targeted decommissioned Node 18. Two linked web launcher icons did not exist. The store draft and app promised payment and deletion features that did not exist. | Node 22 and portable lockfile, valid bundled icons, reduced unused Android permissions and [unpublished store copy](STORE_LISTING.md). No credentials or signing keys added. |

## Before the first paying customer

1. **Founder + payments engineer:** choose the payment provider and refund policy.
   On a trusted backend, price from the selected shop, verify payment, reserve
   capacity and issue the order/pass exactly once. Handle retries, declined
   payments, cancellations and refunds. Reconcile receipts with the ledger.
   `CartState.itemsSubtotal` currently uses a static item lookup; it is not a
   production price quote.
2. **Operations:** choose what happens when the kitchen cannot fill a paid order
   (including companion meals). Test cutover with existing batches, expiry,
   skips and reassignment. Agree who handles shortages before collecting money.
3. **Firebase owner:** provision a separate staging project and named test staff.
   Review old profiles, passes, assignments and notification routing against
   trusted records. Do not copy client-written roles into claims. Provision and
   verify the index, grant only the needed staff permissions, test admin sign-in,
   and confirm phone verification on a signed Android build. Do not switch live
   rules independently of this migration.
4. **Privacy/support owner:** build and verify account deletion and retention for
   Auth, profile data and associated records. Signing out is not deletion. Verify
   staff contact details, public copy, support routes and privacy notices with
   the people responsible before publishing.
5. **Release owner:** test backup/restore, rate limits, SMS spending alerts,
   incident contacts, notification delivery and rollback in staging. Reconcile
   the transitive dependency advisory below. Do not infer cloud safety from
   green local tests.

## Verification

Baseline on Flutter 3.47.9: **zero tests ran** because compilation failed;
`flutter analyze` reported **17 errors**. Lock enforcement was preserved rather
than rewriting `pubspec.lock` to suit the older default SDK. Functions initially
parsed, but `npm audit` could not run without a lock.

- Final mobile suite: **24/24 passed**; `flutter analyze --no-pub` found
  **no issues**. The suite covers session recovery, UID and
  gate changes, preservation of a confirmed gate during a delayed startup read,
  single-day and pass checkout, absence of unverified entitlements, the cutoff,
  and offline catalog updates.
- Final artifacts: Flutter release web build and Android debug APK both built
  successfully. A clean local browser rendered the release customer sign-in
  screen without a session or app configuration; the browser allowed only
  public font assets and the version-pinned Firebase SDK modules, not any
  Firebase data endpoint.
- Clean Functions install: 239 dependencies; Node 22.23.5 loaded all four
  exports without invoking an operation. [Google's runtime table](https://cloud.google.com/functions/docs/runtime-support)
  confirms Node 22 supports first-generation Functions.
- Dependency check: the npm audit endpoint was rate-limited. OSV matched
  **one moderate advisory**, [GHSA-w5hq-g745-h8pq](https://osv.dev/vulnerability/GHSA-w5hq-g745-h8pq),
  on transitive `uuid` 9.0.1 and 10.0.0 across 228 unique locked npm
  package/version pairs. The advisory affects the `v3`, `v5`, and `v6` APIs
  when writing into caller-supplied buffers. Static inspection found Firebase
  Admin's Eventarc helper imports and uses only `v4`; it did not find calls to
  the affected buffer APIs in the Firebase packages checked. **This advisory
  is present in the dependency tree, but its affected code path was not found
  in this app.** Do not silently force a cross-major UUID override. Upgrade
  the owning SDKs when a compatible release is available and rerun the audit.
  No high/critical match was returned; this was not a full supply-chain audit.
- Five rules scenarios passed on the official Firestore emulator (1.20.4),
  loopback only. The real emulator clock exercised the **closed** side of the
  IST window; the client and scheduler also have deterministic boundary tests.
- All **20 Functions tests** passed on Node 22, including a second run with the
  host set to `America/Los_Angeles`. All **13 admin tests** passed, including a
  rejected delete, a late save after changing editors, and a failed initial read.
- In a clean browser with external requests blocked, the admin portal opened
  without its CDN dependencies. A preview offer containing an apostrophe and
  `&` saved, rendered literally and persisted on reload with no unhandled error.

**Android device limitation:** the Android package built, but the dedicated API
36 emulator did not report a completed boot over its private ADB connection
in two attempts. No first-run or reopen result is claimed on Android. A signed
store bundle was not produced; release keys and live Firebase configuration
were not supplied or sought.

**Not tested:** live SMS, real payments, production data/rules, real driver
dispatch, legal compliance, store submission, production load or a real
customer delivery. No contact was made with a live Firebase project, no
message was sent to a customer, and nothing was deployed or pushed.
