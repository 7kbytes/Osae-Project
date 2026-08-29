# Specification Inventory: Local Job Connector Mobile Application

**Target Domain**: Informal Job Seekers & Daily-Wage Employers in Ghana (Accra, Kumasi, Tema)  
**Author**: Spec Miner  
**Date**: 2026-08-29  
**Repository**: `c:\Users\Administrator\Documents\GitHub\Osae-Project`  

---

## 1. Executive Summary & Architecture Overview

The **Local Job Connector** is a production-grade Flutter cross-platform mobile application engineered to connect informal artisans, laborers, and daily-wage job seekers with local business owners, contractors, and household employers in urban Ghana. The application architecture follows Flutter layered design principles utilizing **Provider** state management, clean data models, modular feature modules, and real-time interactive mapping and chat capabilities.

### Architectural Layers
```
lib/
├── app/
│   └── theme.dart                     # Ghanaian-inspired theme palette (Green #006B3F, Gold #FCD116, Red #CE1126)
├── core/
│   ├── models/
│   │   ├── user_model.dart            # AppUser, UserRole (seeker, poster, admin)
│   │   ├── job_model.dart             # JobPost (GHS rates, geo-coordinates, categories)
│   │   └── chat_model.dart            # ChatMessage, ChatRoom
│   ├── providers/
│   │   ├── auth_provider.dart         # Authentication state, login, signup, Google OAuth
│   │   ├── job_provider.dart          # Job feed, search, city/category filters, favorites, posting
│   │   └── chat_provider.dart         # Direct messaging, room indexing, message history
│   └── services/
│       └── mock_data.dart             # Seed datasets for Accra, Kumasi, and Tema informal markets
└── features/
    ├── auth/                          # LoginScreen, ProfileScreen
    ├── jobs/                          # JobFeedScreen, JobDetailScreen, CreateJobScreen, JobCard
    ├── map/                           # MapViewScreen (Google Maps + Marker Explorer)
    ├── chat/                          # ChatListScreen, ChatRoomScreen
    ├── favorites/                     # FavoritesScreen
    └── navigation/                    # MainNavigationScreen (6-tab IndexedStack)
```

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Authentication | Email & Password Sign-In | Authenticate existing users using email and minimum 6-character password | Email string, password string | Authenticated `AppUser` session, route to `MainNavigationScreen` | Form validation: 'Enter valid email', 'Password must be at least 6 chars' | `lib/features/auth/screens/login_screen.dart`, `lib/core/providers/auth_provider.dart` |
| 2 | Authentication | User Registration / Sign-Up | Create new user profile with Name, Phone (+233), Role, City, Email, Password | Full name, phone (+233), role (`seeker`/`poster`), city (`Accra`/`Kumasi`/`Tema`), email, password | New `AppUser` account created, authenticated session initialized | Validation error messages for empty name, phone, email, or short password | `lib/features/auth/screens/login_screen.dart` |
| 3 | Authentication | Google Sign-In OAuth | One-tap OAuth sign-in flow for rapid worker/employer authentication | Google OAuth trigger button tap | Authenticated session with Google profile metadata | Gracefully resets loading state without crash if cancelled | `lib/features/auth/screens/login_screen.dart`, `lib/core/providers/auth_provider.dart` |
| 4 | Authentication / Settings | User Profile Management | Displays active account details, phone, email, auth provider type, and academic attribution | View profile tab | Account details card, verification badges, contact info | Null-safe fallbacks for missing avatar or user names | `lib/features/auth/screens/profile_screen.dart` |
| 5 | Authentication / RBAC | Role Switching (Seeker <-> Employer) | Dynamic in-app toggle enabling users to transition between searching for work and posting gigs | Role choice chips (`Job Seeker` vs `Employer / Poster`) | Updates `JobProvider.currentUserRole`, alters UI action permissions | Immediate UI refresh; non-blocking | `lib/features/auth/screens/profile_screen.dart`, `lib/core/providers/job_provider.dart` |
| 6 | Authentication | User Sign-Out | Ends active session and resets auth state | Sign out button tap | Clears `currentUser`, resets `isAuthenticated = false`, routes to `LoginScreen` | Safe state clearance, no memory leak | `lib/features/auth/screens/profile_screen.dart`, `lib/core/providers/auth_provider.dart` |
| 7 | Navigation | Multi-Tab Root Shell | 6-tab persistent bottom navigation bar (Jobs, Map, Post Gig, Chats, Saved, Profile) | Tab selection (index 0-5) | Renders selected screen via `IndexedStack`, preserving scroll & state | Index clamped [0..5] | `lib/features/navigation/main_navigation_screen.dart` |
| 8 | Job Discovery | Job Feed with Search | Real-time full-text search across job titles, descriptions, and location landmarks | Search query text input | Filtered list of matching `JobPost` items in feed | Shows clear button when text entered; empty search results view on 0 matches | `lib/features/jobs/screens/job_feed_screen.dart`, `lib/core/providers/job_provider.dart` |
| 9 | Job Discovery | City Filter Chips | Fast horizontal filter chips for Ghana urban hubs (All, Accra, Kumasi, Tema) | Chip tap | Filters feed items matching `job.city == selectedCity` | Non-destructive; selecting 'All' restores full feed | `lib/features/jobs/screens/job_feed_screen.dart` |
| 10 | Job Discovery | Category Selector | Horizontal scrollable category chips for informal trades (Construction & Labor, Hospitality, Cleaning, Retail, Transport, Other) | Category chip tap | Filters feed items matching `job.category == selectedCategory` | Empty state shown if selected category has no jobs | `lib/features/jobs/screens/job_feed_screen.dart` |
| 11 | Job Discovery | Job Card Display | Compact card presenting category chip, relative post time (e.g. `15m ago`), title, location landmark, wage/unit, and details button | `JobPost` data model | Structured visual card with ripple ink response | Truncates text overflow with ellipsis; prevents layout breakage | `lib/features/jobs/widgets/job_card.dart` |
| 12 | Job Discovery | Job Details View | Detailed screen showing full job description, location landmark, daily rate, status, and employer contact card | `jobId` parameter | Complete job listing breakdown with role-specific CTAs | Fallback to first available job if `jobId` not matched | `lib/features/jobs/screens/job_detail_screen.dart` |
| 13 | Job Posting | Post Gig / Job Creation | Form allowing employers to publish new daily-wage gigs with title, category, city, landmark, pay rate, pay unit, phone, and description | Form inputs: Title, category, city, pay (GHS), pay unit ('per day'/'per hour'/'fixed'), landmark, phone, description | Inserts new `JobPost` at index 0 of job list, shows confirmation SnackBar, resets form fields | Form validation triggers error alerts under empty or invalid fields | `lib/features/jobs/screens/create_job_screen.dart` |
| 14 | Mapping | Interactive Map View Explorer | Google Maps integration displaying geo-located markers for available informal jobs across Ghana | Map pan/zoom gestures, city switcher pills | Rendered map with markers at exact GPS coordinates | Default center coordinates (Accra: 5.5586, -0.2014) if location missing | `lib/features/map/screens/map_view_screen.dart` |
| 15 | Mapping | Map Marker Selection & Preview Card | Tapping a job pin shows bottom sheet summary card with title, landmark, rate, and 'View Job' button | Marker tap event | Bottom preview card overlay with dismiss button and navigate CTA | Dismissible without losing map state | `lib/features/map/screens/map_view_screen.dart` |
| 16 | Mapping | City Camera Teleportation | City switcher pills on top of map smoothly animate camera to target city centers | City pill tap ('Accra', 'Kumasi', 'Tema') | Smooth camera pan & zoom to city coordinates | Clamped zoom level (13.5) preventing disorientation | `lib/features/map/screens/map_view_screen.dart` |
| 17 | Real-Time Chat | Direct Chat Initiation | Job seekers can initiate direct communication with employers from any job detail page | Tap 'Start Chat with Employer' | Finds existing `ChatRoom` or creates new one, opens `ChatRoomScreen` with default welcome inquiry | Prevented for Employer role with informative notice banner | `lib/features/jobs/screens/job_detail_screen.dart`, `lib/core/providers/chat_provider.dart` |
| 18 | Real-Time Chat | Chat Conversations List | Inbox displaying active chat rooms with employer name, job title subject, last message snippet, and relative timestamp | View chats tab | List of active conversations sorted by most recent message | Empty state with guidance message when no chats exist | `lib/features/chat/screens/chat_list_screen.dart` |
| 19 | Real-Time Chat | Chat Room Messaging Stream | Real-time chat dialogue screen with distinct message bubbles (Green for user, White for recipient) and formatted timestamps | Message text input, send icon or keyboard submit | Appends new `ChatMessage`, updates `ChatRoom.lastMessage` & `updatedAt` | Ignores empty/whitespace-only messages silently | `lib/features/chat/screens/chat_room_screen.dart` |
| 20 | Bookmarks / Favorites | Toggle Saved Jobs | Ability to bookmark any job post from feed card or job detail app bar | Tap heart icon (`Icons.favorite` / `Icons.favorite_border`) | Adds/removes jobId from `_favoriteJobIds` set, immediate color state update | Synchronized globally across feed, details, and favorites tab | `lib/features/jobs/widgets/job_card.dart`, `lib/core/providers/job_provider.dart` |
| 21 | Bookmarks / Favorites | Saved Jobs Feed | Dedicated screen listing all favorited/bookmarked job posts | View saved tab | List of favorited `JobPost` items | Displays empty state illustration when 0 favorites saved | `lib/features/favorites/screens/favorites_screen.dart` |

