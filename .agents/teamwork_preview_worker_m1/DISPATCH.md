## 2026-08-29T01:16:04Z

You are Worker M1 for the Local Job Connector mobile app project.

Your assigned working directory is: c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\teamwork_preview_worker_m1
The authoritative original user request is at: c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\ORIGINAL_REQUEST.md
The master project blueprint is at: c:\Users\Administrator\Documents\GitHub\Osae-Project\PROJECT.md
The data architecture survey report is at: c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\teamwork_preview_explorer_survey_1\analysis.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

YOUR ASSIGNED MILESTONE: M1 — Hybrid Local-First & Firestore Data Sync
Specific Tasks:
1. Update `pubspec.yaml` to include `shared_preferences: ^2.3.2` and run `flutter pub get`.
2. Implement `lib/core/services/local_storage_service.dart`:
   - Concrete `LocalStorageService` wrapping `SharedPreferences`
   - Methods: `init()`, `saveUser(AppUser user)`, `getUser()`, `clearUser()`, `saveJobs(List<JobPost> jobs)`, `getJobs()`, `saveFavorites(Set<String> ids)`, `getFavorites()`, `saveChatRooms(List<ChatRoom> rooms)`, `getChatRooms()`, `saveMessages(String roomId, List<ChatMessage> messages)`, `getMessages(String roomId)`, `saveApplications(List<JobApplication> apps)`, `getApplications()`, `clearAll()`.
   - Ensure clean, robust JSON serialization/deserialization with null-safety and error resilience.
3. Update `lib/main.dart` and the providers/repositories (`AuthProvider`, `JobProvider`, `ChatProvider`, etc.) to support local storage hydration on launch and local persistence on mutations.
4. Implement `test/local_storage_test.dart` to verify cold-restart persistence, serialization/deserialization fidelity, and cache consistency using `SharedPreferences.setMockInitialValues({})`.
5. Run `flutter analyze` and `flutter test` to verify 0 errors/warnings and 100% test pass rate across all test files.

Write your detailed implementation report and test results to:
`c:\Users\Administrator\Documents\GitHub\Osae-Project\.agents\teamwork_preview_worker_m1\handoff.md`.
Update `progress.md` with timestamps. When done, send a message to the caller with a concise summary and report paths.
