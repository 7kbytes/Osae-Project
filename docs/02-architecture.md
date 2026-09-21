# 02. Architecture

## 1. Current state

```
Flutter app (provider state management)
  main.dart -> Firebase.initializeApp
  Providers (Auth, Job, Chat, Application)
    -> Repository interface
         |- Firestore*Repository   (real)
         |- InMemory*Repository    (fallback, used when FirebaseService.isInitialized == false)
    -> LocalStorageService (shared_preferences cache)
Firebase: Auth, Firestore, Hosting (build/web)
Web admin: web/admin/index.html (static, Firebase JS SDK)
```

The repository pattern is a good foundation: it lets tests swap the backend. The problem is that the fallback path is the *default* path in production (see doc 03, R1 and R2).

## 2. Target state

```
Flutter client (web, Android, iOS)
  Providers -> Repositories -> Firestore / Auth / Storage / FCM
                   |
Cloud Functions (trusted logic)
  - set custom claims (admin, role)
  - on application/status change -> send push
  - on report create -> notify admins
  - denormalised counters, rating aggregation
  - account deletion cascade
Firebase App Check on all clients
Admin dashboard -> same Firestore, gated by custom claim, actions written to auditLogs
```

Principles:
1. **No silent fallbacks in release builds.** Fake users and in-memory repositories exist only in tests and an explicit demo flavour.
2. **The server is the authority.** Security-relevant rules (who can change a role or an application status) are enforced by Firestore rules or Functions, never by the client alone.
3. **Environments are separate Firebase projects** (dev, staging, prod).

## 3. Environments

| Env | Firebase project | Purpose |
|---|---|---|
| dev | `local-job-connector-dev` (to create) | Daily development and emulators |
| staging | `local-job-connector-stg` (to create) | Release candidates, QA |
| prod | `local-job-connector-gh` (exists) | Live users |

Use Flutter flavours and `--dart-define` (or per-environment `firebase_options`) so one codebase targets each project. Local work uses the Firebase Emulator Suite (Auth, Firestore, Functions).

## 4. Data model (Firestore)

| Collection | Key fields | Notes |
|---|---|---|
| `users/{uid}` | displayName, phone, role, city, rating, avatarUrl, createdAt | Doc id must equal the Auth uid |
| `jobs/{id}` | title, description, category, payRate, payUnit, currency, city, locationName, lat, lng, posterId, posterName, posterPhone, status, isFilled, createdAt | Public read |
| `applications/{id}` | jobId, jobTitle, seekerId, seekerName, seekerPhone, posterId, status, note, appliedAt | Denormalised for listing |
| `chats/{id}` | jobId, jobTitle, seekerId, seekerName, posterId, posterName, lastMessage, updatedAt | Add `participants: [uid, uid]` for rules |
| `chats/{id}/messages/{id}` | senderId, senderName, text, timestamp, isRead | |
| `admins/{uid}` | role, email, createdAt | Interim admin gate (to be replaced by claims) |

### Planned changes
- **Timestamps:** dates are stored as ISO strings today. Move to Firestore `Timestamp` (or keep strings but sort consistently). Migration needed; `parseDateTime` already reads both.
- **`chats.participants`:** array of the two uids, so rules and queries can use `array-contains`.
- **Deterministic ids:** application id = `{jobId}_{seekerId}` to prevent duplicate applications; chat id = `{jobId}_{seekerId}`.
- **New collections:** `reports`, `auditLogs`, `deviceTokens` (or a `users/{uid}/tokens` subcollection), `reviews`.
- **Stop storing PII in job docs where avoidable.** `posterPhone` on a public job is a privacy issue. Move it to the poster's user doc and reveal it only after an accepted application. **[confirm]**
- **Indexes:** commit `firestore.indexes.json` (the `applications` queries need composite indexes on `seekerId`/`posterId` + `appliedAt`).
- **Pagination:** cursor-based (`startAfterDocument`) for jobs, applications, messages.

## 5. Client structure

Keep the current feature-first layout (`lib/features/*`, `lib/core/*`). Changes planned:
- Auth state driven by `FirebaseAuth.authStateChanges()`, not a boolean default of `true`.
- Repositories return typed errors; providers expose loading, error and empty states; screens render them.
- Fallbacks removed from `AuthProvider`; demo mode becomes an explicit flavour.
- Move hard-coded config (Maps key, project ids) to per-environment config.

## 6. Admin dashboard

Static single page today. Target: keep it dependency-light, gate by custom claim, log every action. Details in doc 05.

## 7. Third-party services

Firebase Auth, Firestore, Hosting, Cloud Functions, Cloud Messaging, Crashlytics, App Check; Google Maps Platform (key restricted per platform); optionally an SMS OTP provider through Firebase Phone Auth. Estimate costs before launch (doc 07).
