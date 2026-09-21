# 05. Admin Dashboard

## 1. Current state (v0)

Location: `web/admin/index.html`, served at `/admin/` after `flutter build web` and hosting deploy. Single file, Firebase JS SDK from the CDN, live Firestore listeners (limit 1000 per collection).

Implemented: email/password sign-in with an `admins/{uid}` check; overview statistics; users (search, role change, delete profile); jobs (status change, delete); applications (status change, delete); chats (read, delete messages or rooms); CSV export.

Known gaps: no audit trail, no MFA, no pagination beyond 1000 documents, no reports queue, cannot delete Auth accounts, authorisation by document lookup, no tests.

## 2. Roles

| Role | Can do |
|---|---|
| `superadmin` | Everything, including managing admins |
| `moderator` | Handle reports, hide jobs, suspend users, read chats tied to a report |
| `support` | Read-only on users, jobs and applications; no chat access |

Implemented as Firebase custom claims (`{role: 'moderator'}`) set by a Cloud Function callable only by a superadmin. Rules check the claim. This replaces the `admins` collection.

## 3. Requirements for v2

### Must
- Custom-claim roles and least-privilege permissions per role.
- **Audit log:** every write (who, what, target id, before and after, time, reason) into `auditLogs`. Written by a Cloud Function or by rules-enforced batch, and immutable.
- **Reports queue:** list, assign, resolve with a reason; deep links to the reported job, user or message.
- Suspend or unsuspend users (client honours `suspended`), hide jobs.
- Delete user, including the Auth account and related data, via a Cloud Function (Admin SDK).
- MFA required for admin accounts; session timeout.
- Confirmation dialogs for destructive actions, with a required reason for moderation actions.

### Should
- Server-side pagination and search (Algolia or Typesense if Firestore filtering is too limiting).
- Time-series metrics: signups, jobs and applications per day; fill rate; time to first application.
- Bulk actions; saved filters.
- Access to chat content only through a report, with the access itself logged (privacy).

### Could
- Broadcast notifications; category and city management; feature flags via Remote Config; admin management screen.

## 4. Non-functional

- Do not rely on hidden URLs; every check is server-enforced (rules, claims).
- No inline user content rendering without escaping (already done through `esc()`); add a Content Security Policy header in `firebase.json`.
- Add `X-Frame-Options`/`frame-ancestors` and `Referrer-Policy` headers for `/admin/**`.
- Move to a proper build (Vite plus TypeScript) when the page exceeds roughly 1,000 lines, so it can be unit tested. Until then, keep it single-file.
- Tests: rule tests for each role; a Playwright smoke test (sign-in, list, change status, delete) against the emulator.

## 5. Operating procedures

- Create the first superadmin with a one-off script run by the owner. Never through the UI.
- Rotate admin credentials on staff changes; review the admin list monthly.
- Review the audit log weekly.
