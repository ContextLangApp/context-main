# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected device
flutter run -d <device-id>
flutter devices                  # list available devices

# Build
flutter build apk                # Android
flutter build ios                # iOS

# Test
flutter test                     # all tests
flutter test test/widget_test.dart  # single file

# Lint / analyze
flutter analyze
```

## Architecture

**AI-Integrated German language learning app** ("Context") built with Flutter + Supabase. Early-stage — most features are stubs.

### Auth flow
`main.dart` initializes Supabase, then `_RootPage` listens to `supabase.auth.onAuthStateChange` (a stream). Authenticated users go to `MainShell`; unauthenticated users go to `WelcomePage`. No manual session checks needed — the stream handles transitions automatically.

**Critical navigation pattern:** `SignUpPage` and `LogInPage` are pushed on top of `WelcomePage` via `Navigator.push`. They are NOT replaced by `_RootPage` automatically — the pushed route stays on top even after the auth stream fires. Each auth page is responsible for popping itself:
- Email sign-up: checks `AuthResponse.session` after `signUp()`; pops if session exists (email confirmation disabled), shows snackbar if null (email confirmation required).
- Email login: calls `Navigator.pop()` after `signInWithPassword()` succeeds.
- Google OAuth on `LogInPage`: subscribes to `onAuthStateChange` in `initState`, pops on `AuthChangeEvent.signedIn`. This is necessary because `signInWithOAuth` returns immediately (before the deep link callback fires).

### Feature structure
```
lib/features/
  welcome/welcome_page.dart   — video background, feature carousel, CTA buttons, Google OAuth
  auth/log_in_page.dart       — email/password login + Google OAuth; auth stream listener for Google sign-in nav
  auth/sign_up_page.dart      — email/password sign-up; checks AuthResponse.session to navigate
  auth/auth_page.dart         — retired (stub comment only); replaced by log_in_page + sign_up_page
  home/home_page.dart         — top bar (stats + sign-out), one active lesson card, locked placeholders
```

`MainShell` (in `main.dart`) is a bottom-nav shell with 4 tabs. Only the **Home** tab is implemented; the other three (Practice, Leagues, Profile) render `Placeholder()`.

### Welcome page
Uses `video_player` for the background video asset (`assets/videos/welcome_bg.mp4`). While the video is loading (or if the file is missing/invalid), a purple→pink gradient is shown as fallback. The carousel uses `PageView.builder` with uniform circle dot indicators (no pill shape). The carousel has no card background — title and body text float directly over the video.

The page has two button states controlled by `_showSignUp`:
- **Default:** "Get Started" (sets `_showSignUp = true`) and "I already have an account" (opens `LogInPage`)
- **Sign-up view:** Google OAuth button and "Continue with Email" button (opens `SignUpPage`); a back arrow resets `_showSignUp = false`. Both buttons are white pill-shaped. A legal text line ("By continuing…") sits below.

**To use a real video:** replace `assets/videos/welcome_bg.mp4` with an actual mp4 file — the current file is a placeholder.

### Log in page (`log_in_page.dart`)
Light gray background (`0xFFEFF3F7`). Layout: X dismiss button (top-right), "Log in to your account" title, Google pill button, "or with email" label, email + password underline fields, "Log in" CTA pinned to bottom (disabled until both fields filled), "Forgot password?" stub link.

Subscribes to `onAuthStateChange` in `initState` (cancelled in `dispose`) to pop after Google OAuth completes via deep link. Email login pops explicitly after `signInWithPassword` succeeds.

### Sign up page (`sign_up_page.dart`)
Same light gray background and layout style as `LogInPage`. Fields: email + password (with eye toggle). "Continue" button disabled until both fields non-empty. After `signUp()`: pops if `response.session != null` (immediate sign-in); shows "check your email" snackbar if session is null (email confirmation required).

### Google logo
Both `welcome_page.dart` and `log_in_page.dart` use a `_GooglePlaceholder` widget — a plain `0xFFE0E0E0` grey circle. Replace the `Container` inside it with `Image.asset(...)` when the real logo asset is ready.

### Deep links
Supabase OAuth deep links use the `io.supabase.context` URL scheme:
- **Android:** intent filter in `AndroidManifest.xml`
- **iOS:** URL scheme in `Info.plist`
- **Supabase dashboard:** `io.supabase.context://login-callback/` must be in Authentication → URL Configuration → Redirect URLs. Without this, Supabase falls back to the project's Site URL (default: `localhost:3000`).

### Color palette
Consistent across all screens:
- Purple `0xFF8B5CF6` — primary buttons, gradients
- Pink `0xFFEC4899` — accents, gradients
- Light gray `0xFFEFF3F7` — scaffold background (auth pages)
- Disabled button blue-gray `0xFFB8C4E0`

### State management
None — raw `StatefulWidget` throughout. Direct `Supabase.instance.client` calls inside widgets with no service/repository layer.

### Supabase
Credentials are hardcoded in `main.dart`. The project uses `supabase_flutter ^2.5.0`. Currently only Auth is wired up; no database queries or storage calls exist yet.
