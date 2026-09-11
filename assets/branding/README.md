# 应用图标资源使用说明

本目录由唯一事实源 `logo.svg` 生成。除更新该 SVG 外，不要直接编辑平台产物；源文件变化后应重新运行图标生成 SKILL。

## Web

- `web/favicon.svg`：现代浏览器首选 favicon，保留 SVG 内部的明暗主题切换。部署后通过 `<link rel="icon" type="image/svg+xml">` 引用。
- `web/favicon.ico`：旧浏览器及 `/favicon.ico` 约定的兼容回退，包含常用小尺寸。
- `web/apple-touch-icon.png`：iOS/iPadOS 网页添加到主屏幕时使用。它是满幅不透明方图，不要再次预制圆角。
- `web/pwa/icon-192.png` 与 `web/pwa/icon-512.png`：PWA 的普通应用图标。
- `web/pwa/icon-maskable-512.png`：PWA maskable 图标，背景满幅且主体位于安全区。
- `web/pwa/manifest.webmanifest`：只声明上述三张 PWA 图标。若产品已有 manifest，应合并 `icons`，不要覆盖名称、启动路径、显示模式、范围或主题色；网页仍需通过 `<link rel="manifest">` 引用最终 manifest URL。

## iOS 与 macOS

- `iOS&macOS/app.icon`：iOS 与 macOS 共用的 Icon Composer 应用图标包，包含 Default、Dark 与 Tinted/Mono 外观。通过 Xcode 或 Icon Composer 加入应用图标配置，不要转换为 `.icns` 代替。
- `iOS&macOS/app.icns`：用于传统 macOS（包括 2023 年以前的版本）或要求 ICNS 的打包工具，与 `.icon` 同时保留。内含 16、32、128、256、512 点的 1x/2x 图像，最大 1024×1024；固定明色主题，不自动切换外观，保留源图轮廓与透明区域。原生应用可放入 `Contents/Resources` 并通过 `CFBundleIconFile` 引用；其他打包工具使用对应图标配置。临时 `.iconset` 不随资源交付。
- `iOS&macOS/menu-bar/appTemplate.svg`：macOS 菜单栏 Template Image 的矢量源，由系统按当前外观着色。
- `iOS&macOS/menu-bar/appTemplate.png` 与 `appTemplate@2x.png`：分别用于 1x/2x 菜单栏位图接入。加载后应标记为 template image，不要作为全彩应用图标使用。

## Windows

- `windows/app.ico`：用于应用可执行文件、安装器、快捷方式及窗口图标，内含多种尺寸。
- `windows/tray-light.ico`：用于浅色系统主题或浅色托盘背景，图形采用深色前景。
- `windows/tray-dark.ico`：用于深色系统主题或深色托盘背景，图形采用浅色前景。应用应监听系统主题并选择对应文件。

## Linux

- `linux/app.svg`：可缩放应用图标，并保留 SVG 明暗主题行为。优先作为桌面集成的矢量源；若目标桌面或打包格式要求固定 PNG 尺寸，应在集成阶段从该 SVG 渲染，不要反向编辑生成文件。

## Android

- `android/res/`：自适应启动图标资源。将所需文件合并到应用模块的 `src/main/res/`，不要覆盖项目中无关资源。
- `mipmap-anydpi-v26/ic_launcher.xml` 与 `ic_launcher_round.xml`：自适应图标入口，引用背景、前景与 monochrome 图层。
- 各密度 `ic_launcher_foreground.png`：自适应前景；各密度 `ic_launcher_monochrome.png`：Android 主题图标遮罩；`ic_launcher.png`：旧版本回退。
- `android/play-store-512.png`：提交 Google Play Console 的 512×512 商店图。它是满幅、无预制圆角的 32-bit RGBA PNG；Alpha 通道存在且所有像素均为 255，由商店负责最终遮罩与阴影。

## 集成边界

这些文件是资源交付，不会自动修改产品仓库的 HTML、manifest、Xcode、Windows 打包、Linux desktop entry 或 Android Gradle 配置。接入时应遵循目标项目现有结构，并合并而不是覆盖既有产品元数据。
