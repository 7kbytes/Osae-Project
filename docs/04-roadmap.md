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
Update: loading and error states (with retry) added to My Applications and the chat list, backed by `loadError`/`retryLoad` on `ApplicationProvider` and `ChatProvider`; My Applications no longer falls back to the `seeker_001` demo id. Chat messages that the backend rejects are now removed and reported instead of staying on screen (R15). Analyze clean; 225 tests pass.
Update: job detail, applicant review, favourites and map now show loading and error states with retry. Job detail no longer acts as a fake "Kofi Mensah / seeker_001" user when signed out: Apply and Chat are disabled instead (R1; widget test added). 226 tests pass.
Update: the chat room shows loading and error (with retry) for its messages; a chat room the backend refuses to create is removed and reported ("Go back"); `ChatProvider` now requires the signed-in user id instead of defaulting to `seeker_001`. 228 tests pass. Loading and error states are now on every screen.
Still open: data migration (not needed yet: production holds only test data); seeker-side "accepted" refresh check; Google sign-in on mobile.

## Phase 2: Core product completion (about 2 to 3 weeks)

Status: password reset (forgot password on the login screen) and self-service account deletion are done and verified live. Jobs posted by a deleted user are not removed yet (needs a Cloud Function, R13). Reports flow done and verified live (2026-09-21): seekers can report a job (reason and details), reports land in the admin dashboard Reports queue where an admin can dismiss, resolve or remove the job; Firestore rules and 4 rule tests cover it. Profile editing done (2026-09-21): name, phone and city from Profile > Edit Profile, via a field-limited `updateProfile` write; rules now stop owners changing their own `rating` or `createdAt` (2 new rule tests, 26 pass). The rules change was **deployed to production on 2026-09-22**. Pagination done (2026-09-21): the live job feed loads 20 jobs at a time ("Load more jobs" adds 20); jobs outside the loaded pages (opened from an application or a favourite) are fetched by id, and edits work on them too. City and category filters moved into the Firestore query on 2026-09-22, with three composite `jobs` indexes deployed, so a filter searches every matching job and paging restarts within the filter. Search moved into the query on 2026-09-22 too: each job stores a bounded `searchTerms` array of word prefixes (title, location, category, city) matched with `array-contains`, debounced by 350ms, with four more composite indexes deployed. Limitation: matching starts at word boundaries, so "leaning" does not find "Cleaning", and the description is not indexed; both need a search service (Algolia/Typesense). Jobs created before this change have no keywords: run `scripts/backfill-search-terms.mjs` once per environment (needs service-account credentials, see docs/03 section 2). Still to do: phone OTP (needs Phone sign-in enabled in Firebase and the paid Blaze plan), avatars (needs Cloud Storage, which requires the Blaze plan), push notifications. Reporting users and messages done (2026-09-22): a shared report dialog files reports on a job, an employer (from job detail or the chat header) or a single message (long-press the other party’s message); all three land in the admin Reports queue, which already handles any target type. Removing or suspending a reported user is Phase 3 work; the admin can currently resolve, dismiss or delete such a report and remove reported jobs.

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
