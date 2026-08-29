# Local Job Connector — Codebase Survey & Health Baseline Report

**Author**: Explorer Agent (`explorer_survey_1`)  
**Date**: 2026-08-29  
**Repository**: `c:\Users\Administrator\Documents\GitHub\Osae-Project`  
**Target Platform**: Flutter Mobile (Android / iOS / Web / Desktop)  
**Context**: Academic / Production App for matching informal job seekers with daily-wage employers across Ghana (Accra, Kumasi, Tema) by Emmanuel Duodu Osae (11012457, BSc Computer Science, UG).

---

## 1. Executive Summary

The **Local Job Connector** project is a structured Flutter application designed to empower informal sector workers (market offloaders, cleaners, restaurant waiters, store attendants, laborers) and daily-wage employers across Ghana.

The application has an established UI foundation and Provider-based state management architecture covering all 6 core functional modules:
1. **Job Feed & Filtering** (City & Category filters, Keyword search)
2. **Interactive Map Explorer** (Accra, Kumasi, Tema markers with camera controls & preview cards)
3. **Gig Creation & Posting** (Form with city-based landmark resolution and wage unit options)
4. **Real-time In-App Chat** (Direct messaging between job seekers and employers)
5. **Favorites & Bookmarks** (Persisted active shortlist)
6. **Authentication & User Profile** (Seeker vs Employer role toggle, Google/Email auth simulation, profile metadata)

### Current Baseline Health
| Metric | Status | Details |
|---|---|---|
| **Compilation / Execution** | Functional | Codebase compiles cleanly against Flutter 3.12+ SDK |
| **Static Analysis (`flutter analyze`)** | ⚠️ **14 issues (Code 1)** | 11 `deprecated_member_use` (`withOpacity`), 3 `unnecessary_underscores` (`_, __`) |
| **Automated Tests (`flutter test`)** | ✅ **6 / 6 passing (Code 0)** | 5 unit tests in `job_provider_test.dart`, 1 smoke widget test in `widget_test.dart` |
| **Backend Integration** | Hybrid / Mocked | Firebase packages declared in `pubspec.yaml`, UI currently backed by in-memory reactive state |

---

## 2. Project Structure & Dependency Audit

### 2.1 File Tree Breakdown
```
Osae-Project/
├── pubspec.yaml                     # Dependencies & SDK constraints
├── analysis_options.yaml            # flutter_lints configuration
├── android/                         # Android platform host & Manifests
│   └── app/src/main/AndroidManifest.xml
├── ios/                             # iOS runner configuration
├── lib/
│   ├── main.dart                    # App entrypoint, MultiProvider & MaterialApp
│   ├── app/
│   │   └── theme.dart               # Ghanaian color palette & Material3 ThemeData
│   ├── core/
│   │   ├── models/
│   │   │   ├── user_model.dart      # AppUser model & UserRole enum
│   │   │   ├── job_model.dart       # JobPost data model with GHS pricing & GPS coords
│   │   │   └── chat_model.dart      # ChatMessage & ChatRoom models
│   │   ├── providers/
│   │   │   ├── auth_provider.dart   # Authentication state & role context
│   │   │   ├── job_provider.dart    # Job feed, filters, search, favorites, role switch
│   │   │   └── chat_provider.dart   # Chat rooms and real-time message exchange
│   │   └── services/
│   │       └── mock_data.dart       # Realistic seed data for Accra, Kumasi, Tema
│   └── features/
│       ├── navigation/
│       │   └── main_navigation_screen.dart # 6-tab BottomNavigationBar & IndexedStack
│       ├── auth/screens/
│       │   ├── login_screen.dart    # Email/Password + Google Sign-In & Register
│       │   └── profile_screen.dart  # Profile details, role toggle, UG student credits
│       ├── jobs/
│       │   ├── screens/
│       │   │   ├── job_feed_screen.dart   # Feed with search & city/category chips
│       │   │   ├── job_detail_screen.dart # Detailed gig specs & chat launcher
│       │   │   └── create_job_screen.dart # Job posting form with validation
│       │   └── widgets/
│       │       └── job_card.dart          # Reusable feed & favorites card
│       ├── chat/screens/
│       │   ├── chat_list_screen.dart      # Active conversations list
│       │   └── chat_room_screen.dart      # Direct messaging room thread
│       ├── favorites/screens/
│       │   └── favorites_screen.dart      # Bookmarked jobs list
│       └── map/screens/
│           └── map_view_screen.dart       # Google Maps with city jump & preview cards
└── test/
    ├── job_provider_test.dart       # 5 Unit tests for JobProvider
    └── widget_test.dart             # 1 Widget smoke test
```

### 2.2 Dependencies (`pubspec.yaml`)
- **Dart SDK**: `^3.12.2`
- **Flutter Framework**: `sdk: flutter`
- **State Management**: `provider: ^6.1.5+1`
- **Location & Maps**:
  - `google_maps_flutter: ^2.18.0`
  - `geolocator: ^14.0.3`