---

## 3. Edge Cases & Failure Modes

| # | Feature | Input / Scenario | Observed / Required Behavior |
|---|---------|------------------|------------------------------|
| 1 | Job Feed | User enters search query with no matching jobs (e.g. "astronaut") | Feed displays dedicated zero-state illustration (`Icons.search_off`), "No jobs found matching your criteria", and advice to adjust keywords. |
| 2 | Job Feed | User rapidly toggles city chips and category filters to an empty combination | Feed cleanly switches to zero-state without throwing any null exceptions or RenderFlex errors. |
| 3 | Job Posting | Employer submits form with missing required fields (e.g. empty title or pay rate) | Form validation prevents submission, highlights invalid fields in red with specific validation messages (`Please enter a title`, `Enter pay`, etc.). |
| 4 | Job Posting | Employer selects city in dropdown | City selection automatically updates default GPS coordinates (`latitude`, `longitude`) and populates representative landmark in location input (e.g. Circle Market for Accra, Kejetia for Kumasi, Community 1 for Tema). |
| 5 | Job Posting | Employer enters non-integer/decimal pay rate | Parsed with `double.tryParse()`; falls back safely to default rate without throwing format exception. |
| 6 | Map View | User runs app on device without GPS hardware or denies location permission | Map defaults safely to Accra city center (5.5586, -0.2014) with `myLocationEnabled: false` and `zoomControlsEnabled: false`. |
| 7 | Map View | User taps on a job marker pin, then taps outside or clicks close 'X' button | Marker info card appears at screen bottom; clicking 'X' cleans up `_selectedJob = null` without disturbing the map camera. |
| 8 | Job Details & RBAC | User in `Employer` role opens a job listing | Seeker "Start Chat with Employer" CTA button is replaced by an amber informational banner: "You are viewing this listing in Employer mode. Switch role in Profile to apply." |
| 9 | Real-Time Chat | Seeker taps "Start Chat with Employer" for the same job multiple times | `ChatProvider.getOrCreateRoom()` detects existing room matching `jobId` + `seekerId` and routes directly to it instead of creating duplicate rooms. |
| 10 | Real-Time Chat | User submits empty string or spaces in chat room input | `ChatProvider.sendMessage` checks `text.trim().isEmpty` and returns immediately without inserting blank message bubbles. |
| 11 | Real-Time Chat | No active conversations in inbox | `ChatListScreen` displays clean empty state with icon `Icons.chat_bubble_outline` and guidance text. |
| 12 | Favorites | User un-favorites a job from inside `FavoritesScreen` | Job is instantly removed from `favoriteJobs` getter; if list becomes empty, screen switches seamlessly to empty bookmarks view. |
| 13 | Authentication | User enters invalid email format or password less than 6 characters | Form validates inputs client-side, showing inline error text before attempting network auth request. |
| 14 | Responsive Layout | Extreme text lengths in job title, description, or employer name | Cards and list tiles utilize `TextOverflow.ellipsis`, `maxLines`, and `Flexible`/`Expanded` to prevent viewport overflow (`RenderFlex overflowed`). |
| 15 | Linter Deprecation | Dart SDK 3.12 / Flutter 3.x modern color alpha specifications | Legacy `.withOpacity(alpha)` calls produce deprecation warnings; must use `.withValues(alpha: ...)` to satisfy 0-warning linter requirement. |

