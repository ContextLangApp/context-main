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

**Language learning app** ("Context") built with Flutter + Supabase. Early-stage — most features are stubs.

### Auth flow
`main.dart` initializes Supabase, then `_RootPage` listens to `supabase.auth.onAuthStateChange` (a stream). Authenticated users go to `MainShell`; unauthenticated users go to `WelcomePage`. No manual session checks needed — the stream handles transitions automatically.

After authentication succeeds from `AuthPage`, the stream fires and `_RootPage` replaces the entire navigator stack with `MainShell` automatically — no explicit `Navigator.pop` needed.

### Feature structure
```
lib/features/
  welcome/welcome_page.dart — looping video background, swipeable feature carousel, CTA buttons
  auth/auth_page.dart       — email/password login + sign-up; accepts initialIsLogin param
  home/home_page.dart       — top bar (stats + sign-out), one active lesson card, locked placeholders
```

`MainShell` (in `main.dart`) is a bottom-nav shell with 4 tabs. Only the **Home** tab is implemented; the other three (Practice, Leagues, Profile) render `Placeholder()`.

### Welcome page
Uses `video_player` for the background video asset (`assets/videos/welcome_bg.mp4`). While the video is loading (or if the file is missing/invalid), a purple→pink gradient is shown as fallback. The carousel uses `PageView.builder` with animated pill dot indicators. "Get Started" opens `AuthPage(initialIsLogin: false)`; "I already have an account" opens `AuthPage(initialIsLogin: true)`.

**To use a real video:** replace `assets/videos/welcome_bg.mp4` with an actual mp4 file — the current file is a placeholder.

### State management
None — raw `StatefulWidget` throughout. Direct `Supabase.instance.client` calls inside widgets with no service/repository layer.

### Supabase
Credentials are hardcoded in `main.dart`. The project uses `supabase_flutter ^2.5.0`. Currently only Auth is wired up; no database queries or storage calls exist yet.
