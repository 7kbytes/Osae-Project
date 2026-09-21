# Local Job Connector: Project Documentation

Local Job Connector is a Flutter app (web, Android, iOS) that connects people who need short-term or local work done in Ghanaian cities with people looking for it. The backend is Firebase (Auth, Firestore, Hosting). A web admin dashboard lives at `web/admin/`.

## Document map

| Doc | Purpose |
|---|---|
| [01-product-requirements.md](01-product-requirements.md) | Who it is for, what it must do, what is out of scope |
| [02-architecture.md](02-architecture.md) | Current state, target state, data model, environments |
| [03-security-and-compliance.md](03-security-and-compliance.md) | Risk register, Firestore rules plan, data protection |
| [04-roadmap.md](04-roadmap.md) | Phased plan with exit criteria |
| [05-admin-dashboard.md](05-admin-dashboard.md) | Admin requirements, roles, audit trail |
| [06-quality-and-release.md](06-quality-and-release.md) | Testing, CI/CD, monitoring, release process |
| [07-decisions-and-open-questions.md](07-decisions-and-open-questions.md) | Decisions to make before building; decision log |

## Where the project stands (audited 2026-09-20)

The UI and data models are largely built. The app is **not production ready**, because the backend integration is not real yet:

- Sign-in accepts any credentials and falls back to a made-up user (`AuthProvider`).
- `FirebaseService.initialize()` is never called, so repositories fall back to in-memory storage, and production probably never touches Firestore.
- Firestore rules let any signed-in user read and write all applications and chats.
- Tests mostly cover the in-memory and fallback paths.

Phase 0 and Phase 1 in the [roadmap](04-roadmap.md) fix these before any new feature work.

## Conventions

- Docs are Markdown in `docs/`, reviewed with code changes.
- A change that alters behaviour, data shape or security updates the relevant doc in the same pull request.
- Every non-trivial choice goes in the decision log in doc 07.