---

## 4. Ghana Domain-Specific Requirements

The application is tailored specifically for the informal labor market and daily-wage ecosystem in Ghana:

### 4.1 Target Geographic Hubs
1. **Accra (Greater Accra Region)**:
   - Key Commercial Hubs & Landmarks: Kwame Nkrumah Circle VIP Bus Station, Kaneshie Market Complex, Makola Market, Agbogbloshie, Madina Market.
   - Coordinates: `5.5586° N, -0.2014° W`.
2. **Kumasi (Ashanti Region)**:
   - Key Commercial Hubs & Landmarks: Kejetia New Market Complex, Adum Commercial District, Bantama, Asafo Interchange.
   - Coordinates: `6.6961° N, -1.6234° W`.
3. **Tema (Greater Accra Metropolitan Area)**:
   - Key Commercial Hubs & Landmarks: Tema Community 1 Main Market, Tema Port & Harbour Logistics Zone, Community 25.
   - Coordinates: `5.6424° N, 0.0050° E`.

### 4.2 Economic & Informal Labor Nuances
- **Currency**: Ghanaian Cedi (`GHS` / `GH₵`). All pay rates formatted in GHS (e.g. `GHS 150 / per day`).
- **Pay Cadence**: Predominantly daily wage (`per day`), hourly (`per hour`), or task-based completion (`fixed`). Daily cash/mobile money settlement upon day's labor completion is customary.
- **Informal Labor Categories**:
  - *Construction & Labor*: Masonry, carpentry, offloading containers, heavy porterage (Kayayei / carrier), steel bending, painting.
  - *Hospitality & Food*: Chop bar servers, grill/kebab assistants, kitchen preppers, wash attendants.
  - *Cleaning & Janitorial*: Market stall sweeping, domestic house cleaning, office/shop deep cleaning.
  - *Retail & Trade*: Market attendant, shop goods packager, stock sorting.
  - *Transport & Dispatch*: Goods offloaders, courier handlers.
