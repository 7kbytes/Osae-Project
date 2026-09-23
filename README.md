# Local Job Connector

A marketplace for informal and short-term work in Ghana, built for Accra, Kumasi and Tema. Job posters advertise gigs; job seekers browse, search and apply, then arrange the work in chat. Flutter on the front end (web, Android, iOS), Firebase behind it.

[![CI](https://github.com/7kbytes/Osae-Project/actions/workflows/ci.yml/badge.svg)](https://github.com/7kbytes/Osae-Project/actions/workflows/ci.yml)

## Links

| | |
|---|---|
| Live web app | https://local-job-connector-gh.web.app |
| Admin dashboard | https://local-job-connector-gh.web.app/admin/ (sign-in required) |
| Repository | https://github.com/7kbytes/Osae-Project |
| Firebase console | https://console.firebase.google.com/project/local-job-connector-gh |
| Firebase project id | `local-job-connector-gh` |

## What works today

Email sign-up and sign-in with real credential checks, password reset, and self-service account deletion. Posting a job, browsing a paginated feed, filtering by city and category, searching, saving favourites, and a map view. Applying to a job, the poster reviewing and accepting applicants, and one-to-one chat per application. Reporting a job, a person or a single message into an admin review queue. An admin dashboard over users, jobs, applications, chats and reports.

Firestore security rules are written, tested against the emulator and deployed. See [`docs/04-roadmap.md`](docs/04-roadmap.md) for what is done and what is not, and [`docs/03-security-and-compliance.md`](docs/03-security-and-compliance.md) for the risk register.

Not yet built: phone OTP, push notifications, profile photos, and a server-side cascade when an account is deleted. Each needs Firebase's paid Blaze plan.

## Getting started

Requires the Flutter SDK (Dart `^3.12.2`), Node.js, and a JDK (the Firestore emulator needs Java).

```bash
git clone https://github.com/7kbytes/Osae-Project.git
cd Osae-Project
flutter pub get
flutter run            # or: flutter run -d chrome
```

The app talks to the production Firebase project by default. To work against local emulators instead:

```bash
firebase emulators:start      # Auth 9099, Firestore 8081, Hosting 5000, UI 4000
```

## Everyday commands

```bash
flutter analyze                    # static analysis; keep it clean
flutter test                       # unit and widget tests
dart format lib test               # formatting, enforced by CI
flutter build web                  # output in build/web

cd rules-tests && npm install && npm test    # Firestore rules tests (emulator)
cd e2e && npm install && npm test            # end-to-end suite against the live site
```

CI runs formatting, analysis, the test suite, a web build and the rules tests on every push and pull request.

## Project layout

```
lib/
  app/           theme
  core/
    models/         data classes (JobPost, AppUser, Report, chat, application)
    providers/      ChangeNotifier state (auth, jobs, applications, chat)
    repositories/   data access, each with a Firestore and an in-memory implementation
    services/       Firebase init, local storage, location
    utils/          validators and input sanitising
    widgets/        shared widgets
  features/<feature>/screens|widgets
test/            unit and widget tests
rules-tests/     Firestore rules tests (Node, emulator)
e2e/             end-to-end scripts against a deployed site
web/admin/       admin dashboard (single static page)
docs/            requirements, architecture, security, roadmap, decisions
scripts/         one-off maintenance scripts
firestore.rules, firestore.indexes.json, firebase.json
```

State is managed with `provider`. Every repository has a Firestore implementation and an in-memory one, so tests and demo mode run without a backend.

## Deploying

```bash
flutter build web
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

These deploy straight to production; there is no staging project yet. Note that pushing code does not deploy the site — hosting must be deployed separately, or the live site keeps serving an older build.

## Scripts

Both need Google application credentials and are safe to re-run.

```bash
# Fill in search keywords on jobs created before search shipped
GOOGLE_APPLICATION_CREDENTIALS=/path/outside/repo/key.json \
  node scripts/backfill-search-terms.mjs --dry-run

# Seed fictional demo data for a walkthrough (every document carries demo:true)
GOOGLE_APPLICATION_CREDENTIALS=/path/outside/repo/key.json \
  node scripts/seed-demo-data.mjs
GOOGLE_APPLICATION_CREDENTIALS=... node scripts/seed-demo-data.mjs --wipe
```

The seeded posters, seekers and phone numbers are invented, and marked "(demo)". It is material for demonstrating the product, not evidence of usage.

## Secrets

Never commit service-account keys, `.env` files or admin passwords. Keep the service-account key outside the working tree and point `GOOGLE_APPLICATION_CREDENTIALS` at it. Firebase web and Android API keys are identifiers rather than secrets, but still need App Check and restricted API scopes. See section 2 of [`docs/03-security-and-compliance.md`](docs/03-security-and-compliance.md).

## Documentation

| Doc | Contents |
|---|---|
| [`docs/01-product-requirements.md`](docs/01-product-requirements.md) | Users, scope, prioritised requirements |
| [`docs/02-architecture.md`](docs/02-architecture.md) | Structure, data model, data flow |
| [`docs/03-security-and-compliance.md`](docs/03-security-and-compliance.md) | Risk register, rules matrix, Ghana data protection |
| [`docs/04-roadmap.md`](docs/04-roadmap.md) | Phases, status, what is left |
| [`docs/05-admin-dashboard.md`](docs/05-admin-dashboard.md) | Admin dashboard plan |
| [`docs/06-quality-and-release.md`](docs/06-quality-and-release.md) | Testing strategy, CI/CD, release |
| [`docs/07-decisions-and-open-questions.md`](docs/07-decisions-and-open-questions.md) | Decision log |

## About

Built by Emmanuel Duodu Osae (11012457), BSc Computer Science, University of Ghana.
