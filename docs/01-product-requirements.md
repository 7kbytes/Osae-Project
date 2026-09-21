# 01. Product Requirements

Status: draft. Items marked **[confirm]** are assumptions to validate (see doc 07).

## 1. Problem and goal

People in Ghanaian cities (Accra, Kumasi, Tema) who need casual work done (cleaning, delivery, repairs, events) have no trusted, local way to find workers. Workers have no easy way to find nearby jobs. The goal is a mobile-first marketplace with clear job listings, direct application, and in-app chat.

## 2. Users

| Role | Description | Key needs |
|---|---|---|
| Seeker | Looks for work | Browse or map nearby jobs, apply, track applications, chat with posters |
| Poster | Offers work | Post jobs, review applicants, accept or reject, mark jobs filled or complete |
| Admin | Runs the platform | Moderate content, manage users, monitor health, handle reports |

A user has one active role at a time and can switch (`switchRole`). **[confirm]** whether one account may hold both roles at once.

## 3. Functional requirements

MoSCoW priority: **M**ust, **S**hould, **C**ould.

### Accounts and identity
- M: Sign up and sign in with real Firebase Auth. Failed authentication must never create a session.
- M: Profile: name, phone, city, role, avatar.
- S: Phone-number verification by SMS OTP. **[confirm]** Phone is the primary identity for many Ghanaian users; email may not be.
- S: Password reset, account deletion (self-service).
- C: Google sign-in on mobile (currently web popup only).

### Jobs
- M: Create, edit, close and delete own jobs with title, description, category, pay, city and location.
- M: Feed with search and filters (category, city, status); map view.
- M: Statuses: open, in progress, completed.
- S: Favourites synced to the account (currently local).
- C: Distance sorting, saved searches, job expiry.

### Applications
- M: Seeker applies with an optional note; one application per job per seeker.
- M: Poster views applicants and moves them through pending, accepted, rejected, completed.
- M: Seeker sees status changes.

### Chat
- M: One-to-one chat between seeker and poster, tied to a job.
- S: Unread counts and push notifications.
- S: Report a message or user.

### Trust and safety
- M: Report job or user; admin can review and act.
- S: Ratings and reviews after a completed job (the `rating` field exists but no flow updates it).
- C: Verified-poster badge.

### Notifications
- S: Push (FCM) for new application, status change, new message.

### Admin
See [05-admin-dashboard.md](05-admin-dashboard.md).

## 4. Non-functional requirements

| Area | Target |
|---|---|
| Availability | Managed services only; no self-hosted servers |
| Performance | Feed first paint under 2 s on a mid-range phone over 4G; lists paginated (page size 20 to 50) |
| Offline | Reads work from cache; writes queue and sync; clear offline banner |
| Security | Least-privilege Firestore rules verified by automated tests; no secrets in the repo |
| Privacy | Comply with Ghana's Data Protection Act, 2012 (Act 843). See doc 03 |
| Accessibility | Text scaling, contrast and screen-reader labels checked before launch |
| Observability | Crash reporting and error logging in release builds |
| Localisation | English at launch; currency GHS; local phone formats |

## 5. Out of scope for v1

In-app payments or escrow, video or voice calls, background checks, multi-country support. Revisit after launch metrics.

## 6. Success metrics

- Activation: percentage of new users who apply to or post a job within 7 days.
- Match rate: percentage of jobs receiving at least one application within 48 hours.
- Fill rate: percentage of jobs reaching accepted or completed.
- Health: crash-free sessions of at least 99.5%; report-handling time under 24 hours.

## 7. Release criteria for v1

All **M** items done and verified against real Firebase; Phase 0 to 3 exit criteria in the roadmap are met; security review passed.