- **Internationalization & Formatting**: `intl: ^0.20.3`
- **Firebase Ecosystem**:
  - `firebase_core: ^4.14.0`
  - `firebase_auth: ^6.6.1`
  - `cloud_firestore: ^6.9.0`
  - `google_sign_in: ^7.2.0`
- **Icons & UI**: `cupertino_icons: ^1.0.8`
- **Dev Dependencies**: `flutter_test: sdk: flutter`, `flutter_lints: ^6.0.0`

### 2.3 Platform Configurations
- **Android Manifest**: Located at `android/app/src/main/AndroidManifest.xml`. Contains location permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`) and Google Maps API metadata placeholder.

---

## 3. Architecture & State Management

### 3.1 Provider Setup
The application uses `MultiProvider` in `lib/main.dart`:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => JobProvider()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),
  ],
  child: ...
)
```

### 3.2 State Flow & Responsibilities
1. **`AuthProvider`**:
   - Manages `_isAuthenticated`, `_currentUser` (`AppUser`), `_authMethod`.
   - Supports `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, and `signOut`.
   - Default authenticated demo state facilitates instant app access during development/testing.
2. **`JobProvider`**:
   - Manages active job list (`_jobs`), favorite IDs set (`_favoriteJobIds`), active city filter (`_selectedCity`), category filter (`_selectedCategory`), search query (`_searchQuery`), and `currentUserRole` (`UserRole.seeker` vs `UserRole.poster`).
   - Implements computed property `filteredJobs` which applies multi-attribute filtering (city, category, title/description/location search).
   - Implements actions: `setRole`, `setCityFilter`, `setCategoryFilter`, `setSearchQuery`, `toggleFavorite`, `addJob`.
3. **`ChatProvider`**:
   - Manages chat rooms list (`_rooms`) and messages map per room (`_messagesPerRoom`).
   - Implements `getOrCreateRoom`, `sendMessage`, and `getMessages`.
   - Dynamically creates room if not existing and handles message dispatch with timestamps.

---

## 4. Detailed Feature-by-Feature Status

| Feature / Screen | File Path | Implementation Status | Observations & Notes |
|---|---|---|---|
| **Theme & Ghanaian Styling** | `lib/app/theme.dart` | ✅ Complete | Uses Ghanaian Green `#006B3F`, Gold `#FCD116`, Red `#CE1126`. Modern Material 3 cards, buttons, chips. |
| **Root Navigation** | `lib/features/navigation/main_navigation_screen.dart` | ✅ Complete | 6 tabs: Jobs, Map, Post Gig, Chats, Saved, Profile. Uses `IndexedStack` to preserve screen state across tab switches. |
| **Authentication Screen** | `lib/features/auth/screens/login_screen.dart` | ✅ Complete | Sign in / Sign up mode toggle, role selector, city dropdown, email/password validation, Google sign in button. |
| **User Profile & Settings** | `lib/features/auth/screens/profile_screen.dart` | ✅ Complete | Shows user details, email, phone, city badge, role switcher choice chips (`Job Seeker` / `Employer`), academic project credits for Emmanuel Duodu Osae (UG), and Sign out button. |
| **Job Feed & Filters** | `lib/features/jobs/screens/job_feed_screen.dart` | ⚠️ Polish Needed | Search bar with clear button, horizontal city filter chips (All, Accra, Kumasi, Tema), horizontal category filter chips, dynamic job listing. *Has 4 deprecation/underscore warnings.* |
| **Job Card Component** | `lib/features/jobs/widgets/job_card.dart` | ⚠️ Polish Needed | Displays category, time elapsed (`_formatTimeAgo`), favorite toggle, title, location, wage in GHS, view details button. *Has 1 deprecation warning.* |
| **Job Details Screen** | `lib/features/jobs/screens/job_detail_screen.dart` | ⚠️ Polish Needed | Category chip, Active badge, title, location, payment details, full description, employer card, and context-sensitive action button (Chat launcher for Seekers, role switch notice for Employers). *Has 3 deprecation warnings.* |
| **Gig Creation Form** | `lib/features/jobs/screens/create_job_screen.dart` | ✅ Complete | Full validation for title, category, city (auto-fills default coords & landmarks for Accra/Kumasi/Tema), wage amount, pay unit, landmark location, contact phone, description. Inserts into JobProvider. |
| **Interactive Map Explorer** | `lib/features/map/screens/map_view_screen.dart` | ⚠️ Polish Needed | GoogleMap widget displaying job markers across Ghana, quick-jump city selector chips (animating camera to Accra, Kumasi, or Tema), bottom floating preview card for selected marker. *Has 2 deprecation warnings.* |
| **Chat Conversations List** | `lib/features/chat/screens/chat_list_screen.dart` | ⚠️ Polish Needed | Lists active chat threads with employer name, job title subject, last message snippet, formatted timestamp. *Has 2 deprecation/underscore warnings.* |
| **Direct Chat Room** | `lib/features/chat/screens/chat_room_screen.dart` | ⚠️ Polish Needed | Bubble thread distinguishing sender vs recipient messages, timestamps, text field with send button. *Has 2 deprecation warnings.* |
| **Favorites / Saved Jobs** | `lib/features/favorites/screens/favorites_screen.dart` | ✅ Complete | Renders bookmarked jobs using JobCard or displays an empty state banner with instructions. |

