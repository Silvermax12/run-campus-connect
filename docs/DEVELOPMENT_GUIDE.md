# RUN Campus Connect — Engineering Standards & Development Guide

This guide defines the engineering conventions, architectural patterns, state management standards, release workflows, and tooling guidelines for developing on the **RUN Campus Connect** codebase.

---

## 1. Feature-First Directory Structure

All application source code resides under `lib/`. Code must be organized by **feature** rather than by layer:

```
lib/
├── app.dart                        # Root application widget (MaterialApp.router)
├── firebase_options.dart           # Generated FlutterFire configuration
├── main.dart                       # App entry point, background services & splash screen
├── core/                           # Shared infrastructure across all features
│   ├── config/                     # Environment and service configurations
│   ├── constants/                  # Universal spacing and university constants
│   ├── providers/                  # Shared Firebase singleton providers
│   ├── services/                   # App-wide services (FCM, Presence, Updates, Analytics)
│   ├── theme/                      # Brand theme specifications and theme controllers
│   └── widgets/                    # Reusable atomic UI components
├── router/                         # Declarative routing and auth state machine
└── features/                       # Independent domain modules
    ├── auth/
    ├── chat/
    ├── explore/
    ├── home/
    ├── notifications/
    ├── posts/
    ├── profile/
    ├── settings/
    └── update/
```

### Layer Rules within a Feature

```
features/<feature>/
├── data/           # Repositories, remote API clients, Firestore queries
├── domain/         # Immutable data models, entities, enums, business logic
└── presentation/   # Screens, widgets, and Riverpod StateNotifiers/Controllers
```

- **Domain must not depend on Data or Presentation**. Keep domain entities pure Dart without Flutter dependencies whenever possible.
- **Presentation interacts with Data exclusively through Repositories**. UI widgets must never execute direct Firestore queries or HTTP requests.
- **Controllers manage state mutation**. Screens delegate user gestures to Riverpod controllers.

---

## 2. Riverpod 2.x State Management Standards

The platform strictly uses Riverpod with **code generation** (`riverpod_annotation` and `riverpod_generator`).

### 2.1 Provider Declaration Conventions

#### 1. Global Infrastructure Singletons (`keepAlive: true`)
For long-lived services, repositories, and platform wrappers that should never be disposed:
```dart
@Riverpod(keepAlive: true)
PostRepository postRepository(Ref ref) {
  return PostRepository(
    firestore: ref.watch(firestoreProvider),
    cloudinaryService: ref.watch(cloudinaryServiceProvider),
    auth: ref.watch(firebaseAuthProvider),
    notificationService: ref.watch(notificationServiceProvider),
    analyticsService: ref.watch(analyticsServiceProvider),
  );
}
```

#### 2. Real-Time Stream Providers
For reactive Firestore queries:
```dart
@Riverpod(keepAlive: true)
Stream<List<Post>> globalPostsStream(Ref ref) {
  return ref.watch(postRepositoryProvider).watchGlobalPosts();
}
```

#### 3. Asynchronous UI Controllers (`AsyncNotifier`)
For UI flows involving network calls and loading states:
```dart
@riverpod
class CreatePostController extends _$CreatePostController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> submit({
    required String content,
    required PostVisibility visibility,
    File? imageFile,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null) throw Exception('Profile not loaded');
      await ref.read(postRepositoryProvider).createPost(
        content: content,
        author: profile,
        visibility: visibility,
        imageFile: imageFile,
      );
    });
  }
}
```

### 2.2 Error Handling with `AsyncValue.guard`
Never wrap controller logic in raw `try/catch` blocks that assign errors to ad-hoc boolean variables. Use `AsyncValue.guard`:
- Automatically converts uncaught exceptions into `AsyncValue.error(e, stackTrace)`.
- UI screens observe state changes using `ref.listen`:
  ```dart
  ref.listen<AsyncValue<void>>(
    createPostControllerProvider,
    (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        },
        data: (_) {
          context.pop();
        },
      );
    },
  );
  ```

### 2.3 Code Generation Command
Generated files are committed to the repository. After modifying any `@riverpod` annotation:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Declarative Routing Standards (`go_router`)

