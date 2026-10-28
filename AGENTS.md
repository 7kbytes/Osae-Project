# Local Job Connector: guide for Codex

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


## Local development workflow

Flutter/Provider marketplace with Firebase Auth, Firestore and Hosting. Existing AGENTS.md and docs contain architectural and security rules; this section does not supersede them.

From the repo root in PowerShell:

- `powershell -File scripts/dev.ps1 doctor`: inspect prerequisite tools.
- `powershell -File scripts/dev.ps1 setup`: install dependencies using the existing lockfile/tool manifest.
- `powershell -File scripts/dev.ps1 check`: run the configured non-deploy checks; stops on failure.
- `powershell -File scripts/dev.ps1 build`: compile locally; never publishes.
- Add `-Plan` to print the commands without executing them. Doctor still inspects command availability.
- `powershell -File scripts/dev.ps1 rules`: run Firestore emulator rules tests.

The rules task uses the existing demo-ljc emulator test command. Application/admin e2e scripts are separate and must be inspected for target and cleanup behavior before running. Doctor requires Java for rules tests; Flutter web checks alone do not require Android SDK.

Keep setup and verification separate from deployment, production seeds and destructive migrations. Report checks that could not run and why. Preserve unrelated local changes. Use separate Git worktrees when simultaneous chats edit this repository.