---

## 5. Static Analysis & Test Baseline Audit

### 5.1 Static Analysis Issues (`flutter analyze`)
Running `flutter analyze` produces **14 lint issues** (all classified as `info`, causing exit code 1):

1. **Deprecated Member (`deprecated_member_use`)**:
   - Dart / Flutter SDK deprecation: `Color.withOpacity(alpha)` is deprecated in favor of `Color.withValues(alpha: ...)`.
   - Affected locations:
     - `lib\features\chat\screens\chat_list_screen.dart:54`
     - `lib\features\chat\screens\chat_room_screen.dart:103`
     - `lib\features\chat\screens\chat_room_screen.dart:127`
     - `lib\features\jobs\screens\job_detail_screen.dart:54`
     - `lib\features\jobs\screens\job_detail_screen.dart:68`
     - `lib\features\jobs\screens\job_detail_screen.dart:202`
     - `lib\features\jobs\screens\job_feed_screen.dart:98`
     - `lib\features\jobs\screens\job_feed_screen.dart:133`
     - `lib\features\jobs\widgets\job_card.dart:54`
     - `lib\features\map\screens\map_view_screen.dart:89`
     - `lib\features\map\screens\map_view_screen.dart:131`
2. **Unnecessary Underscores (`unnecessary_underscores`)**:
   - Using `(_, __)` instead of `(_, _)` in `ListView.separated`:
     - `lib\features\chat\screens\chat_list_screen.dart:46`
     - `lib\features\jobs\screens\job_feed_screen.dart:89`
     - `lib\features\jobs\screens\job_feed_screen.dart:125`

### 5.2 Automated Tests Status (`flutter test`)
- Currently 2 test suites exist:
  - `test/job_provider_test.dart` (5 tests):
    1. Initial jobs loaded correctly
    2. Filter jobs by city
    3. Toggle favorite job
    4. Add new job post
    5. Switch user role
  - `test/widget_test.dart` (1 test):
    1. LocalJobConnector app loads and renders main title
- All 6 tests pass successfully in ~1.5 seconds.

### 5.3 Test Coverage Gaps
1. **AuthProvider Unit Tests**: No test file for `AuthProvider` (authentication state transitions, sign in, sign up, sign out, role retention).
2. **ChatProvider Unit Tests**: No test file for `ChatProvider` (room retrieval/creation, message dispatching, room ordering).
3. **Data Model Serialization Tests**: No unit tests validating `AppUser.fromMap`/`toMap`, `JobPost.fromMap`/`toMap`, `ChatMessage.fromMap`/`toMap`, `ChatRoom.fromMap`/`toMap`.
4. **Widget / Flow Tests**:
   - `JobFeedScreen`: Test searching keywords, selecting city chips, selecting category chips, tapping a job card.
   - `JobDetailScreen`: Test toggling favorite from app bar, launching chat as Seeker vs seeing warning as Employer.
   - `CreateJobScreen`: Test form field validation, city coordinate auto-population, and job submission.
   - `ChatRoomScreen`: Test message sending and bubble display.
   - `ProfileScreen`: Test role switching between Seeker and Employer.
   - `FavoritesScreen`: Test display of favorited jobs and empty state.
   - `MapViewScreen`: Test map widget rendering and city chip selection.

---

## 6. Recommendations & Roadmap for Success

1. **Phase 1: Static Analysis Cleanliness (0 Warnings / 0 Errors)**
   - Replace all occurrences of `.withOpacity(...)` with `.withValues(alpha: ...)` across the 6 affected files.
   - Fix `(_, __)` separator builders to `(_, _)` or `(context, index)`.
   - Verify `flutter analyze` exits with code 0.

2. **Phase 2: Comprehensive Test Suite Implementation**
   - Implement `test/auth_provider_test.dart` covering all auth actions.
   - Implement `test/chat_provider_test.dart` covering room creation, message sending, and ordering.
   - Implement `test/models_test.dart` covering JSON/Map serialization for `AppUser`, `JobPost`, `ChatMessage`, and `ChatRoom`.
   - Implement comprehensive widget tests for `JobFeedScreen`, `JobDetailScreen`, `CreateJobScreen`, `ChatRoomScreen`, `ProfileScreen`, `FavoritesScreen`, and `MapViewScreen`.
   - Verify all tests pass cleanly via `flutter test`.

3. **Phase 3: Verification & Polish**
   - Run end-to-end static analysis and full test suite.
   - Verify seamless transitions across roles, map interaction, and messaging.

---
*Report generated by Explorer Agent.*