- **Screen Route Constants**: Every screen class must expose `static const routeName` and `static const routePath`:
  ```dart
  class ChatScreen extends StatelessWidget {
    static const routeName = 'chat';
    static const routePath = '/chat/:userId';
    ...
  }
  ```
- **Type-Safe Navigation**: Pass primitive identifiers via `pathParameters` or `queryParameters`. Complex non-serializable objects (like a news detail map) may be passed via `extra`.
- **Navigation Inside Controllers**: Controllers must not hold `BuildContext`. Return values or state transitions trigger navigation in the UI widget layer via `context.go()` or `context.push()`.

---

## 4. UI Design & Theming Conventions

### 4.1 Redeemer's University Brand Tokens
Defined in `lib/core/theme/app_theme.dart`:
```dart
static const Color runBlue = Color(0xFF003366);       // Primary Navy
static const Color runGold = Color(0xFFFFCC00);       // Secondary Gold
static const Color executiveNavy = Color(0xFF050A30); // Dark Background
static const Color executiveCard = Color(0xFF1E272E); // Dark Surface
```

### 4.2 Material 3 Standard Rules
- Always use `Theme.of(context).colorScheme` rather than hardcoding colors in widgets.
- Use `ShimmerBox` as a placeholder while network images or streams are loading.
- For modal confirmation dialogs, follow the platform styling in `core/widgets/`.

---

## 5. Adding a New Feature Step-by-Step

Follow this disciplined 6-step checklist when introducing a new feature:

1. **Model Creation (`domain/`)**:
   Create immutable entity classes in `lib/features/<name>/domain/`. Implement `fromMap`, `toMap`, and equality checks.
2. **Repository Implementation (`data/`)**:
   Create `<name>_repository.dart` in `lib/features/<name>/data/`. Annotate the repository provider with `@Riverpod(keepAlive: true)`.
3. **Controller & State (`presentation/`)**:
   Create `<name>_controller.dart` in `lib/features/<name>/presentation/` using `@riverpod class <Name>Controller extends _$NameController`.
4. **UI Screen & Widgets (`presentation/`)**:
   Build the user interface using `ConsumerWidget` or `ConsumerStatefulWidget`.
5. **Route Registration (`router/app_router.dart`)**:
   Add the route to `app_router.dart`. If access requires authentication or specific profile states, update `resolveAuthRedirect` in `auth_redirect.dart`.
6. **Unit & Widget Testing (`test/`)**:
   Add corresponding test suites in `test/features/<name>/`.

---

## 6. Release Engineering & Build Workflows

### 6.1 Versioning Scheme
Version numbering is maintained in `pubspec.yaml`:
```yaml
version: 1.0.0+4
```
- Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- In Android builds: `1.0.0` maps to `versionName`, while `4` maps to `versionCode`.
- Whenever deploying an update, increment the build number.

### 6.2 App Icon & Native Splash Generation
Configured in `pubspec.yaml`:
```bash
# Regenerate Android and iOS launcher icons
dart run flutter_launcher_icons

# Regenerate native Android 12+ splash screens
dart run flutter_native_splash:create
```

### 6.3 Local APK and App Bundle Builds
```bash
# Build release APK for direct installation
flutter build apk --release

# Build Google Play Android App Bundle (AAB)
flutter build appbundle --release
```
The output files will be generated at:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### 6.4 Shorebird OTA Code Push Deployment
```bash
# Check Shorebird installation and app registration
shorebird doctor

# Deploy a new base release (first release of a version)
shorebird release android

# Push a live Over-The-Air Dart patch to active users
shorebird patch android
```

---

## 7. Git Hygiene & Credentials Policy

> [!CAUTION]
> Never commit secrets, API keys, or private service account certificates to Git.

The following files are strictly ignored via `.gitignore`:
- `python_backend/serviceAccountKey.json`
- `vercel_functions/.env` and `vercel_functions/.env.local`
- `android/app/google-services.json` (if containing private staging keys)
- `.env` files across all directories

Before creating a commit or pull request:
```bash
# Check code formatting
dart format --output=none --set-exit-if-changed lib test

# Run static analysis
flutter analyze

# Execute test suite
flutter test
```
