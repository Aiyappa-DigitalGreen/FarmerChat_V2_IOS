# FarmerChat iOS — V2

An AI-powered agricultural advisory chatbot for smallholder farmers, built by [Digital Green](https://www.digitalgreen.org). FarmerChat delivers personalized crop advice, weather updates, and agricultural tips via text, voice, and image queries — in multiple local languages.

---

## Overview

FarmerChat helps farmers get instant, contextual answers to agricultural questions directly on their phones. The app connects to a backend AI service that understands crop health, weather patterns, and farming practices relevant to local contexts across African and Asian markets.

**Bundle ID:** `org.digitalgreen.farmer.chatbot`

---

## Features

| Feature | Description |
|---|---|
| Phone OTP Auth | SMS-based authentication with 180-second OTP timer |
| Text Chat | Natural language queries answered by an AI advisory engine |
| Voice Input | Voice-to-text transcription sent to the AI backend |
| Image Analysis | Crop/plant image submission for disease and health diagnosis |
| Home Feed | Daily personalized advice cards, tips carousel, and weather |
| Multilingual | Backend-driven language selection; 5+ supported languages |
| Chat History | Persistent conversation list with full message threads |
| Location Awareness | GPS → IP geolocation → locale fallback for contextual responses |
| User Profile | Name, gender, livestock and crop preferences |
| Appearance | Light, dark, and system-auto theme support |
| Deep Linking | Pending navigation targets survive cold start and onboarding |

---

## Architecture

The project follows **Clean Architecture with MVVM**, organized by feature module.

```
FarmerChat/
├── App/                  # Root view, navigation router, AppDestination enum
├── Core/
│   ├── Config/           # AppConfig, ApiConstants, FeatureFlags
│   ├── Network/          # APIClient (URLSession actor), APIModels, AppEnvironment
│   ├── Storage/          # PreferencesManager (UserDefaults), KeychainManager
│   ├── Location/         # LocationManager (CoreLocation wrapper)
│   ├── Error/            # ErrorNavigationManager, retry-lambda storage
│   └── SDK/              # AppSDKConfig — MoEngage, Plotline, Firebase, Adjust gates
├── Features/
│   ├── Auth/             # Phone entry, OTP verification, country picker
│   ├── Chat/             # Conversation view, history, follow-up chips
│   ├── Home/             # Daily feed, weather, input bar
│   ├── Onboarding/       # Language selection, name entry
│   ├── Settings/         # Language, profile, logout, appearance
│   ├── Help/             # FAQs
│   ├── Location/         # Location permission prompt flow
│   ├── Legal/            # Privacy policy, terms (in-app WebView)
│   ├── Splash/           # Splash screen
│   └── Error/            # Error display and retry
└── Shared/
    ├── Components/       # LogoMark, MarkdownTextView, TipsCarousel, shared UI
    ├── Extensions/       # AnyCodable, Color+Hex, Loadable<T>
    └── Theme/            # AppTheme — 100+ design tokens (color, spacing, typography)
```

Each feature module contains a **View**, **ViewModel/UseCase**, and **Repository**, keeping UI, business logic, and data access strictly separated.

---

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (100% — no UIKit or Storyboards)
- **Async Pattern:** `async/await` with a custom `Loadable<T>` state enum
- **Networking:** `URLSession` actor with Bearer token auth and automatic 401 token refresh
- **Persistence:** `UserDefaults` (preferences) + Keychain (access/refresh tokens)
- **Navigation:** Type-safe enum routing via `AppDestination`
- **External Dependencies:** **None** (no CocoaPods, SPM, or Carthage)

---

## SDK Integrations

The following SDKs are wired in but **disabled by default** via a master switch (`AppSDKConfig.sdkEventsEnabled = false`). They can be enabled per environment when credentials are configured.

| SDK | Purpose |
|---|---|
| MoEngage | Push notifications & in-app messaging |
| Plotline | Campaign personalization |
| Firebase | Analytics & Crashlytics |
| Adjust | Attribution tracking |

---

## Configuration

Sensitive keys are stored in `Config.plist` (not committed). Create this file from the template and populate:

| Key | Description |
|---|---|
| `GUEST_USER_API_KEY` | API key for unauthenticated (guest) access |
| `MOENGAGE_APP_ID` | MoEngage workspace ID |
| `ADJUST_APP_TOKEN` | Adjust attribution token |
| `PLOTLINE_API_KEY_DEV` | Plotline key for development |
| `PLOTLINE_API_KEY_PROD` | Plotline key for production |

Feature flags (also in `Config.plist`):

| Flag | Description |
|---|---|
| `v2_show_name_screen_onboarding` | Show name entry during onboarding |
| `enable_auth_interstitial` | Show interstitial before auth |
| `chat_feedback_enabled` | Enable thumbs up/down on chat responses |
| `v2_wobble_animation_enabled` | Enable card wobble animation |

---

## API

- **Auth:** Bearer token (access + refresh), guest API-Key fallback
- **Headers:** `Build-Version: v2`, `Device-Info` (JSON-encoded), `Accept-Language`
- **Timeouts:** 15s connection / 30s read-write
- **Endpoints (20+):** User init, OTP send/verify, language ops, home feed, text/voice/image chat, weather, FAQs, profile update

Environment switching (dev/prod) is handled via `AppEnvironment`.

---

## Getting Started

1. **Clone the repo**
   ```bash
   git clone https://github.com/Aiyappa-DigitalGreen/FarmerChat_V2_IOS.git
   cd FarmerChat_V2_IOS
   ```

2. **Add Config.plist** — create `FarmerChat/Config.plist` with the keys listed above.

3. **Open in Xcode**
   ```bash
   open FarmerChat.xcodeproj
   ```

4. **Select a simulator or device** and press **Run** (`⌘R`).

> No package installation step is needed — the project has zero external dependencies.

---

## Project Stats

| Metric | Value |
|---|---|
| Swift files | ~96 |
| Lines of code | ~15,000+ |
| External dependencies | 0 |
| API endpoints | 20+ |
| Feature modules | 10 |
| Supported languages | 5+ (backend-driven) |

---

## Contributing

This is an internal Digital Green project. For access or contributions, contact the Digital Green engineering team at [aiyappa@digitalgreen.org](mailto:aiyappa@digitalgreen.org).

---

## License

Copyright © Digital Green. All rights reserved.
