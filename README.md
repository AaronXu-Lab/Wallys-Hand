<div align="center">
  <img width="225" height="225" src="/assets/branding/logo.svg" alt="Logo">
  <h1><b>Loop Just</b></h1>
  <p>Window management made elegant.<br>
  <a href="https://github.com/MrKai77/Loop-Just#features"><strong>Explore Loop Just »</strong></a><br><br>
  <a href="https://github.com/MrKai77/Loop-Just/releases/latest/download/Loop%20Just.zip">Download for macOS</a><br>
  <i>~ Compatible with macOS 13 and later. ~</i></p>
</div>

Loop Just is a macOS app that simplifies window management with keyboard shortcuts. Assign actions to the trigger key to move, resize, and arrange windows quickly, saving valuable time and energy.

> [!NOTE]
>
> Loop Just is constantly evolving, with new features and improvements added regularly to enhance your window management experience on macOS.

<h6 align="center">
  <img src="assets/graphics/loop_demo.gif" alt="Loop Just Demo">
  <br /><br />
  <a href="https://discord.gg/2CZ2N6PKjq">
    <img src="https://img.shields.io/badge/Discord-join%20us-7289DA?logo=discord&logoColor=white&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/MrKai77/Loop-Just/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/MrKai77/Loop-Just?label=License&color=5865F2&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/MrKai77/Loop-Just/stargazers">
    <img src="https://img.shields.io/github/stars/MrKai77/Loop-Just?label=Stars&color=57F287&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/MrKai77/Loop-Just/network/members">
    <img src="https://img.shields.io/github/forks/MrKai77/Loop-Just?label=Forks&color=ED4245&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/MrKai77/Loop-Just/issues">
    <img src="https://img.shields.io/github/issues/MrKai77/Loop-Just?label=Issues&color=FEE75C&style=for-the-badge&labelColor=23272A" />
  </a>
  <br />
</h6>

## Features

### Keyboard Shortcuts

Loop Just allows you to assign any key in tandem with the trigger key to initiate a window manipulation action.

<div><video controls src="https://github.com/user-attachments/assets/d865329f-0533-4eeb-829d-9aa6159f454b" muted="false"></video></div>

### Cycles

Loop Just can become very powerful when paired with cycles. These enable you to perform multiple window manipulations in quick succession by pressing the same key combination repeatedly.

<div><video controls src="https://github.com/user-attachments/assets/1adb1325-775d-4687-9085-71c7f775d65d" muted="false"></video></div>

### Stash

Hide windows at the screen edge to declutter your workspace. Hover near the edge or use a keybind to access them whenever you need.

<div><video controls src="https://github.com/user-attachments/assets/080ba2fb-41b3-4b39-9000-a76f2fc794ed" muted="false"></video></div>

## Usage

### Installation

#### Homebrew

```bash
brew install loop
```

#### Manual Download

Navigate to the [release page](https://github.com/MrKai77/Loop-Just/releases/latest) and download the latest `.zip` file located at the bottom, or [click me](https://github.com/MrKai77/Loop-Just/releases/latest/download/Loop%20Just.zip).

### Triggering

Loop Just uses a trigger key to function. Users can assign a key to work with the trigger key, activating specific actions. The trigger key can be set in the "Behavior" tab of the "Settings" section and can consist of one or multiple keys.

To set Caps Lock as your trigger key, you have two options:

#### a. Change System Settings

1. Go to System Settings → Keyboard → "Keyboard Shortcuts...".
2. In the "Modifier Keys" tab, remap `Caps Lock (⇪) key` to `(^) Control`.
3. Repeat this remapping process for every connected keyboard.
4. In Loop Just, select the `Right Control` key as your trigger.

#### b. Use an external App

- [Hyperkey](https://hyperkey.app/)
- [Karabiner Elements](https://karabiner-elements.pqrs.org/)

#### c. Shell/AppleScript

Loop Just can be controlled via shell commands or AppleScript using its URL scheme:

```bash
# Shell examples
open "loopjust://direction/right"     # Move window to right half
open "loopjust://action/maximize"     # Maximize window
open "loopjust://screen/next"         # Move to next screen

# AppleScript examples
osascript -e 'tell application "Loop Just" to activate'
osascript -e 'open location "loopjust://direction/left"'
```

You can also create custom scripts to chain multiple actions:

```bash
#!/bin/bash
# Example: Move window right and then maximize
open "loopjust://direction/right"
sleep 0.5
open "loopjust://action/maximize"
```

For a complete list of available commands:

```bash
open "loopjust://list/all"           # List all commands
open "loopjust://list/actions"       # List window actions
open "loopjust://list/keybinds"      # List custom keybinds
```

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

To see all the contributors who have played a significant role in developing Loop Just, visit our [Contributors](CONTRIBUTORS.md) page.

### How to Contribute

For an extensive guide on how to contribute, check out the [contributing guide](CONTRIBUTING.md).

## FAQ

### Comparison

<table>
  <thead>
    <tr>
      <th></th>
      <th>Loop Just</th>
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
      <td>Stashed&nbsp;Windows</td>
      <td>✅</td>
      <td>❌</td>
      <td>✅</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
      <td>❌</td>
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
