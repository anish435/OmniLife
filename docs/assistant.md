# Assistant (chat and voice)

A conversational assistant that can set reminders, add tasks, notes, events
and transactions, quick-log OmniPulse moments, tick habits and answer a few
questions about your own data. It uses Groq's free tier
(`llama-3.3-70b-versatile`). Open it from the mic on the dashboard or at
`/assistant`.

## Turning it on

1. Get a free key at <https://console.groq.com/keys>.
2. Copy `.env.example` to `.env` (git-ignored) and set `GROQ_API_KEY=...`.
3. Run with the define file. No code changes are needed.

Web (Chrome or Edge, needed for voice):

```
flutter run -d chrome --dart-define-from-file=.env
```

or, headless, as the project's launch config does:

```
flutter run -d web-server --web-port 8765 --dart-define-from-file=.env
```

Android:

```
flutter run -d <device-id> --dart-define-from-file=.env
flutter build apk --dart-define-from-file=.env
```

Without the file, pass the key directly instead:
`flutter run --dart-define=GROQ_API_KEY=your_key`.

Without a key the rest of the app is unaffected and the Assistant screen
says "The assistant isn't set up yet."

Defines are compile-time. Restart (not hot reload) after changing `.env`.

> The key is compiled into the app. That is fine for local development and
> a personal build, but do not publish a web build or APK containing a key
> you care about. Put a small proxy in front of Groq before shipping.

### Optional defines

| Define          | Purpose                                                      |
| --------------- | ------------------------------------------------------------ |
| `GROQ_MODEL`    | Override the model (default `llama-3.3-70b-versatile`).      |
| `AI_MEMORY_URL` | Base URL of a memory service (for example in front of MongoDB). Off by default; memory then stays on-device only. |

The memory contract is `POST {url}/memory/{userId}` with `{text, at}` and
`GET {url}/memory/{userId}?limit=3` returning `[{text, at}]`.

## Voice

* Dictation uses `speech_to_text`: Chrome and Edge on the web, and Android.
  The browser or phone asks for microphone access the first time you tap
  the mic. If it is blocked or unsupported, the assistant says so in plain
  words and you can type instead.
* The final transcript is sent automatically.
* Spoken replies use `flutter_tts`. They are on after a voice command and
  off after a typed one. The speaker icon in the app bar mutes them.
* Android: `RECORD_AUDIO` and the speech/TTS service `queries` are in the
  manifest.

## How it behaves

* Low-risk writes (reminder, task, note, event, transaction, pulse log,
  habit) happen immediately and show a result card with Undo.
* Deleting anything, or an unclear request, asks first: a confirmation card
  or a one-line question.
* Everything goes through the existing controllers and services, so lists
  refresh and data syncs the same way as when you add things by hand.
* Reminders go through the `ReminderService` contract in
  `lib/domain/repositories/reminder_repository.dart`. It is looked up lazily;
  until the Reminders feature registers it the assistant says reminders
  aren't available yet.

### Reminder rules

* Day-part defaults: tonight 9 PM, morning 8 AM, afternoon 2 PM, evening 6 PM.
* "daily", "every day", "each day", "everyday", "every morning/night" repeat
  daily; "weekly" and "every Monday" repeat weekly; otherwise it fires once.
* A one-off with only a time that has already passed today moves to tomorrow.

## Free-tier friendliness

* One model request per command (round 1 returns tool calls); the
  confirmation text is written locally from the tool results.
* Compact prompt and tool schemas, and only the last 12 messages (about six
  turns) are sent.
* HTTP 429 or 5xx: one retry (honouring a short `retry-after`), then
  "I've hit the free usage limit for a moment. Try again in a minute."
* No polling and no background requests.

## Code map

* `lib/domain/assistant/` provider abstraction, tools, engine, reminder time
  rules, memory interface.
* `lib/data/assistant/` `GroqProvider`, chat history store, remote memory.
* `lib/presentation/assistant/` tool implementations and the voice service.
* `lib/presentation/controllers/assistant_controller.dart` and
  `lib/presentation/pages/assistant/assistant_page.dart`.
* `lib/core/bindings/assistant_bindings.dart` lazy registration.
