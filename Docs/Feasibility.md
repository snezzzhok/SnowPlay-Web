> Актуальное обновление: [нижний зимний мир](Floor-World-Revision.md). Снег Dock и отдельная площадка лепки удалены, Йети получил две игры, ёлка — новые варианты. Ниже сохранён предыдущий проход.

> Обновление 13.11.2026: актуальные механики, результаты и ограничения нового ТЗ описаны в [Interactive Winter World](Interactive-Winter-World.md). Предыдущие результаты ниже относятся к указанным в них проходам.

# Feasibility and platform boundaries

Environment inspected 2026-11-12: macOS 26.6.2, arm64, Swift 6.2.4, one display at 2×. Full Xcode is absent; Command Line Tools alone are selected. No private API is used.

## Confirmed in this environment

- Swift source compilation, linking, native process startup, menu bar application, transparent NSWindow/SKView construction and ignoresMouseEvents property.
- Public CG metadata and AX calls are callable. Probe initially reported AX trusted and one Dock-owned row; a later new binary/session reported AX unavailable and zero eligible windows. Trust and GUI session state are prerequisites, not hardcoded assumptions.
- Local HTTP server binds explicitly to IPv4 127.0.0.1 and an ephemeral port. Actual requests verified Origin/Host/token/fetch-site rejection, static serving, state/config/command handling, malformed duplicate headers, no CORS.
- Local control panel rendered in native Safari; Pause/Resume and Focus settings visibly changed.
- Native app packaged and ad-hoc signed. See performance JSON for real process measurements.

The final foreground renderer uses Core Graphics for simple snow/frost after measuring the initial SpriteKit overhead. Ornament animation still uses a lazily created SpriteKit view. The native offscreen renderer check passed transparency and redraw/removal checks without capturing the desktop.

## Event observation and remaining native acceptance

Window observation uses front-to-back CG geometry and public per-app AX observers, matching AX elements by PID + frame, because a public stable CG-window-number attribute is not assumed. Exact same-position windows are ambiguous; hide/missing is never promoted to close. Close/minimize metadata remains available, but the new brief disables associated snow shedding. CG polling follows movement; AX end-of-move notifications alone cannot provide continuous coordinates.

The disposable NSWindow integration fixture initially ran in an inactive session (AX false / no eligible geometry), so that attempt was inconclusive. A later unlocked run observed all transition types: created 2, moved 1, resized 8, minimized 1, restored 1, confirmed closed 2, visibility lost 2. See `window-integration-result.json`. Counts can include concurrent user windows; the timed fixture exercises public NSWindow methods, not pixel simulation. This confirms event observation in that session, not full visual correctness or every macOS configuration.

Dock is represented by one eligible narrow Dock-owned CG rectangle, with a bounded public AXList frame fallback. Ambiguous/auto-hidden geometry hides the strip. Per-icon snow accumulation is unsupported. The new integration supports hats using available public AX app-icon URLs/frames; ambiguous or hidden icons are omitted. Dock multi-edge behaviour still requires manual validation.

Foreground particles/caps use transparent floating windows. Geometry masks prevent known upper windows from being covered; ornament windows live at desktop-icon level + 1 and hide occupied objects. Public NSWindow levels cannot insert an overlay arbitrarily between two foreign windows. Mission Control, Stage Manager, Spaces transitions, panels at nonzero window levels, rounded corner shadows and unusual applications require manual acceptance. Effects cannot promise perfect per-window compositing in every macOS mode.

Sleep/display-sleep/session-switch notifications pause views. A frontmost loginwindow check adds best-effort lock suppression using public app metadata, but macOS does not expose a universal documented “screen is locked” notification through NSWorkspace. Immediate lock suppression in every lock configuration remains unverified; no undocumented distributed notification names or private session dictionary keys are used.

GPU timings, actual presented frame rate, multiple physical displays and several-hour stability are **not measured**. Timer pacing is labeled simulation Hz. Xcode project syntax validates, but xcodebuild/XCTest are unavailable locally. CI is provided and has not been executed by this session.

## Local toolchain repair without system mutation

This host mixes an older `PackageDescription.private.swiftinterface` with a newer dynamic library and has duplicate `SwiftBridging` module maps. `Scripts/local-build.sh` masks the duplicate through a local VFS overlay and copies the matching **public** PackageDescription interface into `.build/toolchain`. It never changes the installed toolchain, security settings or global caches. Normal Xcode users should use `swift build` / `swift test`.

`Scripts/test-core.sh` runs the exact same XCTest test method source with a small local assertion adapter because Command Line Tools do not ship XCTest here. It does not claim XCTest was run. CI uses real XCTest.

## Official API references consulted

- [NSWindow.ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents) — mouse transparency.
- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)) — window metadata, not content capture.
- [AXObserverCreate](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate) and [AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification) — per-application public AX events, errors and unsupported-notification fallback.
- [kAXUIElementDestroyedNotification](https://developer.apple.com/documentation/applicationservices/kaxuielementdestroyednotification) — disposed accessibility element.
- [SKView](https://developer.apple.com/documentation/spritekit/skview) — transparent SpriteKit view, preferred refresh rate and pause.

The minimize/close implementation now uses 3–5 second local snow clocks (default 4 s), not a global SpriteKit scene multiplier. Core tests verify locality, soft boundaries, cancellation, coalescing, saved snow mass, legacy settings and uninterrupted restoration. The real-window snow integration script is `Scripts/test-window-effects.py`; its latest actual result is recorded separately in `window-effects-integration-result.json`.

The controlled native fixture now passes accumulation, minimize and close regions, original-window geometry, 4 s timing, 35% local speed, recovery, saved minimized profile, restoration and final state disposal. It uses actual falling particles and public NSWindow operations, not seeded profiles. This is one desktop-session integration result; the wider compatibility matrix remains open.

## Supplied asset integration validation

See `Asset-Integration-Report.md` for the current revision, `asset-performance-result.json` for the three measured modes, and `window-exclusion-result.json` for the latest real-window regression. Older window-snow performance/results are historical and are superseded. No private API was added.
