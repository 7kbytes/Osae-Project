# Project: Local Job Connector Mobile App Production-Readiness

## Architecture
- **State Management & DI**: `Provider` (MultiProvider in `lib/main.dart`)
- **Data Architecture**: Hybrid Local-First & Cloud Firestore
  - **Local Persistence**: `LocalStorageService` wrapping `shared_preferences` for cold-restart persistence of User Profiles, Job Posts, Favorites, Chat Rooms/Messages, and Job Applications.
  - **Cloud Sync**: `FirebaseService` / Firestore Repositories (`FirestoreUserRepository`, `FirestoreJobRepository`, `FirestoreChatRepository`, `FirestoreApplicationRepository`) with seamless offline caching and fallback to in-memory/local storage.
  - **Service & Repository Interfaces**: Abstract repositories (`UserRepository`, `JobRepository`, `ChatRepository`, `ApplicationRepository`) allowing pure in-memory test mocks and production persistence.
- **Workflow & Domain Layer**:
  - `AuthProvider` -> `UserRepository` & `LocalStorageService`
  - `JobProvider` -> `JobRepository` & `LocalStorageService`
  - `ApplicationProvider` -> `ApplicationRepository` & `LocalStorageService`
  - `ChatProvider` -> `ChatRepository` & `LocalStorageService`
  - `ConnectivityProvider` -> Network status stream & connectivity monitoring
- **UI & Presentation Layer**:
  - Global Error Boundary (`GlobalErrorBoundaryWidget`, `ErrorWidget.builder`, `FlutterError.onError`, `PlatformDispatcher.instance.onError`)
  - Network Offline Indicator Banner (`OfflineBannerWidget`)
  - Form validation & sanitization (`FormValidators`, `InputSanitizer`)
  - Resilient UI screens with empty states, safe image/map error builders, and null guards
- **Code Layout**:
  - `lib/core/models/`: Data models (`user_model.dart`, `job_model.dart`, `job_application_model.dart`, `chat_model.dart`, `timestamp_helper.dart`)
  - `lib/core/services/`: `local_storage_service.dart`, `connectivity_service.dart`, `firebase_service.dart`, `location_service.dart`, `mock_data.dart`, `error_handler_service.dart`
  - `lib/core/repositories/`: `user_repository.dart`, `job_repository.dart`, `chat_repository.dart`, `application_repository.dart`
  - `lib/core/providers/`: `auth_provider.dart`, `job_provider.dart`, `application_provider.dart`, `chat_provider.dart`, `connectivity_provider.dart`
  - `lib/core/utils/`: `form_validators.dart`, `input_sanitizer.dart`
  - `lib/core/widgets/`: `global_error_boundary.dart`, `offline_banner.dart`, `safe_image.dart`
  - `lib/features/`: Auth, Jobs, Applications, Chat, Favorites, Map, Navigation
  - `test/`: 17 comprehensive test suites (Tiers 1-5 + Adversarial)

