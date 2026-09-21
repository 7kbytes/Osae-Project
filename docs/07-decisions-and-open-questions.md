# 07. Decisions and Open Questions

## Open questions

**Resolved 2026-09-20 with the defaults below (decision D6).** Revisit any of them if the owner changes their mind; Q7 to Q9 in particular still need real numbers before launch.

| # | Question | Why it matters | Default if unanswered |
|---|---|---|---|
| Q1 | Who is the launch audience and city (Accra only, or Accra, Kumasi and Tema)? | Scope of seed data and support | Accra, Kumasi, Tema |
| Q2 | Phone OTP as the primary sign-in, or email/password? | Auth design, SMS cost | Email plus phone verification |
| Q3 | Can one account be both seeker and poster? | Data model and UI | Yes, switchable |
| Q4 | Should posters' phone numbers be public? | Privacy (R5), spam | Hidden until an application is accepted |
| Q5 | Are payments in scope for v1? | Compliance, regulation | Out of scope |
| Q6 | Who moderates, and what is the response-time promise? | Staffing; admin roles | Owner plus one moderator |
| Q7 | Who is the team (developers, QA, design) and target launch date? | Roadmap dates | One or two developers; no fixed date |
| Q8 | Budget ceiling per month for Firebase, Maps and SMS? | Architecture and quotas | Set a GCP budget alert first |
| Q9 | Legal counsel for terms, privacy and Act 843 registration? | Launch gate | Required before public launch |
| Q10 | Which languages beyond English (Twi, Ga, Ewe)? | Localisation effort | English only at v1 |
| Q11 | Should the project be open source or private? | Secrets hygiene, licensing | Private |

## Decision log

Format: date, decision, reason, alternatives.

| ID | Date | Decision | Reason | Alternatives |
|---|---|---|---|---|
| D1 | 2026-09-20 | Keep Flutter plus Firebase | Already built; managed backend; low ops burden | Custom API (more control, more work) |
| D2 | 2026-09-20 | Keep the repository pattern and provider state management | Working and testable; a rewrite is not justified | Riverpod or Bloc migration (revisit later) |
| D3 | 2026-09-20 | Admin dashboard as a static page under `web/admin` for v0 | Fast to ship; no build tooling | Separate React app (adopt when it outgrows one file) |
| D4 | 2026-09-20 | Move admin authorisation from the `admins` doc to custom claims in v2 | Standard, enforceable in rules and Functions | Keep the doc lookup |
| D6 | 2026-09-20 | Open questions Q1 to Q11 resolved with the listed defaults (owner said: use default) | Unblocks Phase 0 | Wait for detailed answers |
| D5 | 2026-09-20 | Separate dev, staging and prod Firebase projects | Safe testing; no test data in production | Single project with prefixes |

## How to use this file

Add questions as they arise. When one is answered, move it to the decision log with a date and reason, and update the affected doc.
