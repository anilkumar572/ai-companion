# Nova

Nova is a formal, voice-only AI companion for **Android and iOS**, built with Flutter.

## Features

- Cinematic animated orb interface inspired by sci-fi assistants
- Voice-only interaction with formal responses
- Male or female voice selection
- Reminders stored on device
- Calendar summaries via device calendar access
- Web search via DuckDuckGo instant answers
- Android and iOS only (no web target)

## Getting Started

### Requirements

- Flutter 3.27+
- Android Studio or Xcode for device builds
- Physical device recommended for microphone and speech testing

### Install

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Test

```bash
flutter test
flutter analyze
```

## Voice Commands

Examples:

- "Hello Nova"
- "What is on my calendar today?"
- "Remind me to call the client at 3 PM"
- "Search for renewable energy news"
- "What are my reminders?"

## Permissions

- Microphone — voice input
- Speech recognition — transcription
- Calendar — schedule summaries
- Internet — web search

## Project Structure

```
lib/
  core/          # Theme and constants
  models/        # App state models
  providers/     # Nova session controller
  services/      # Speech, TTS, agent, tools
  ui/            # Screens and animated widgets
```

## Roadmap

- On-device LLM integration via `llamadart`
- Open-source offline STT/TTS via `sherpa_onnx`
- Camera vision commands
- Local notification delivery for reminders
