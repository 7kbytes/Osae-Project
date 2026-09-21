# 03. Security and Compliance

## 1. Risk register

Severity: **C**ritical, **H**igh, **M**edium. Status as of 2026-09-20.

| ID | Sev | Risk | Where | Fix | Status |
|---|---|---|---|---|---|
| R1 | C | Sign-in accepts any credentials and falls back to a fake user; the app starts already logged in | `auth_provider.dart` | Real auth only; `startAuthenticated: false`; surface errors | Fixed on branch phase-1-real-backend (tests pass); fake fallback user in the job detail screen removed 2026-09-21 |
| R2 | C | `FirebaseService.initialize()` never called, so repositories use in-memory data in production | `main.dart`, `firebase_service.dart` | Initialise once at startup, set flag, verify repositories switch | Fixed on branch phase-1-real-backend |
| R3 | C | Any signed-in user can read and write all `applications` and `chats` | `firestore.rules` | Scope to participants (section 3) | Rules written and tests authored; not yet run or deployed |
| R4 | H | Any signed-in user can update any job (including `posterId`) | `firestore.rules` | Owner-only update with field validation | Rules written, tests authored; not yet deployed |
| R5 | H | All user profiles (incl. phone numbers) readable by any signed-in user | `firestore.rules` | Public profile subset vs private fields | Rules written (owner-only read); tests authored; not yet deployed |
| R6 | H | Admin credentials and the service-account key were handled during development; the admin password was shown in chat | ops | Rotate the admin password and the service-account key; keep the key out of the working tree | **Open, do first** |
| R7 | H | Maps API key unrestricted | `AndroidManifest.xml`, `web/index.html` | Restrict by HTTP referrer and Android package and SHA-1 | Open |
| R8 | M | `google-services.json` and `firebase_options.dart` committed | repo | Acceptable for client config, but pair with App Check and per-env config | Open |
| R9 | M | No client-side or server-side input validation on writes | rules | Validate types, lengths, enums in rules | Open |
| R10 | M | Errors swallowed with `debugPrint`; failures invisible in release | providers | Error states and Crashlytics | Open |
| R11 | M | Agent working files and build caches tracked in git | `.agents/`, `.firebase/` | Remove from the repo, add to `.gitignore` | Open |
| R12 | M | Admin authorisation via a Firestore doc; no audit trail; no MFA | `web/admin` | Custom claims, `auditLogs`, MFA (doc 05) | Open |
| R13 | M | Deleting a user profile leaves the Auth account and related data | admin | Cloud Function cascade | Open |
| R14 | H | Job screen hard-coded `posterId: 'poster_001'`, chat screen hard-coded sender `seeker_001`, favourites used a default user id, so real writes were rejected or attributed to the wrong user | `create_job_screen`, `chat_room_screen`, favourites | Use the signed-in user everywhere | Fixed, verified live |
| R15 | H | Providers swallowed write failures (`catch (_) {}`) and kept the optimistic change, so users saw success for data that was never saved | `job_provider`, `application_provider`, `chat_provider` (message send) | Roll back and report failure | Fixed (unit tests); chat send fixed 2026-09-21 |
| R16 | H | `ApplicationProvider` never read from Firestore (local cache only), so posters never saw applicants | `application_provider` | Live streams bound to the signed-in user | Fixed, verified live |
| R17 | M | Chat room ids differed between client and Firestore; chat list showed the wrong party's name; chat and job providers were not bound to the signed-in user or role | chat and job providers | Deterministic `chat_<job>_<seeker>` ids, user-bound providers | Fixed, verified live |

## 2. Secrets policy

- Never commit service-account keys or admin passwords. `firebase-service-account.json` is gitignored but sits in the working folder; move it outside the repo and use `GOOGLE_APPLICATION_CREDENTIALS`, or use CI workload identity.
- Firebase web and Android API keys are identifiers, not secrets, but must be protected by App Check, restricted API scopes and rules.
- Rotate anything that has been pasted into chat, tickets or logs.

## 3. Firestore rules plan

Principle: default deny, then grant the minimum. Test every rule with the emulator (doc 06).

Helper functions: `isSignedIn()`, `isOwner(uid)`, `isAdmin()` (claim `admin == true`), `isParticipant(chat)`.

| Collection | Read | Create | Update | Delete |
|---|---|---|---|---|
| `users/{uid}` | Owner, admin; a public subset via a separate doc or callable | Owner (`id == uid`) | Owner, but **not** `role` escalation to `admin`; admin | Owner, admin |
| `jobs/{id}` | Anyone | Signed in, `posterId == auth.uid`, valid fields | Owner, `posterId` immutable; admin | Owner, admin |
| `applications/{id}` | Seeker, poster of the job, admin | Signed in, `seekerId == auth.uid`, status `pending` | Poster may change `status` only; seeker may withdraw; admin | Admin |
| `chats/{id}` | Participants, admin | Participant | Participant (`lastMessage`, `updatedAt` only) | Admin |
| `chats/{id}/messages/{id}` | Participants, admin | Participant, `senderId == auth.uid` | None | Admin |
| `reports/{id}` | Admin | Signed in | Admin | Admin |
| `auditLogs/{id}` | Admin | Admin (or Functions) | None | None |
| `admins/{uid}` | Self | None | None | None |

Field validation: strings length-bounded, enums checked (`role`, `status`), numbers non-negative, timestamps server-set where possible.

## 4. Authentication and abuse

- Firebase Auth email/password now; phone OTP planned. Enable email enumeration protection.
- App Check (Play Integrity, DeviceCheck, reCAPTCHA v3 on web) enforced on Firestore and Auth once clients ship.
- Rate limiting: rules cannot rate-limit alone; use Functions or App Check plus document-id patterns to block duplicate spam.
- Admin dashboard: enable MFA on admin accounts; short sessions; restrict `/admin` by claim, not obscurity.

## 5. Data protection (Ghana)

Ghana's Data Protection Act, 2012 (Act 843) regulates personal data and is overseen by the Data Protection Commission. To confirm with a lawyer before launch:

- Register as a data controller with the Commission.
- Publish a privacy policy and terms of service; get consent at sign-up; record consent time and version.
- Data minimisation: collect only name, phone, city, role. Don't expose phone numbers publicly (R5).
- Provide access, correction and deletion. Build a self-service "delete my account" flow (also required by Apple and Google store policies).
- Define retention: for example inactive accounts for 24 months, chat logs for 12 months after job completion, audit logs for 24 months.
- Breach response: written runbook (who decides, who is notified, within what time).
- Choose a Firestore region deliberately; note where the data is stored.

## 6. Moderation and safety

Report flow for jobs, users and messages; admin queue; ability to hide a job, suspend a user (needs an app-side check on a `suspended` flag), and warn users. Publish community guidelines and a prohibited-content list (scams, upfront-fee jobs, illegal work, discrimination).
