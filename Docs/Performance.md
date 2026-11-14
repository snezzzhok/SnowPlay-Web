> Исторические замеры предыдущей графики. Актуальная интеграция: [Asset-Integration-Report.md](Asset-Integration-Report.md), [asset-performance-result.json](asset-performance-result.json).

# Performance report

Measured locally on 2026-11-12, macOS 26.6.2 / arm64, one Retina 2× display. Release build, ad-hoc signature. Balanced preset, 1 ordinary windows, 42 free particles, battery power, decorations disabled. 5 s warmup followed by 20 one-second samples. Local control requests were included. Raw values are in `performance-result.json`.

| Measurement | Actual | Target / interpretation |
| --- | --- | --- |
| Simulation pacing | 29.74 Hz median | Battery target 30 Hz; **not** a presented-frame/GPU measurement |
| Timer interval p95 | 34.67 ms | At 30 Hz, nominal interval is 33.33 ms |
| CPU, one-core equivalent | 8.82% median, 9.56% max | Aspirational <=3% target **not achieved** |
| Resident memory (RSS) | 54.91 MiB median | RSS alone excludes important graphics accounting |
| Physical footprint | 65.50 MiB median, 65.53 MiB max | Below 150 MiB in this ordinary-work sample; decorations require separate qualification |
| Explicit Pause CPU | 0.66% of one core | External `ps` process-time delta over 3 s |
| GPU / displayed FPS | Not measured | Requires Instruments / unlocked interactive profiling |
| Several-hour soak | Not performed | Release gate remains open |

The active session was observed (`activeSimulationObserved: true`, `systemPaused: false`). An earlier attempt took place in an inactive session and correctly suspended effects; those paused timings were not used to claim active performance.

## Isolated physics benchmark

Release engine only, 400 free particles and 40 sampled surfaces, 3,600 fixed simulation steps after warmup:

- Mean step: 0.0858 ms.
- p95 step: 0.0988 ms.
- Maximum observed step: 0.3902 ms.

This isolates simulation cost and does **not** measure AppKit, SpriteKit, compositor, GPU or whole-application CPU. Raw values: `physics-benchmark.json`; source: `Scripts/Benchmark.swift`.

## Optimizations implemented and measured boundaries

- Reused particle storage; foreground dots/caps/frost use a lightweight Core Graphics canvas, with no per-flake SpriteKit nodes.
- Bounded free particles (400/display) and event particles (80 scheduler budget); normal density substantially lower.
- Smooth wind interpolation, sampled accumulation rather than per-grain simulation.
- Surface geometry redraw limited to 20 Hz, while free particles follow configured frame pacing.
- Desktop SpriteKit view is created lazily only for visible ornaments, then paused when hidden.
- Paused/hidden/system-suspended views stop rendering.
- Dock and window geometry share one CG snapshot; Dock AX search is bounded, cached and backed off.
- Existing AX window matches avoid repeated enumeration; per-app AX messaging timeouts are bounded.
- Battery/Low Power Mode limits refresh to 30 Hz and reduces particle count.
- Small textures are loaded lazily with a bounded cache; compressed custom artwork is below 1 MiB.

A sampled native stack confirmed significant time in Dock/CG metadata calls and graphics framework work. That motivated shared snapshots, Dock caching, and pausing unused rendering. Raw profiler output is intentionally kept in ignored `.build`, not committed as user environment data. The remaining CPU gap requires further profiling; this build is a functional preview, not a claim that all performance targets are met.

## Renderer decision

The initial all-SpriteKit foreground measured 9.66% median CPU and 157.79 MiB physical footprint (`performance-spritekit-baseline.json`). After that measurement, simple foreground snow/frost moved to Core Graphics; SpriteKit remains responsible for ornament animation. The final sample above has substantially lower physical footprint.

A per-particle partial-invalidation experiment made AppKit drawing substantially more expensive on this host (116.28% median one-core-equivalent CPU). It was rejected and is **not** in the packaged app. The production canvas uses one coalesced full redraw, while geometry is cached. `performance-incremental-experiment.json` records the rejected experiment for transparency.

`Scripts/test-renderer.sh` verifies transparency, small dot drawing, removal without trails and cap draw/removal using our own offscreen bitmap, with no desktop capture. It passed on the final source.

## Reproduce

```sh
SNOWPLAY_LOCAL_TOOLCHAIN_WORKAROUND=1 Scripts/package.sh # this host only
python3 Scripts/performance-sample.py
```

Run without other SnowPlay instances, in an unlocked desktop session. Repeat on mains, multiple resolutions/displays, decorations enabled, foreground typing, fullscreen and extended runtime. Use Instruments Time Profiler / Metal System Trace / Allocations for GPU, actual presented frames, energy use and memory attribution. Do not infer these results from the local canvas preview.

The measurements above predate the window-local 3–5 second effect update. They remain baseline measurements; CPU/GPU cost while the new regional effects are active has not been separately profiled.