- **Phone Number Format**: Ghana standard (+233 2X XXX XXXX / +233 5X XXX XXXX / +233 20 XXX XXXX). Mobile phone contact is vital for immediate direct coordination.

---

## 5. Precise Acceptance Criteria & Verification Metrics

### 5.1 Static Analysis & Quality Gate
- **`flutter analyze`**:
  - **Target**: 0 errors, 0 warnings, 0 linter issues.
  - **Current Baseline**: 14 deprecation/underscore info issues identified (`withOpacity` -> `withValues`, `__` -> `_`).
  - **Resolution Criteria**: All 14 issues resolved across `lib/features/` screens and widgets.

### 5.2 Automated Test Coverage
- **`flutter test`**:
  - **Target**: 100% pass rate across all unit and widget tests.
  - **Coverage Scope**:
    - `JobProvider`: Initial data loading, city filtering, category filtering, search querying, favorites toggling, job creation, role switching.
    - `AuthProvider`: Initial auth state, email sign-in/up, Google sign-in simulation, sign-out.
    - `ChatProvider`: Room retrieval/creation, message appending, room list ordering, unread handling.
    - Widget Tests: Main app loading, login screen submission, navigation tab switching, job feed card rendering, detail view inspection, profile role toggling.

### 5.3 User Experience & Role Transition Verification
- Clean, non-destructive role transitions between **Job Seeker** and **Employer** in `ProfileScreen`.
- Real-time reactivity in `JobDetailScreen` (Seeker sees chat CTA; Employer sees informative role reminder).
- Google Maps interactive exploration functioning with city teleportation pills and marker popups.
- Real-time chat dialogue message sending and timestamp ordering.

---

## 6. Interface Contracts & Data Schemas

### 6.1 `AppUser`
```dart
enum UserRole { seeker, poster, admin }

class AppUser {
  final String id;
  final String displayName;
  final String phone;
  final UserRole role;
  final String city; // Accra, Kumasi, Tema
  final double rating;
  final String? avatarUrl;
  final DateTime createdAt;
  ...
}
```

### 6.2 `JobPost`
```dart
class JobPost {
  final String id;
  final String title;
  final String description;
  final String category;
  final double payRate;
  final String payUnit; // 'per day', 'per hour', 'fixed'
  final String currency; // 'GHS'
  final String city; // 'Accra', 'Kumasi', 'Tema'
  final String locationName;
  final double latitude;
  final double longitude;
  final String posterId;
  final String posterName;
  final String posterPhone;
  final bool isFilled;
  final bool isFavorite;
  final DateTime createdAt;
  ...
}
```

### 6.3 `ChatMessage` & `ChatRoom`
```dart
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  ...
}

class ChatRoom {
  final String id;
  final String jobId;
  final String jobTitle;
  final String seekerId;
  final String seekerName;
  final String posterId;
  final String posterName;
  final String lastMessage;
  final DateTime updatedAt;
  ...
}
```

---

## 7. Actionable Findings for Feature Engineers

1. **Fix Color Deprecations**: Replace all `.withOpacity(...)` calls in `chat_list_screen.dart`, `chat_room_screen.dart`, `job_detail_screen.dart`, `job_feed_screen.dart`, `job_card.dart`, and `map_view_screen.dart` with `.withValues(alpha: ...)`.
2. **Fix Underscore Lints**: Replace unused secondary closure parameters `(_, __)` with `(_, _)` or `(context, index)`.
3. **Comprehensive Unit & Widget Tests**: Expand test suite in `test/` to verify `AuthProvider`, `ChatProvider`, `JobFeedScreen`, `JobDetailScreen`, `CreateJobScreen`, `MapViewScreen`, `ChatRoomScreen`, and `ProfileScreen`.
4. **Offline Persistence & Error Handling**: Ensure state management gracefully falls back to local data and handles offline conditions cleanly.
