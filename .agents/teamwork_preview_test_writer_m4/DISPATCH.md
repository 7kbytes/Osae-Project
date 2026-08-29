## 2026-08-29T01:34:05Z

You are Test Writer M4 for the Local Job Connector mobile app project.

Your assigned working directory is: c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\teamwork_preview_test_writer_m4
The authoritative original user request is at: c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\ORIGINAL_REQUEST.md
The master project blueprint is at: c:\Users\Administrator\Documents\GitHub\Osae-Project\PROJECT.md
The test infrastructure blueprint is at: c:\Users\Administrator\Documents\GitHub\Osae-Project\TEST_INFRA.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

YOUR ASSIGNED MILESTONE: M4 — Comprehensive E2E Testing Suite (Tiers 1-4)
Specific Tasks:
1. Review all features in `PROJECT.md § Feature Inventory` and `TEST_INFRA.md`.
2. Expand/create test suites in `test/` (e.g. `test/e2e_workflows_test.dart` and/or updates to existing test files) covering:
   - Tier 1: Unit & Serialization tests (SharedPreferences serialization, models, validators, sanitizers)
   - Tier 2: Boundary & Corner tests (empty storage restoration, rapid network toggling, malformed/corrupt JSON gracefully ignored, boundary pay rates, duplicate applications)
   - Tier 3: Cross-Feature Interaction tests (Offline posting -> restart hydration -> application submission -> applicant review & accept -> chat room generation)
   - Tier 4: Real-World Workload Scenarios (End-to-end seeker & employer multi-step user journeys, role switching, status lifecycles from open to completed)
3. Execute `flutter test` and `flutter analyze` to ensure:
   - 100% test pass rate
   - 0 errors, 0 warnings, 0 lints from `flutter analyze`.
4. Publish `c:\Users\Administrator\Documents\GitHub\Osae-Project\TEST_READY.md` following the template in `TEST_INFRA.md`.
5. Write your detailed handoff report to:
`c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\teamwork_preview_test_writer_m4\handoff.md`.
Update `progress.md` with timestamps. When done, send a message to the caller with a concise summary and report paths.
