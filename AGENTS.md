# AGENTS.md — notchVpn

Guidance for any agent (human or AI) working in this repo. Keep it loaded; update when conventions change.

## What this app is

A macOS background app that polls the public IP, detects country changes (= VPN connect/disconnect), and slides a notification down from the notch. No dock icon (`LSUIElement = true`). Status item lives in the menu bar.

## Project layout

```
notchVpn/
├── project.yml                       # XcodeGen spec — single source of truth
├── notchVpn.xcodeproj/               # generated; do NOT hand-edit
├── Sources/notchVpn/
│   ├── App/                          # entry point + lifecycle
│   │   ├── notchVpnApp.swift
│   │   ├── AppDelegate.swift
│   │   └── AppCoordinator.swift      # wires services & UI
│   ├── Core/
│   │   ├── Models/                   # plain Sendable value types
│   │   ├── Services/
│   │   │   ├── IPProviders/          # one struct per upstream API
│   │   │   ├── IPLookupService.swift # actor — provider chain + fallback
│   │   │   ├── VPNMonitor.swift      # @MainActor — polling + backoff
│   │   │   └── NetworkReachability.swift
│   │   └── Storage/                  # UserDefaults wrappers
│   ├── UI/
│   │   ├── Notch/                    # NSPanel + SwiftUI hosting
│   │   ├── MenuBar/
│   │   ├── Settings/
│   │   └── Shared/
│   ├── Utilities/
│   │   ├── Logger.swift
│   │   └── Extensions/
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       └── notchVpn.entitlements
└── Tests/notchVpnTests/
```

## Tooling

- **Project generation**: `xcodegen generate` — every time `project.yml` or files change.
- **Build (CLI)**: `xcodebuild -project notchVpn.xcodeproj -scheme notchVpn -configuration Debug build`
- **Test (CLI)**: `xcodebuild -project notchVpn.xcodeproj -scheme notchVpn test`
- **Adding a file**: drop it under `Sources/notchVpn/...` and re-run `xcodegen generate`. Never add files via Xcode UI — they won't be reflected in `project.yml`.

## Hard rules

### Code language
All identifiers, comments, log messages, commit messages — **English only**. UI strings stay English unless the user asks otherwise.

### Concurrency
- Strict concurrency is **on** (`SWIFT_STRICT_CONCURRENCY: complete`). Every type that crosses an actor boundary must be `Sendable`.
- UI and presenters: `@MainActor`.
- Pure data services that fan out work: `actor`.
- No `DispatchQueue.main.async` for UI hops — use `await MainActor.run { ... }` or `Task { @MainActor in ... }`.
- No `DispatchSemaphore` to bridge async APIs. Use `withCheckedContinuation` only at SDK seams (e.g. `NWPathMonitor`).
- Capture `[weak self]` inside any `Task { ... }` that outlives a single await.