## Feature Inventory
| # | Feature | Description | Milestone | Source | Status |
|---|---------|-------------|-----------|--------|:------:|
| 1 | `shared_preferences` Dependency | Added `shared_preferences: ^2.3.2` to `pubspec.yaml` | M1 | Survey 1, Survey 3 | DONE |
| 2 | `LocalStorageService` | Local caching & retrieval for Profiles, Jobs, Favorites, Chats, and Applications | M1 | Survey 1, R1 | DONE |
| 3 | Hybrid Cache-First Hydration | Repository hydration from local storage on startup, sync to Firestore when online | M1 | Survey 1, R1 | DONE |
| 4 | `JobStatus` Lifecycle Support | Extended `JobPost` with `JobStatus` enum (`open`, `inProgress`, `completed`) & transitions | M2 | Survey 1, R2 | DONE |
| 5 | `ApplicationProvider` | State management for job applications, submission, seeker list, poster applicant review | M2 | Survey 1, R2 | DONE |
| 6 | Job Application Submission UI | Seeker "Apply for Job" modal in `JobDetailScreen` with note, phone & validation | M2 | Survey 1, R2 | DONE |
| 7 | Employer Applicant Review Screen | Employer review screen to inspect candidates and accept/reject applications | M2 | Survey 1, R2 | DONE |
| 8 | Job Seeker Applications Screen | Seeker view to track submitted applications and status transitions | M2 | Survey 1, R2 | DONE |
| 9 | Global Error Boundaries | `FlutterError.onError`, `PlatformDispatcher.onError`, `ErrorWidget.builder`, `GlobalErrorBoundary` | M3 | Survey 2, R3 | DONE |
| 10 | Network Offline Indicator | `ConnectivityService`/`ConnectivityProvider` with animated `OfflineBanner` | M3 | Survey 2, R3 | DONE |
| 11 | Form Sanitization & Validation | Centralized `FormValidators` for email, Ghana phone, numeric pay, sanitized inputs | M3 | Survey 2, R3 | DONE |
| 12 | UI Fallbacks & Null Guards | Safe image loading, map fallbacks, and fix `JobDetailScreen` empty job crash | M3 | Survey 2, R3 | DONE |
| 13 | Comprehensive E2E Test Suite | 4-Tier test suite (Tiers 1-4) covering persistence, workflows, resiliency, edge cases | M4 | Survey 3, R4 | DONE |
| 14 | Adversarial Hardening (Tier 5) | White-box stress tests, extreme edge cases, concurrent state mutations (205 tests) | M5 | R4, Project Pattern | DONE |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|:------:|
| M1 | Hybrid Local-First & Firestore Data Sync | `pubspec.yaml`, `LocalStorageService`, repository cache-first hydration & offline persistence | none | DONE |
| M2 | End-to-End Application & Applicant Workflows | `JobStatus` lifecycle, `ApplicationProvider`, Job Application submission modal, `ApplicantReviewScreen`, `MyApplicationsScreen`, status transitions | M1 | DONE |
| M3 | Production Error Handling & Resiliency | Global error boundaries in `main.dart`, `ConnectivityProvider`, `OfflineBanner`, `FormValidators`, `JobDetailScreen` crash fix, UI fallbacks | M1 | DONE |
| M4 | E2E Testing Suite (Tiers 1-4) | Comprehensive opaque-box test cases for persistence, workflows, offline transitions, form validation | M1, M2, M3 | DONE |
| M5 | Adversarial Hardening & Final Audit | Tier 5 adversarial stress testing, 100% test pass verification (205/205), `flutter analyze` 0 warnings, forensic integrity audit (CLEAN) | M4 | DONE |

## Interface Contracts
### `LocalStorageService`
```dart
abstract class LocalStorageService {
  Future<void> init();
  Future<void> saveUser(AppUser user);
  AppUser? getUser();
  Future<void> clearUser();
  Future<void> saveJobs(List<JobPost> jobs);
  List<JobPost> getJobs();
  Future<void> saveFavorites(Set<String> favoriteIds);
  Set<String> getFavorites();
  Future<void> saveChatRooms(List<ChatRoom> rooms);
  List<ChatRoom> getChatRooms();
  Future<void> saveMessages(String roomId, List<ChatMessage> messages);
  List<ChatMessage> getMessages(String roomId);
  Future<void> saveApplications(List<JobApplication> applications);
  List<JobApplication> getApplications();
  Future<void> clearAll();
}
```

### `ApplicationProvider`
```dart
abstract class ApplicationProvider extends ChangeNotifier {
  List<JobApplication> get applications;
  List<JobApplication> get myApplications; // For seekers
  List<JobApplication> getApplicationsForJob(String jobId); // For employers
  bool hasApplied(String jobId, String seekerId);
  Future<bool> submitApplication({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String applicantId,
    required String applicantName,
    required String applicantPhone,
    required String coverNote,
  });
  Future<bool> updateApplicationStatus(String applicationId, ApplicationStatus status);
  Future<void> loadApplications();
}
```

### `ConnectivityProvider`
```dart
abstract class ConnectivityProvider extends ChangeNotifier {
  bool get isOnline;
  void setOnline(bool value);
}
```

### `FormValidators`
```dart
class FormValidators {
  static String? validateEmail(String? value);
  static String? validateGhanaPhone(String? value);
  static String? validatePayRate(String? value);
  static String? validateRequired(String? value, String fieldName);
  static String sanitizeText(String text);
}
```
