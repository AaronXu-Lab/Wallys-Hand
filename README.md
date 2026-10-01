<div align="center">
  <img width="225" height="225" src="/assets/branding/wallys-hand-app-icon-master.png" alt="Wally‘s Hand icon">
  <h1><b>Wally‘s Hand</b></h1>
  <p>A personal macOS window utility.</p>
</div>

Wally‘s Hand arranges windows with keyboard shortcuts, cycles, and drag-to-edge snapping. It is a personal fork of [Loop](https://github.com/MrKai77/Loop); original contributors are credited in the app.

## Features

### Keyboard Shortcuts

Wally‘s Hand allows you to assign any key in tandem with the trigger key to initiate a window manipulation action.

<div><video controls src="https://github.com/user-attachments/assets/d865329f-0533-4eeb-829d-9aa6159f454b" muted="false"></video></div>

### Cycles

Wally‘s Hand can become very powerful when paired with cycles. These enable you to perform multiple window manipulations in quick succession by pressing the same key combination repeatedly.

<div><video controls src="https://github.com/user-attachments/assets/1adb1325-775d-4687-9085-71c7f775d65d" muted="false"></video></div>

### Port management

In **Settings → 端口管理**, add a service name, TCP port, project directory and startup command.
Use **导出全部配置** to save every service and its recovery/log settings as one JSON backup;
**导入配置** replaces the saved list after confirmation. Imported services stay disabled.
Project files and logs are not included, so restore the project directories separately.
Commands run in a login zsh with `PORT` set. Use a foreground command (for example,
`npm run dev -- --port 5173 --strictPort`); the project must actually use the configured port.
Do not use a launcher that detaches or supervises its own services.

- Protection starts only when manually enabled, including after relaunch.
- The app identifies listeners by the launched process group and process start times.
  Other listeners on the configured port receive SIGTERM, followed by SIGKILL after two seconds
  if necessary. Processes the app cannot terminate are reported as conflicts.
- A lost listener gets a three-second recovery grace period; initial startup gets 90 seconds.
  Automatic recovery is off by default. When enabled, it retries ten times with backoff,
  resetting the retry budget after two minutes of stable operation. Each service’s **详情** sheet has a live
  **自动恢复** switch: changing it preserves the running process, turning it off cancels pending
  automatic retries, and turning it on recovers an already failed service. An intentionally
  stopped service stays stopped.
- **停止服务** stops recovery and keeps the port protected with a local HTTP 503 page on
  IPv4 and IPv6 loopback. **停用保护** releases it. Quit stops managed processes and placeholders.
- The menu bar shows per-service actions, status, logs, and an alert icon/tooltip on failures.
  It stays visible while protection is enabled, even when the normal menu icon is hidden.

Enable **监听日志** in a service's **详情** sheet to keep appending its process output
and timestamped status/retry events across launches. The switch applies immediately
and persists with the service configuration. Disable it to return to a latest-attempt
log on the next launch. Monitoring logs can grow while the switch is enabled.

The overview cards show only service name, port, status, a primary action, and
**详情**. Details combine configuration, recovery policy, diagnostics, logs,
restart, release, and deletion. Configuration is read-only while protected;
disable protection before editing. Configuration changes require saving, while
the recovery switch for an existing service applies immediately.

Port handoffs have a brief gap; this is polling and reclamation, not an uninterrupted proxy.
The placeholder serves plain HTTP, not HTTPS, and no application-level health check is implied
by “running.” Logs for the latest attempt are in `~/Library/Logs/WallysHand/Ports/`.

Run `./script/test_port_management.sh` for isolated process/socket regression tests.

## Usage

Window management is off by default. Enable it with **Settings → Behavior → 启用窗口管理**;
the app asks for Accessibility access only when you enable it. Turning it off stops
window keyboard and drag monitoring while port management remains available.

### Build from source

Requires **macOS 26+** and **Xcode 26+ (Swift 6.2)**. Settings use
[AaronUI 0.1.1](https://github.com/AaronXu-Lab/AaronUI-SwiftUI) for semantic colors,
buttons, badges, empty states, and service editor fields, alongside Luminare's
window and settings containers. The AaronUI package is pinned to an exact version;
Xcode needs GitHub access to this private repository to resolve it. CI also
needs credentials with read access to AaronUI; the default repository-scoped
`GITHUB_TOKEN` cannot read a separate private repository.

For UI review, launch a Debug build with `--preview-settings`. This opens the
port settings without starting event taps or requesting accessibility permission.

Open `Wally‘s Hand.xcodeproj` and build the `Wally‘s Hand` scheme, or run `./script/build_and_run.sh --verify`.

### Triggering

Wally‘s Hand uses a trigger key to function. Users can assign a key to work with the trigger key, activating specific actions. The trigger key can be set in the "Keybinds" tab and can consist of one or multiple keys.

To set Caps Lock as your trigger key, you have two options:

#### a. Change System Settings

1. Go to System Settings → Keyboard → "Keyboard Shortcuts...".
2. In the "Modifier Keys" tab, remap `Caps Lock (⇪) key` to `(^) Control`.
3. Repeat this remapping process for every connected keyboard.
4. In Wally‘s Hand, select the `Right Control` key as your trigger.

#### b. Use an external App

- [Hyperkey](https://hyperkey.app/)
- [Karabiner Elements](https://karabiner-elements.pqrs.org/)

### Keyboard Shortcuts

<table>
  <thead>
    <tr>
      <th>Category</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>General</strong></td>
      <td>Fullscreen, Maximize, Almost Maximize, Centre, MacOS Centre, Minimize, Hide</td>
    </tr>
    <tr>
      <td><strong>Halves</strong></td>
      <td>Top Half, Bottom Half, Left Half, Right Half</td>
    </tr>
    <tr>
      <td><strong>Quarters</strong></td>
      <td>Top Left Quarter, Top Right Quarter, Bottom Left Quarter, Bottom Right Quarter</td>
    </tr>
    <tr>
      <td><strong>Horizontal Thirds</strong></td>
      <td>Right Third, Right Two Thirds, Horizontal Center Third, Left Two Thirds, Left Third</td>
    </tr>
    <tr>
      <td><strong>Vertical Thirds</strong></td>
      <td>Top Third, Top Two Thirds, Vertical Center Third, Bottom Two Thirds, Bottom Third</td>
    </tr>
    <tr>
      <td><strong>Screen Switching</strong></td>
      <td>Next Screen, Previous Screen, Left Screen, Right Screen, Top Screen, Bottom Screen</td>
    </tr>
    <tr>
      <td><strong>Window Manipulation</strong></td>
      <td>Larger, Smaller, Shrink Top, Shrink Bottom, Shrink Right, Shrink Left, Grow Top, Grow Bottom, Grow Right, Grow Left, Move Up, Move Down, Move Right, Move Left</td>
    </tr>
    <tr>
      <td><strong>More</strong></td>
      <td>Initial Frame, Undo, Custom, Cycle</td>
    </tr>
  </tbody>
</table>

## Contributors

To see all the contributors who have played a significant role in developing Wally‘s Hand, visit our [Contributors](CONTRIBUTORS.md) page.

### How to Contribute

For an extensive guide on how to contribute, check out the [contributing guide](CONTRIBUTING.md).

## FAQ

### Comparison

<table>
  <thead>
    <tr>
      <th></th>
      <th>Wally‘s Hand</th>
      <th>macOS&nbsp;15+</th>
      <th>Rectangle&nbsp;Pro</th>
      <th>Rectangle</th>
      <th>Magnet</th>
      <th>Moom</th>
      <th>Swish</th>
      <th>BetterTouchTool</th>
      <th>Multitouch</th>
      <th>Hammerspoon</th>
      <th>Yabai</th>
      <th>Amethyst</th>
      <th>AeroSpace</th>
      <th>1Piece</th>
      <th>Wins</th>
      <th>MacsyZones</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Price</td>
      <td>Free</td>
      <td>Free</td>
      <td>$9.99</td>
      <td>Free</td>
      <td>$4.99</td>
      <td>$15.00</td>
      <td>$16.00</td>
      <td>$14.00</td>
      <td>$15.99</td>
      <td>Free</td>
      <td>Free</td>
      <td>Free</td>
      <td>Free</td>
      <td>Free</td>
      <td>$13.99</td>
      <td>Free</td>
    </tr>
    <tr>
      <td>Open&nbsp;Source</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Custom&nbsp;Frames</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Modifier&nbsp;+&nbsp;Arrows</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Padding&nbsp;/&nbsp;Margins</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Save&nbsp;Workspace</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Restore&nbsp;Initial&nbsp;Frame</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Pin&nbsp;Windows&nbsp;On&nbsp;Top</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
    </tr>
    <tr>
      <td>Snap&nbsp;Windows&nbsp;via&nbsp;Drag</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
    </tr>
    <tr>
      <td>Resize&nbsp;Adjacent&nbsp;Windows</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Action&nbsp;Sequences&nbsp;(Cycles)</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
    </tr>
    <tr>
      <td>Move&nbsp;Windows&nbsp;Across&nbsp;Screens</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
    </tr>
    <tr>
      <td>Switch&nbsp;Focus&nbsp;Between&nbsp;Windows</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
    </tr>
    <tr>
      <td>Scripting&nbsp;(URL&nbsp;/&nbsp;AppleScript&nbsp;or&nbsp;other)</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
    </tr>
  </tbody>
</table>

> Information was gathered from each app’s official website and other online sources and may be outdated.
> If you notice any inaccuracies, please open an issue or contact the maintainers.
> Special thanks to the [Definitive MacApp Comparisons](https://docs.google.com/spreadsheets/d/1HtJN4oQ6oBDFmFaF4Qeq5vCGEU1g-KB1DEz5Sp_OwXo/edit?gid=456166567#gid=456166567) spreadsheet.

### License

This project is licensed under the [GNU GPLv3 license](LICENSE).

### Compatibility identifiers

The app keeps `com.xuweinan.LoopJust` and the existing `Loop Just` application-support directory to preserve settings and update compatibility. Existing GitHub repository URLs remain unchanged.
