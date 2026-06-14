# CLAUDE.md

**Context** — an AI-integrated German learning app focused on contextual reading and real-life scenario conversations. Flutter + Supabase, with Supabase Edge Functions proxying Azure AI services. Early-stage.

## Commands

```bash
flutter run -d <device-id>                       # run on device (no AI keys needed)
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

`MainShell` is a 4-tab bottom nav: **Home** and **Practice** (implemented), **Leagues**, **Profile** (still `Placeholder()`). The learning features are entered as cards on Home; the Practice tab is the saved-vocabulary Dictionary.

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
  speak_practice/          — on-device speech_to_text → Azure feedback
  scenario_conversation/   — record audio → Azure STT → chat → TTS playback
  practice/                — Practice tab: saved-vocabulary Dictionary (list, delete, speaker)
```

## Save Vocabulary

Cross-cutting feature for capturing words from any learning content into a per-user dictionary:
- `widgets/vocabulary_selectable_text.dart` — drop-in replacement for German `Text`; long-press a single word → "Save to Dictionary" toolbar action. Used in `article_reader` (body), `speak_practice` (transcript), `scenario_conversation` (both message bubbles). German content only; English tips/feedback stay plain `Text`.
- `services/vocabulary_service.dart` — `saveVocabulary` (normalize → reject multi-word → dup-check → enrich → insert), `fetchSavedVocabulary`, `deleteVocabulary`.
- `services/tts_playback_service.dart` — shared Azure TTS fetch + playback (extracted from `scenario_conversation`, which now uses it). Dictionary speaker button speaks `"word. example"`.
- `supabase/functions/enrich-vocabulary` — Azure AI Foundry call returning meaning/pronunciation/example/usage as JSON.
- `saved_vocabulary` table (`supabase/migrations/`): per-user words with `(user_id, normalized_word)` unique key and owner-only RLS.

## Services & AI backends

**AI policy: all cloud AI goes through Supabase Edge Functions backed by Azure — no AI-provider keys in the client.** Two Azure services sit behind the functions: Azure **Speech** (`AZURE_SPEECH_*`) for STT/TTS, and Azure **AI Foundry** (OpenAI-compatible, currently Grok, `AZURE_OPENAI_*`) for the LLM. On-device `speech_to_text` is allowed for live transcription (no cloud key).

- `services/azure_ai_service.dart` (`AzureAiService`) — the single AI gateway. Methods: `transcribeAudio`, `chat`, `synthesizeSpeech`, `getSpeakingFeedback`, `enrichVocabulary`. Calls the edge functions over HTTP with the signed-in JWT (anon-key fallback).
- `services/tts_playback_service.dart` — wraps `AzureAiService.synthesizeSpeech` + `audioplayers` playback; shared by scenario and the Dictionary speaker.
- `services/vocabulary_service.dart` — dictionary CRUD; enrichment delegated to `AzureAiService.enrichVocabulary`.
- `services/profile_service.dart` — reads the `profiles` row (`profileExists`, `favoriteTopics`); used by `main.dart` and `article_reader`.
- Edge functions: `azure-stt`, `azure-tts` (Azure Speech); `azure-chat`, `enrich-vocabulary`, `speaking-feedback` (Foundry). New AI capabilities should follow this pattern, not call a provider from the client.

Foundry functions prompt for JSON and parse defensively (strip ```json fences); they avoid `response_format: json_object`, which triggers a "Failed to reconstruct non-streaming response" 500 on the Grok deployment.

## Data & state

- `data/local_articles.dart` — hardcoded B1 German articles; `articleForTopics()` picks by topic. No DB-backed content yet.
- Supabase: Auth + `profiles` and `saved_vocabulary` tables (the latter is the only DB-backed feature content, with RLS; schema in `supabase/migrations/`). Credentials live in `config/app_config.dart` (`AppConfig`).
- No state management library — raw `StatefulWidget`s. DB access is moving into thin services (`profile_service`, `vocabulary_service`) rather than inline `Supabase.instance.client` calls in widgets; no caching yet.

## Design tokens

- Purple `0xFF8B5CF6` — primary buttons, gradients
- Pink `0xFFEC4899` — accents, gradients
- Light gray `0xFFEFF3F7` — scaffold background
- Disabled blue-gray `0xFFB8C4E0`

## Placeholder assets

- `assets/videos/welcome_bg.mp4` — placeholder; gradient fallback shows if missing.
- `_GooglePlaceholder` (grey circle) stands in for the Google logo in `welcome_page.dart` and `log_in_page.dart`.
- Welcome carousel copy and Home stats (streak/diamonds/stars, hardcoded `0`) are placeholders.
