# Local Job Connector: guide for Claude Code

Flutter (web, Android, iOS) marketplace for local jobs in Ghana. Backend: Firebase (Auth, Firestore, Hosting). Web admin dashboard: `web/admin/index.html`. Project Firebase id: `local-job-connector-gh`.

**Read `docs/` first.** It holds the requirements, architecture, risk register, roadmap and decision log. The current phase is Phase 0 (foundation) then Phase 1 (make the backend real); see `docs/04-roadmap.md`.

## Commands
- `flutter pub get`, `flutter analyze`, `flutter test`, `dart format lib test`
- `flutter build web` (output `build/web`; `web/` contents such as `web/admin/` are copied in)
- `firebase emulators:start` (Auth 9099, Firestore 8081, UI 4000)
- Deploys go to production: `firebase deploy --only firestore:rules` / `hosting`. Never deploy without the user asking.

## Layout
- `lib/core/{models,providers,repositories,services,utils,widgets}`, `lib/features/<feature>/screens|widgets`
- State: `provider` (ChangeNotifier). Data access: repository interface with `Firestore*` and `InMemory*` implementations.
- Tests in `test/`; `firestore.rules`, `firestore.indexes.json`, `firebase.json` at the root.

## Rules of engagement
1. Match surrounding code style; run `dart format` and `flutter analyze` before finishing.
2. Never add silent fallbacks that fake a user or data in release builds (risks R1, R2 in docs/03).
3. Any change to Firestore rules needs rule tests and an update to the matrix in docs/03.
4. Behaviour, data-shape or security changes update the matching doc in the same change.
5. Secrets: never read, print or commit `firebase-service-account.json`, `.env*`, or passwords. Use `GOOGLE_APPLICATION_CREDENTIALS` and only when the user explicitly authorises it.
6. Confirm before anything outward-facing or destructive: deploys, deleting Firebase data or users, force pushes, publishing.
7. Report test failures honestly; do not weaken tests to make them pass.

## Known issues (see docs/03 for the register)
Sign-in falls back to a fake user; `FirebaseService.initialize()` is never called; rules are too permissive. Do not build new features on top of these without fixing or flagging them.
