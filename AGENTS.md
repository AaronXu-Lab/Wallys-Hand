# AGENTS.md

Wally‘s Hand is a personal macOS menu-bar utility (fork of [Loop](https://github.com/MrKai77/Loop)) with three tools: window management, port/service management, and memory monitoring. Swift 6.2, macOS 26+, Xcode 26+. UI copy is Simplified Chinese.

Note the path quirk: the project, scheme and source folder are named `Wally‘s Hand` with a **curly apostrophe (U+2018)**, not `'`. Always quote these paths.

## Commands

```bash
./script/build_and_run.sh            # Debug build (unsigned) + launch; kills any running instance first
./script/build_and_run.sh --verify   # build only and check the bundle id (com.xuweinan.LoopJust)
./script/build_and_run.sh --logs     # build, launch, stream os_log for the process
./script/build_and_run.sh --debug    # build and run under lldb
swiftformat --lint .                 # CI lint (Lint workflow); `swiftformat .` to fix
./script/package_dmg.sh              # universal Release build, ad-hoc signed DMG into dist/
```

Debug builds land in `.codex/rename-build` (override with `DERIVED_DATA_PATH`). A Debug build launched with `--preview-workspace` (or `--preview-settings` → port tool) shows the UI without event taps, accessibility prompts or service supervision — use it for UI review.

### Tests

There is no XCTest target. Each suite is a standalone executable that `swiftc` compiles from a hand-picked list of production source files plus `Tests/<Suite>/Regression.swift`:

```bash
./script/test_port_management.sh       # real processes/sockets in a temp dir; needs python3
./script/test_cli.sh
./script/test_memory_monitoring.sh
./script/test_event_monitoring.sh thread   # or: address. Requires ./script/build_and_run.sh --verify first
```

There is no per-test filter; run the suite script. When a production file used by a suite gains a dependency on another file, add that file to the script's `swiftc` list (and keep those files free of app-only imports where possible). The event-monitoring suite links the Debug build's `Defaults.o`/`Scribe.o` and the Scribe macro plugin, so it fails without a prior build. See `Tests/EventMonitoring/README.md` for what it does and does not prove.

### CLI

`./script/wally ports <list|add|edit|delete> ...` runs the built app binary with `--cli`. `LoopApp.init` intercepts `--cli`, and `PortCLI` forwards the command over `DistributedNotificationCenter` to the running app instance (launching it in the background with `--cli-background` if needed). The app (`PortCLIServer` → `PortServiceManager.executeCLI`) is the sole owner of configuration state; the CLI process never edits it directly.

## Architecture

- **App shell** (`App/`): `LoopApp` declares a `Settings` scene hosting `WorkspaceView`; `AppDelegate` starts the CLI server and menu bar, broadcasts a terminate notification so only one instance runs, then starts/stops window management by observing `Defaults[.windowManagementEnabled]`. Navigation is `AppDestination` — new tools add a case there and own their internal navigation rather than adding global settings tabs.
- **Window management**: `Core/LoopManager` (main-actor singleton) owns the trigger lifecycle: `KeybindTrigger` (driven by event taps in `Utilities/Event Monitoring/`, which run on a dedicated `EventTapThread`) opens/closes "Loop" and selects `WindowAction`s. `ResizeContext` carries state for one operation; `WindowActionEngine` → `WindowEngine` → `WindowFrameResolver` compute and apply frames via the Accessibility API (`Window Management/Window/`) or `SystemWindowManager`. `WindowDragManager` handles drag-to-edge snapping. `WindowActionCache` is read from the event-tap thread, so it publishes immutable snapshots — keep it thread-safe. `Private APIs/` wraps SkyLight SPI.
- **Port management** (`Port Management/`): `PortServiceManager` (persistence, UI/CLI façade) → `PortSupervisor` (timer-driven state machine per service: launch, listener detection, conflict kill, recovery backoff) → `PortProcess` (login-zsh process groups) and `PortPlaceholder` (HTTP 503 listener holding the port while stopped). `MenuBarController` surfaces status. These files are compiled outside the app by the test scripts, so they must not depend on SwiftUI/app-only types beyond what the scripts include. Behavioral contract (grace periods, retry counts, log paths) is documented in README.md's "Port management" section — keep it in sync.
- **Memory monitoring** (`Memory Monitoring/`): `MemorySampler` produces `MemorySnapshot`s; views are separate from sampling logic.
- **Updater**: `Updater/` downloads, verifies and installs updates; privileged installs go through the `WallysHandUpdaterHelper` XPC target, with the protocol in `Shared/` (shared between app and helper).
- **Settings/state**: preferences use the `Defaults` package; keys are in `Extensions/Defaults+Extensions.swift`. `Migration/` handles importing old settings (including Rectangle). Logging uses Scribe's `@Loggable`.
- **UI**: settings UI uses AaronUI (`AaronUI-SwiftUI`, private repo pinned to an exact version — resolving packages needs GitHub access to it) for controls and tokens; Luminare only creates the main and update windows. App-specific compositions live in `App/Components` and must use AaronUI controls/tokens, not a separate visual style.
- **Localization**: `Localizable.xcstrings` is synced via Crowdin; `.github/LocalizationSorter.swift` normalizes it.

## Conventions

- Format with SwiftFormat (`.swiftformat`); CI rejects unformatted Swift.
- Document non-trivial code with `///` doc comments explaining behavior, per CONTRIBUTING.md.
- Version and build number live in `Wally‘s Hand/Config.xcconfig`.
- Default branch is `develop`.
