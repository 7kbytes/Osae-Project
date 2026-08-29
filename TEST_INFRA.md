# E2E Test Infra: Local Job Connector Mobile App

## Test Philosophy
- Opaque-box, requirement-driven. No dependency on implementation internal design details.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial + Real-World Workload Testing.

## Feature Inventory & Test Mapping
| # | Feature | Requirement | Tier 1 (Unit/Serialization) | Tier 2 (Boundary & State) | Tier 3 (Pairwise/Cross) | Tier 4 (E2E Application) |
|---|---------|-------------|:------:|:------:|:------:|:------:|
| 1 | Hybrid Local Persistence (SharedPreferences) | R1 | 5 | 5 | ✓ | ✓ |
| 2 | Firestore Cloud Sync & Offline Queue | R1 | 5 | 5 | ✓ | ✓ |
| 3 | Job Status Transitions (open->in_progress->completed) | R2 | 5 | 5 | ✓ | ✓ |
| 4 | Job Application Submission Workflow | R2 | 5 | 5 | ✓ | ✓ |
| 5 | Employer Applicant Review (Accept / Reject) | R2 | 5 | 5 | ✓ | ✓ |
| 6 | Global Error Boundaries & Crash Prevention | R3 | 5 | 5 | ✓ | ✓ |
| 7 | Network Offline / Online State Transitions | R3 | 5 | 5 | ✓ | ✓ |
| 8 | Form Sanitization & Ghana Phone Validation | R3 | 5 | 5 | ✓ | ✓ |
| 9 | UI Fallbacks & Empty State Resilience | R3 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Test Runner**: `flutter test`
- **Pass/Fail Semantics**: All tests must execute with exit code 0, 0 test failures, 0 exceptions.
- **Coverage Strategy**:
  - `test/local_storage_test.dart`: SharedPreferences serialization, cold restart restoration, cache integrity.
  - `test/application_provider_test.dart`: JobApplication submission, status transitions, applicant query by employer/seeker.
  - `test/application_flow_widget_test.dart`: UI widget flows for seeker applying, employer reviewing and accepting/rejecting.
  - `test/resiliency_test.dart`: Global error boundaries, network offline indicator toggles, form sanitization, fallback widgets.
  - `test/tier4_scenarios_test.dart`: Multi-step end-to-end user journeys (Offline Job Creation -> Restart -> Apply -> Accept -> Complete).
  - `test/tier5_adversarial_test.dart`: Adversarial race conditions, corrupted storage recovery, extreme inputs.

## Coverage Thresholds
- **Tier 1 (Unit & Serialization)**: ≥ 45 test cases
- **Tier 2 (Boundary & Corner Cases)**: ≥ 45 test cases
- **Tier 3 (Cross-Feature & Pairwise)**: ≥ 15 test cases
- **Tier 4 (Real-World Scenarios)**: ≥ 10 full scenario tests
- **Tier 5 (Adversarial Coverage Hardening)**: Complete gap closure
- **Target**: Maintain 100% test pass rate with 0 `flutter analyze` issues.
