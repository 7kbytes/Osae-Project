# End-to-end tests

Playwright scripts that drive the **deployed** app in a real browser and check Firestore through the Admin SDK.

## Run

```
cd e2e
npm install
npx playwright install chromium
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account.json   (PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS = "...")
npm test
```

Optional: `BASE_URL=https://staging.example.web.app` to target another environment.

## What runs

| Script | Covers |
|---|---|
| `auth.js` | login screen, wrong password rejected, sign-up, session restore, sign-out, re-login |
| `marketplace-flow.js` | poster posts a job, seeker sees it, applies, starts a chat |
| `poster-flow.js` | poster chat list and reply, applicant review, accept |
| `account.js` | forgot password, self-service account deletion |
| `admin.js` | admin dashboard sign-in, lists, status change, delete, non-admin rejected (uses a temporary admin) |

Every run creates accounts named `e2e.*@example.com` and deletes them afterwards (`npm run cleanup` removes strays).

## Safety

- Use a **non-production** Firebase project once staging exists (docs/02-architecture.md). Until then these run against production with clearly named test data.
- The service-account key must live outside the repo. Never commit it.
- Screens are canvas-rendered, so a few steps click by coordinates; a layout change may need the script adjusted.
