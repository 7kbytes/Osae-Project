# 06. Quality and Release

## 1. Testing strategy

| Layer | Tool | What it proves | Target |
|---|---|---|---|
| Unit | `flutter test` | Models, validators, provider logic | Meaningful coverage of `core/` (aim for 80%) |
| Widget | `flutter test` | Screens render loading, error, empty and data states | All feature screens |
| Firestore rules | Emulator plus `@firebase/rules-unit-testing` | A user cannot read or write what they shouldn't | Every row of the doc 03 matrix, allow and deny |
| Integration | `integration_test` against the emulators | End-to-end flows (sign-up, post, apply, accept, chat) | Golden paths |
| Admin | Playwright against the emulators | Admin flows and role limits | Smoke suite |
| Manual | Device matrix | Low-end Android, iOS, Chrome, Safari | Before each release |

Existing tests: 17 files, many adversarial and empirical suites that exercise fallbacks. Audit them in Phase 1: keep useful ones, delete those that only assert the fake-auth behaviour, add a test that a wrong password is **rejected**.

Definition of done for a change: code plus tests plus docs; analyzer clean; CI green; reviewed.

## 2. CI/CD (GitHub Actions)

On every pull request:
1. `flutter pub get`, `flutter analyze`, `dart format --set-exit-if-changed`
2. `flutter test --coverage`
3. Start the emulators, run rule tests and integration tests
4. Build web (smoke check)

On merge to `main`: deploy to **staging** (hosting, rules, functions). On a version tag: deploy to **prod** after manual approval. Android and iOS builds via Fastlane or Codemagic; store uploads to the internal track.

Secrets live in GitHub Actions secrets or workload identity federation, never the repo.

## 3. Versioning and branching

Trunk-based development with short-lived branches and pull requests. Semantic versioning (`1.2.0+build`); tag releases; keep a `CHANGELOG.md`. Commit messages in the imperative mood.

## 4. Observability

- Crashlytics for the app; Firebase Performance for start-up and screen traces.
- Cloud Functions logs and error alerts.
- GCP budget alerts (50%, 90%, 100%) and Firestore read/write anomaly alerts. A bad query loop is the most likely cause of surprise cost.
- Dashboards for the success metrics in doc 01 (Analytics events: `sign_up`, `job_posted`, `application_sent`, `application_accepted`).

## 5. Backup and recovery

- Scheduled Firestore exports to a Cloud Storage bucket (daily, 30-day retention); point-in-time recovery enabled.
- Restore drill once before launch and once per quarter.
- Rollback: Hosting supports instant rollback; keep the previous rules and functions versions tagged.

## 6. Release process

1. Freeze; cut a release branch or tag on `main`.
2. Deploy to staging; run the manual checklist.
3. Approve; deploy rules and functions first, then hosting, then submit mobile builds.
4. Staged rollout on stores; watch crash-free rate and error logs for 24 hours.
5. Publish the changelog; close the milestone.

## 7. Launch checklist

- [ ] All Critical and High risks in doc 03 closed
- [ ] Rules tests green; App Check enforced
- [ ] Privacy policy, terms and consent flow live; deletion flow works
- [ ] Data controller registration submitted
- [ ] Maps key restricted; no secrets in the repo history that are still valid
- [ ] Crashlytics receiving events from a release build
- [ ] Backups and restore drill done
- [ ] Budget alerts set
- [ ] Admin MFA on; audit log verified
- [ ] Store listings, screenshots, support contact ready
- [ ] Runbooks written; owner on call named
