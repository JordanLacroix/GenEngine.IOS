# GenEngine for iOS and iPadOS

Native SwiftUI client for playing interactive stories powered by GenEngine. The repository is an adaptable product foundation: it includes a polished offline demo, authenticated backend access, and Debug-only authoring tools.

## Product slice

- Premium narrative home and library.
- Immersive choice-based player with motion and accessibility support.
- Offline demo so the product remains reviewable without a backend.
- Identity, Authoring, and Play API integration.
- Developer controls isolated from release builds.
- Universal layout for iPhone and iPad.

## Requirements

- Xcode 26 or later.
- Swift 6.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44 or later.

## Generate and run

```bash
brew install xcodegen
xcodegen generate
open GenEngine.xcodeproj
```

The Xcode project is generated and intentionally ignored. `project.yml` is the source of truth.

Choose **Explore the demo** on the welcome screen to navigate the complete product slice without a running backend.

## Connect to GenEngine locally

Start the backend from the GenEngine repository:

```bash
docker compose -f compose.yaml up --build -d --wait
```

In a Debug build, open **Developer** and configure the three service URLs. Simulator defaults use `localhost`; a physical device needs reachable HTTPS endpoints. App Transport Security is not disabled globally.

The bundled `forest-choice.json` fixture can be imported and published from the Developer screen. Tokens are stored in Keychain; endpoint preferences are stored in `UserDefaults`.

## Architecture

```text
GenEngine/
├── App/                 App entry point, navigation and product state
├── Core/
│   ├── Configuration/   Environments and endpoint persistence
│   ├── DesignSystem/    Tokens and reusable components
│   ├── Models/          API and presentation models
│   ├── Networking/      Typed API client
│   └── Security/        Keychain-backed credentials
└── Features/
    ├── Authentication/
    ├── Developer/       Debug builds only
    ├── Home/
    ├── Library/
    └── Player/
```

Views depend on `AppState`; remote I/O is isolated behind `GenEngineAPI`. Fixtures live in `DemoStory` and never alter production responses.

## Quality

```bash
xcodebuild build -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

xcodebuild test -project GenEngine.xcodeproj -scheme GenEngine \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Swift Testing covers deterministic demo navigation and API enum compatibility. GitHub Actions regenerates the project before every build.

## Security notes

- No credentials or personal LAN address are committed.
- Release builds contain no Developer tab or authoring import UI.
- Cleartext traffic is not globally allowed. Use HTTPS for devices and deployed environments.
- The mobile app currently talks to the three GenEngine services directly. A single public edge endpoint is recommended before production distribution.
