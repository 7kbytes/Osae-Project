# 04. Roadmap

Phases are sequential; each has exit criteria that must be met before the next starts. Durations are rough estimates for one or two developers and will be revised after Phase 0.

## Phase 0: Foundation and hygiene (about 3 to 5 days)

Goal: a safe, reproducible base.

- Rotate the admin password and the service-account key (R6); keep the key out of the repo.
- Remove `.agents/`, `.firebase/`, scratch docs from git; fix `.gitignore`.
- Create dev and staging Firebase projects; add Flutter flavours and per-env config.
- Set up the Firebase Emulator Suite; add `firestore.indexes.json`.
- CI: analyze, format check, unit and widget tests on every pull request.
- Branch protection on `main`; pull request template; CODEOWNERS.
- Restrict the Maps key (R7).

Exit: a new developer can clone, run `flutter test`, start the emulators and run the app in under 30 minutes; CI is green.

## Phase 1: Make the backend real (about 1 to 2 weeks)

Goal: the app actually uses Firebase and fails safely.

- Initialise Firebase once and drive auth from `authStateChanges` (R1, R2).
- Remove fake-user fallbacks from release builds; add explicit demo flavour.
- Loading, error and empty states on all screens; Crashlytics.
- Deterministic ids for applications and chats; `participants` array on chats.
- Rewrite Firestore rules per doc 03 with emulator rule tests (R3 to R5, R9).
- Data migration script for existing documents (dates, participants).
- Rewrite tests so they exercise the Firestore path (emulator), not only fallbacks.

Exit: with the emulator, sign-up, post job, apply, accept, chat work end to end; wrong password is rejected; rule tests prove a user cannot read another user's chats or change another's job.

### Phase 1 status (2026-09-21)
Done and verified on the live site with Playwright: real sign-in, wrong-password rejection, session restore, post job, apply, chat (create and reply), poster review and accept, admin dashboard, and the deployed Firestore rules and indexes. Found and fixed R14 to R17 through those tests.
Remaining: loading, error and empty states on all screens; data migration for existing documents; a repeatable end-to-end suite in the repo (currently ad-hoc scripts); Google sign-in on mobile; seeker-side status refresh check.

### Phase 1 close-out (2026-09-21, branch phase-2-account-and-resilience)
Done: loading and error states on the job feed (with retry); repeatable end-to-end suite in `e2e/` (5 scripts, 35 checks, all passing against the live site); a bug where the poster's applications and chat list were empty is fixed.
Still open: loading and error states on the remaining screens; data migration (not needed yet: production holds only test data); seeker-side "accepted" refresh check; Google sign-in on mobile.

## Phase 2: Core product completion (about 2 to 3 weeks)

Status: password reset (forgot password on the login screen) and self-service account deletion are done and verified live. Jobs posted by a deleted user are not removed yet (needs a Cloud Function, R13). Still to do: phone OTP, pagination, profile editing and avatars, push notifications, reports flow.

- Phone verification (OTP) and password reset; account deletion.
- Pagination, search, filters, map clustering.
- Favourites synced to the account.
- Profile editing and avatar upload (Storage rules).
- Push notifications for applications and messages.
- Reports flow (client side) and `reports` collection.

Exit: all **M** and agreed **S** items in doc 01 verified on staging.

## Phase 3: Admin dashboard v2 (about 1 to 2 weeks)

See doc 05: custom-claim roles, audit log, reports queue, suspend user, Auth account management via Functions, MFA, deployed and gated.

Exit: an admin can resolve a report end to end and every action appears in the audit log.

## Phase 4: Hardening and launch readiness (about 1 to 2 weeks)

- App Check enforced; abuse and cost alerts; budget alerts on GCP.
- Accessibility, performance and device testing (low-end Android).
- Privacy policy, terms, consent capture, deletion flow, data controller registration.
- Store assets and listings; internal, then closed testing tracks.
- Load and cost test with realistic data volumes.
- Runbooks: incident response, backups (scheduled Firestore export), rollback.
- Security review against the risk register; all C and H closed.

Exit: launch checklist in doc 06 complete.

## Phase 5: Launch and iterate

Staged rollout (5%, 25%, 100%), monitor crash-free rate and metrics from doc 01, weekly triage, then plan ratings, payments and expansion based on data.

## Milestone summary

| Milestone | Contents | Gate |
|---|---|---|
| M0 | Phase 0 | CI green, envs ready |
| M1 | Phase 1 | Real backend, rules tested |
| M2 | Phase 2 | Feature complete on staging |
| M3 | Phase 3 | Admin v2 |
| M4 | Phase 4 | Launch checklist |
| M5 | Phase 5 | Live |
