# Hungr

Morning tiffin delivery for Khammam. The Flutter customer app is in `lib/`,
the static operations portal in `web_admin/`, and the Firebase backend in
`functions/`. **This is a pre-launch build:** customers can review an estimate,
but the app does not collect money or issue paid meal passes.

## Local checks

Use the committed lockfiles. The mobile QA run used Flutter 3.47.9; the Functions
runtime is Node 22. From the repository root in PowerShell:

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
npm --prefix functions ci --ignore-scripts
npm --prefix functions test
node --test qa\admin\catalog.test.cjs
```

For Firestore permission tests, use a **disposable local emulator** as described
in [the permission contract](qa/firestore/README.md). Nothing above requires
live SMS, a payment account, production credentials, or deployment.

The [launch-readiness report](QA_REPORT.md) lists the evidence, what remains
unsafe to launch, and the next work in priority order.
