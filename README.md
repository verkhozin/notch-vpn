<p align="center">
  <img src="docs/notchvpn.png" alt="notchVpn" width="128" />
</p>

<h1 align="center">notchVpn</h1>

<p align="center">A macOS background app that watches your public IP and slides a notification out from under the notch the moment your country flips — VPN up, VPN down, no menus, no toast in the corner.</p>

<p align="center">
  <a href="#build--run">Build &amp; run</a> ·
  <a href="#details-that-make-it-feel-alive">How it works</a> ·
  <a href="#whats-inside">Architecture</a> ·
  <a href="https://github.com/verkhozin/notch-vpn/blob/main/AGENTS.md">Contributing</a>
</p>

It lives in the menu bar, polls a chain of IP providers every 30 seconds, and the only time you ever see it is when the country your traffic appears to come from actually changes. When it does, the physical notch lights up at the outline, then a black pill grows down out of it — same corner radius, same shoulders, no visible seam — and shows you exactly what happened: VPN connected, VPN dropped, country switched. A second or so later it retracts back into the notch and disappears.

## Details that make it feel alive

- **Morph anchored to the real notch** — the pill's start geometry is sampled live from `NSScreen.main.safeAreaInsets.top` plus `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, so on a notched Mac it grows out of the actual cutout instead of from a hardcoded rectangle. On a non-notch display it falls back to a centred virtual notch and the morph still reads as "from above"
- **No seam at the bottom of the notch** — `NotchMorphShape` is a single closed path that starts at `y = 0` and curves out at the bottom corners, so it shares its top edge with the screen and the system notch. The pill literally grows out of the notch; it doesn't sit beneath it
- **Halo before motion** — frame 1 isn't the pill moving. It's a stroke that traces the bottom outline of the still-collapsed notch and gently pulses, so your eye catches the cutout itself before anything starts to expand
- **Phased entry** — halo lights → pill height springs in → width springs in 40–80ms later → content fades up → SF Symbol then *draws itself on* with `.symbolEffect(.drawOff)` last. Five phases on independent timing so the reveal feels composed instead of "everything at once"
- **Spark on disconnect** — VPN drops emit two soft particles from the bottom corners of the pill that scale up and fade out as the body expands, so connect and disconnect read differently before you ever look at the label
- **Restore stagger** — a country switch lands as `oldFlag → arrow → newFlag + name`, each beat 160ms apart, each on its own spring. It tells a tiny story instead of just swapping a string
- **Debounced drop** — a `connected → offline` transition doesn't fire a "connection lost" notification immediately; it parks a 1.5s task. If reachability comes back before then, the drop is cancelled. Spurious offline blips during VPN handoff never reach the user
- **Adaptive backoff** — successful poll resets the interval to 30s; provider error multiplies by 1.5 up to 60s; reachability change resets it and fires an immediate tick. Battery-aware without ever sitting longer than a minute on a stale country
- **Non-stealing panel** — the notification window is an `NSPanel` (not `NSWindow`) with `.borderless`, `.nonactivatingPanel`, `.statusBar` level, and a collection behavior that includes `.canJoinAllSpaces` and `.fullScreenAuxiliary`. It floats above fullscreen apps, joins every Space, and never steals focus from whatever you were doing
- **First country swallow** — the first successful poll after launch is not treated as a "change". You don't get a notification for "you opened the app and you're in DE" — only for actual transitions afterwards

## Ambient by design

The notification *is* the entire app surface. There is no main window, no Dock icon (`LSUIElement = true`), and the menu-bar item is just a flag — the current country if connected, a neutral glyph if offline. Onboarding runs once on first launch and asks for exactly one thing: which country is "home", so a return to it can be detected as a VPN drop. After that, the app is invisible until your apparent country changes.

## What's inside

About 2900 lines of Swift across `App / Core / UI / Utilities`. The notification is a SwiftUI `ZStack` (outer glow → fill → mid glow → core stroke → spark overlay → masked content) hosted in an `NSHostingView` inside a borderless `NSPanel`. The morph itself is two `Shape`s — `NotchMorphShape` for the closed body and `NotchMorphHalo` for the bottom-outline-only stroke — sharing one path generator with a `(.closed | .bottomOutline)` switch, so the halo *is* the silhouette of the body and the two can never drift. Both are driven by a single `NotchAnimationModel` that owns the staged `Task` sequence; SwiftUI `withAnimation` springs on `heightT` / `widthT` / `haloOpacity` / `haloPulse` / `contentOpacity` / `sparkPhase` give every parameter its own response and damping. IP lookup is an `actor IPLookupService` over an ordered chain of `IPProvider`s — each provider declares only its URL and how to map its JSON to `IPInfo`; `IPHTTPFetcher` centralises timeout, User-Agent, `429 → .rateLimited`, and decode-failure handling so adding a new provider is one file. Polling lives in `@MainActor VPNMonitor`: a single `Task` loop with adaptive sleep, plus reactive ticks driven by `NWPathMonitor` via `NetworkReachability`. Strict Swift concurrency is on (`SWIFT_STRICT_CONCURRENCY: complete`); the only allowed singleton is `AppSettings.shared`, every other dependency is wired through `AppCoordinator`. App Sandbox is enabled with only `network.client`; nothing is persisted except the last-known home country code.

## Requirements

- macOS 26.0 (Tahoe)
- Xcode 26 with Swift 5.10 toolchain

## Build & run

```bash
brew install xcodegen          # one time
xcodegen generate              # regenerates notchVpn.xcodeproj from project.yml
open notchVpn.xcodeproj         # then ⌘R in Xcode
```

The app launches as an accessory — no Dock icon, no main window, just a flag in the menu bar. First launch shows a one-shot onboarding sheet that asks you to pin "home country" (so a return to it can be detected as a VPN drop). After that, the app is silent until your public-IP country changes; when it does, the pill slides down from the notch with the new country (or a "Connection lost" pulse if you've fallen back to home). Right-click the menu bar item for a manual refresh.

## Status

A small, focused tool — not a full VPN client. notchVpn never touches `NEVPNManager`; it only observes the public IP via a provider chain (currently `ipapi.co` → `ipwho.is`) and infers VPN state from country transitions. That's intentional: it sidesteps the Sandbox + System Extension complexity required to drive real tunnels, and the IP-poll signal is enough for the actual job — "tell me the moment my apparent country changes." The notification surface, the morph anchored to the physical notch, the multi-phase entry, the provider failover, the reachability-driven refresh — those are real and standalone. Hooking a real `NEVPNManager` (or a third-party tunnel client) into the same `VPNMonitor` callback shape would slot in without touching the UI layer.

## License

MIT — see [LICENSE](LICENSE).
