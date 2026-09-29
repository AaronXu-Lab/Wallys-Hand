# Wally‘s Hand icon sources

- `wallys-hand-app-icon-master.png`: AXO-style master artwork for the macOS app icon: porcelain-white pinch gesture, deep-blue window frame, and a pearl pale-blue Icon Composer background. Generated with the built-in imagegen tool. See `wallys-hand-app-icon-redraw-prompt.md` for the current production prompt.
- `wallys-hand-menubar-template.png`: monochrome transparent template extracted from the app artwork.
- `Wally‘s Hand/Resources/AppIcon-WallysHand.icon/`: active Xcode app icon package using the master artwork for Default and Dark, with system-derived Tinted rendering.
- `Wally‘s Hand/Assets.xcassets/menubarIcon.imageset/`: 18 px and 36 px menu bar template images derived from the transparent source.

The older `logo.svg` and non-macOS platform files in this directory belong to the original Wally‘s Hand branding and are not used by this macOS build.

- `wallys-hand-app-icon-previous-green.png`: preserved previous green master for rollback.

- `wallys-hand-app-icon-previous-flat.png`: previous flat blue-black version, preserved for comparison.