### No singletons (with one exception)
Wire dependencies through `AppCoordinator`. The only allowed shared instance is `AppSettings.shared` (UserDefaults wrapper — note: not named `Settings` to avoid shadowing SwiftUI's `Settings` scene). Everything else takes its dependencies via initializer.

### Networking
- Always set `URLRequest.timeoutInterval` (≤ 10s). Default is 60s and will hang the polling loop.
- Always set a `User-Agent` header (`notchVpn/<version>`).
- HTTPS only. No `NSAppTransportSecurity` exceptions. If a provider is HTTP-only, drop it.
- Treat `429` explicitly → `IPProviderError.rateLimited`, advance to next provider.
- Provider chain is ordered by reliability. Adding a provider = new file in `IPProviders/`, conformance to `IPProvider`, append to `AppCoordinator`.

### Polling & battery
- Adaptive backoff in `VPNMonitor`:
  - Healthy tick (any successful fetch, including a country change) → reset to `baseInterval` (30s).
  - Provider error → `× 1.5`, cap at `maxInterval` (60s).
  - Reachability change (online / offline / path change) → reset to `baseInterval` and refresh.
- Never poll faster than 30s. The notch app is for awareness, not real-time monitoring.
- Reachability gate: if `NetworkReachability.isOnline == false`, skip the fetch entirely and emit `.offline`.

### Notch UI
- Use `NSPanel` (subclass `NotchWindow`) with `.borderless`, `.nonactivatingPanel`, `level = .statusBar`. Never `NSWindow` — it would steal focus.
- `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary` so the notification shows over fullscreen apps.
- Position by `NSScreen.main.frame.maxY` minus content height. Don't try to physically clip to the notch cutout — render below it; the notch shape remains visually intact.
- SwiftUI views go inside `NSHostingView`. Keep view code pure: no service calls from views.
- Auto-dismiss with `Task.sleep` + cancellable `dismissTask`; never use `Timer` (retain cycles + main-thread coupling).

### Privacy
- The only persisted data is the last known country code (for cold start). No IP, no logs to disk.
- App Sandbox is on. Only `network.client` entitlement.
- No analytics, no telemetry, no crash reporting that ships data off-device.

### Logging
- Use `Log.app` / `Log.monitor` / `Log.network` / `Log.ui` from `Utilities/Logger.swift`.
- Never log raw IPs at `default`/`info` level — drop to `.debug` or redact via `\(ip, privacy: .private)`.
- No `print()` outside of test scaffolding.

### Testing
- Mocks are protocol-based. `IPProvider` is the seam — tests inject `StubProvider`.
- No live HTTP in tests. `URLSession` is never hit by unit tests.
- `@testable import notchVpn` is supported because tests use `BUNDLE_LOADER=$(TEST_HOST)`.
- New service → new tests file mirroring path: `Sources/notchVpn/Core/Services/Foo.swift` → `Tests/notchVpnTests/FooTests.swift`.

## Patterns

### Adding a new IP provider
1. New file `Sources/notchVpn/Core/Services/IPProviders/<Name>Provider.swift`.
2. Conform to `IPProvider` (`name`, `func fetch() async throws -> IPInfo`).
3. Use `IPHTTPFetcher` to perform the HTTP call — it handles timeout, User-Agent, 429 → `.rateLimited`, and decode failure → `.decodingFailed`. The provider only declares the URL, the response shape, and how to map it to `IPInfo`.
4. Append to providers array in `AppCoordinator.init()`.
5. `xcodegen generate`.

### Adding a UI surface in the notch
1. New SwiftUI view in `UI/Notch/`.
2. Have the presenter (or a new presenter under `UI/Notch/`) instantiate `NotchWindow` and host the view.
3. Animations — use SwiftUI `.transition(.move(edge: .top))` inside the view, not AppKit window-frame animations.

### Adding a setting
1. Add a key + getter/setter in `Core/Storage/Settings.swift` (the type is `AppSettings`).
2. Read it from the consuming service via init injection — don't pull `AppSettings.shared` in random files.
3. Bind it in `SettingsView` with `@AppStorage` only for trivial toggles; otherwise route through `AppSettings`.

## Don'ts

- Don't add a third-party dependency unless the alternative is genuinely worse than 200+ lines of in-house code. Adding any SPM dependency requires updating `project.yml` and AGENTS.md.
- Don't introduce a "service locator" or DI container. The coordinator is enough.
- Don't tap into `NEVPNManager` for now — Sandbox + System Extension complexity isn't worth it for the current scope. Keep it as IP-poll-only.
- Don't render the notch UI on `NSStatusBarButton.window`. Use a dedicated `NSPanel`.
- Don't bypass the provider chain — no direct `URLSession.shared.data` calls outside `IPProviders/`.
- Don't add a launch-at-login feature without `SMAppService` + a clear settings toggle (and a test).
- Don't widen entitlements without updating this file and writing down why.

## Build matrix

- macOS deployment target: **26.0** (Tahoe).
- Swift: 5.10 toolchain (Xcode 26).
- Architectures: arm64 + x86_64 universal in Release.
- Notch geometry assumes M-series MacBook Pro / Air. App still works on non-notch displays — notification just appears at top center.

## Common failure modes

| Symptom                                   | Likely cause                                                       |
| ----------------------------------------- | ------------------------------------------------------------------ |
| Notification never appears                | App is sandboxed without `network.client`, or status bar item never installed → check `applicationDidFinishLaunching` |
| Country flips between two values          | Two screens / VPN load-balancing — debounce by requiring N consecutive same-country reads before firing |
| 429 storms                                | Single provider getting hammered — confirm chain has ≥2 providers and rate-limit triggers `× 1.5` backoff |
| Window steals focus                       | `NSWindow` instead of `NSPanel`, or missing `.nonactivatingPanel`  |
| `@testable import` fails                  | `BUNDLE_LOADER` / `TEST_HOST` missing in test target settings      |
