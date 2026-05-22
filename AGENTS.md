# AGENTS.md

**Context** — an AI-integrated German learning app focused on contextual reading and real-life scenario conversations. Built with Flutter + Supabase. Early-stage — most features are stubs.

## Commands

```bash
flutter run -d <device-id>       # run on device
flutter devices                  # list devices
flutter build apk                # Android build
flutter build ios                # iOS build
flutter test                     # all tests
flutter test test/widget_test.dart  # single file
flutter analyze                  # lint
```

## Architecture

### App shell & navigation

`main.dart` initializes Supabase, then `_RootPage` listens to `supabase.auth.onAuthStateChange`. Authenticated → `MainShell`; unauthenticated → `WelcomePage`.

`MainShell` is a bottom-nav shell with 4 tabs: **Home** (implemented), **Practice**, **Leagues**, **Profile** (all `Placeholder()`).

### Auth flow

Auth pages (`SignUpPage`, `LogInPage`) are pushed on top of `WelcomePage` via `Navigator.push`. They are **not** replaced by `_RootPage` automatically — each page is responsible for popping itself after auth succeeds. For Google OAuth, this means subscribing to `onAuthStateChange` and popping on `signedIn`, since `signInWithOAuth` returns before the deep link callback fires.

Deep links use the `io.supabase.context://login-callback/` scheme (configured in `AndroidManifest.xml` and `Info.plist`). This URL must also be in Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.

### Feature structure

```
lib/features/
  welcome/welcome_page.dart   — video background, feature carousel, CTA buttons, Google OAuth
  auth/log_in_page.dart        — email/password login + Google OAuth
  auth/sign_up_page.dart       — email/password sign-up
  home/home_page.dart          — top bar (stats + sign-out), one active lesson card, locked placeholders
```

### State management

None — raw `StatefulWidget` throughout. Direct `Supabase.instance.client` calls inside widgets with no service/repository layer.

### Supabase

Credentials are hardcoded in `main.dart`. Uses `supabase_flutter ^2.5.0`. Only Auth is wired up — no database queries or storage calls yet.

### Design tokens

- Purple `0xFF8B5CF6` — primary buttons, gradients
- Pink `0xFFEC4899` — accents, gradients
- Light gray `0xFFEFF3F7` — scaffold background (auth pages)
- Disabled button blue-gray `0xFFB8C4E0`

### Placeholder assets

- **Welcome video:** `assets/videos/welcome_bg.mp4` is a placeholder — a gradient fallback shows while loading or if missing.
- **Google logo:** `_GooglePlaceholder` widget (grey circle) is used in `welcome_page.dart` and `log_in_page.dart`. Replace with `Image.asset(...)` when the real asset is ready.