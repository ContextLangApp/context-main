# CLAUDE.md

**Context** — an AI-integrated German learning app focused on contextual reading and real-life scenario conversations. Flutter + Supabase, with Supabase Edge Functions proxying Azure AI services. Early-stage.

## Commands

```bash
flutter run -d <device-id>                       # run on device
flutter run --dart-define=GEMINI_API_KEY=<key>   # speak-practice needs this
flutter devices                                  # list devices
flutter build apk / flutter build ios
flutter test                                     # all tests (currently an empty stub)
flutter analyze                                  # lint
```

## App shell & navigation

`main.dart` initializes Supabase, then `_RootPage` listens to `auth.onAuthStateChange`:
- No session → `WelcomePage`
- Session but no `profiles` row → `OnboardingFlow`
- Session + profile → `MainShell`

The profile check runs on both `signedIn` and `initialSession`, so interrupted onboarding resumes on restart.

`MainShell` is a 4-tab bottom nav: **Home** (implemented), **Practice**, **Leagues**, **Profile** (all `Placeholder()`). Feature entry points currently live as cards on Home, not under the Practice tab.

## Auth

Email/password + Google OAuth via Supabase. Auth pages (`SignUpPage`, `LogInPage`) are pushed over `WelcomePage` and pop themselves after auth — `_RootPage` does not replace them. Google OAuth subscribes to `onAuthStateChange` and pops on `signedIn`, since `signInWithOAuth` returns before the deep-link callback.

Deep link scheme `io.supabase.context://login-callback/` (in `AndroidManifest.xml`, `Info.plist`, and Supabase Dashboard → Auth → Redirect URLs).

## Features

```
lib/features/
  welcome/                 — video background, feature carousel, CTA, Google OAuth
  auth/                    — log_in_page, sign_up_page (auth_page.dart is a dead stub)
  onboarding/              — 3-step flow (name, reason, topics); upserts to `profiles`
  home/                    — top bar (stats + sign-out), feature cards, locked placeholders
  article_reader/          — shows a local article matched to the user's favorite_topics
  speak_practice/          — on-device speech_to_text → Gemini feedback
  scenario_conversation/   — record audio → Azure STT → chat → TTS playback
```

## Services & AI backends

Two parallel stacks (a known inconsistency worth consolidating):
- `services/gemini_service.dart` — **direct client call** to Gemini for speak-practice feedback. Key via `--dart-define=GEMINI_API_KEY` (compiled into the build).
- `services/azure_conversation_service.dart` — calls Supabase Edge Functions (`supabase/functions/azure-{stt,chat,tts}`) that hold the Azure keys server-side. Chat is Grok via Azure AI Foundry. Auth header uses the signed-in JWT, falling back to the anon key.

## Data & state

- `data/local_articles.dart` — hardcoded B1 German articles; `articleForTopics()` picks by topic. No DB-backed content yet.
- Supabase: Auth + a `profiles` table (`id`, `name`, `learning_reason`, `favorite_topics`). No other queries/storage. Credentials hardcoded in `main.dart` and duplicated in the Azure service.
- No state management — raw `StatefulWidget` with direct `Supabase.instance.client` calls in widgets; no repository layer or caching.

## Design tokens

- Purple `0xFF8B5CF6` — primary buttons, gradients
- Pink `0xFFEC4899` — accents, gradients
- Light gray `0xFFEFF3F7` — scaffold background
- Disabled blue-gray `0xFFB8C4E0`

## Placeholder assets

- `assets/videos/welcome_bg.mp4` — placeholder; gradient fallback shows if missing.
- `_GooglePlaceholder` (grey circle) stands in for the Google logo in `welcome_page.dart` and `log_in_page.dart`.
- Welcome carousel copy and Home stats (streak/diamonds/stars, hardcoded `0`) are placeholders.
