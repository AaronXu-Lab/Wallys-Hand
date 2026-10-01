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

In **工具 → 端口管理**, add a service name, TCP port, project directory and startup command.
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

Window management is enabled by default and requires Accessibility access. Turn it
off with **窗口管理 → 启用窗口管理** to stop window keyboard and drag monitoring
while keeping port management available. Existing saved preferences are preserved.

Hold **left Control + left Option** to use the default window shortcuts:
**Return** maximizes, **[ / ]** moves to the previous / next screen, arrow keys
cycle through half, third, and two-thirds layouts, and two adjacent arrow keys
select a quarter. The default Stage Manager strip width is **100 px**.

### Build from source

Requires **macOS 26+** and **Xcode 26+ (Swift 6.2)**. Settings use
[AaronUI 0.2.0](https://github.com/AaronXu-Lab/AaronUI-SwiftUI) for semantic colors,
navigation, buttons, switches, inputs, dropdowns, badges, empty states, progress,
settings surfaces, and modal content. Luminare is limited to creating the main
and update windows. SwiftUI/AppKit remains for layout and state, window/menu/file
panel integration, shortcut event recording, native modal focus, and the slider
and multi-select/reorder list behaviors currently retained by this app.
Application-specific compositions live in `App/Components`; they use AaronUI
controls and tokens rather than maintaining a separate visual style. The AaronUI package is pinned to an exact version;
Xcode needs GitHub access to this private repository to resolve it. CI also
needs credentials with read access to AaronUI; the default repository-scoped
`GITHUB_TOKEN` cannot read a separate private repository.

The main window is a tool workspace. **窗口管理** and **端口管理** are peer tools;
window shortcuts, behavior, excluded apps, and advanced options live inside the window tool.
**通用设置** holds application-wide language, launch, and menu bar preferences.
The workspace remembers the last tool and window-tool tab across launches. Use
**⌘1 / ⌘2** to open the tools and **⌘,** for general settings. New tools should add
an `AppDestination` and own their internal navigation instead of adding global preference tabs.

For UI review, launch a Debug build with `--preview-workspace`. This restores the
workspace without starting event taps or requesting accessibility permission.
`--preview-settings` remains supported as a direct preview of port management.

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

### CLI 端口管理

构建应用后，在仓库中使用 `./script/wally`。也可设置 `WALLY_APP="/path/to/Wally‘s Hand.app"` 指定应用。CLI 通过当前登录会话的本地 IPC 调用应用；未运行时会在后台启动应用。旧版本应用需要先退出并重启最新构建。

```bash
./script/wally ports list
./script/wally ports add 7680 --name 'AaronUI Gallery' \
  --directory '/Users/aaronxu/Documents/GitHub/AaronUI-Web' \
  --command 'npm run dev -- --host 0.0.0.0'
./script/wally ports edit 7680 --name 'AaronUI' --monitor-logs true
./script/wally ports delete 7680
```

`edit` 和 `delete` 支持用端口或服务 UUID 定位。`edit` 仅修改提供的字段，可用 `--port` 修改端口；新增和编辑均支持 `--auto-recover true|false`、`--monitor-logs true|false`。目录相对于调用 CLI 时的工作目录解析。命令不会执行所保存的启动命令，新配置保持未启用；保护中的服务必须先在界面停用保护才能编辑或删除。

输出为 JSON，成功退出码为 0，错误为 1；`--help` 查看参数说明。若请求超时，先用 `ports list` 核对结果后再决定是否重试。应用始终负责验证、保存与界面更新，CLI 不直接覆盖偏好设置。回归测试：`./script/test_cli.sh`。
