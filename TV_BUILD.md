# RustDesk TV 版 · 构建与装机手册

目标设备：Android 7.1（API 25）电视盒子，1920×1080 横屏输出，只有遥控器（D-pad）。
基线：`rustdesk/rustdesk` master，官方版本 `1.5.1`，`minSdkVersion 22`（已兼容 Android 7.1）。

---

## 1. 为什么必须重编译，不能改安装包

RustDesk 的界面由 Flutter / Dart 渲染，编译后进入 `libapp.so` 与 `libflutter.so`，
**不是可替换的 Android XML 资源**。用 APKTool 改 `res/` 只能改图标和字符串，
改不了主界面、字号、焦点框和布局。

所以要改外观，唯一路径是：

```
Fork 源码 → 改 Dart UI → 改 AndroidManifest → 生成 flutter-rust-bridge
→ vcpkg 编解码依赖 → cargo-ndk 编译 Rust 核心 → flutter build apk → 重签名
```

官方只在 Linux runner 上验证过 Android 构建（`flutter/build_android_deps.sh`、
`ndk_arm.sh` 里的路径都是 `linux-x86_64`）。本机是 Windows，且缺 Flutter SDK、
Android NDK、vcpkg、Docker，WSL 也被策略禁用 —— **本机出不了 APK，必须走云端 CI**。

---

## 2. 编译（GitHub Actions · 已自动跑通）

实际仓库：<https://github.com/zfzong/rustdesk-tv-android7>，
分支 `tv-android7`（已设为默认分支），提交 `e130426`。
Fork 的 Actions 已通过 API 开启并把工作流权限设为 write，无需手动点黄色提示条。
首次运行：[run 42449364642](https://github.com/zfzong/rustdesk-tv-android7/actions/runs/42449364642)。

重新构建时：仓库 → **Actions** → 左侧 `RustDesk TV (Android 7.1)` → **Run workflow**
（分支选 `tv-android7`）。

参数：

- `abi`：`armv7`（安卓 7.1 老盒子默认，32 位）/ `arm64` / `both`
- `tv_mode`：`true` = TV 横屏遥控器界面；`false` = 官方手机版界面（同一套源码对照用）

首次构建要编译 `cargo-expand`、`flutter_rust_bridge_codegen`、
vcpkg 的 FFmpeg/Opus 等依赖、Rust NDK 核心库和 Flutter，
**通常在 2–4 小时之间**，期间 Actions 页面长时间没有日志输出是正常的。

完成后在运行结果页底部 **Artifacts** 下载 `rustdesk-tv-apk-armv7`
（或 arm64），解压得到 `rustdesk-tv-armv7-android7.apk`。

> 只推 `tv-android7` 分支而保留官方 `master`，是为了避开官方 `ci.yml` /
> `flutter-ci.yml` 的 `push: branches: [master]` 触发，不会连带跑全平台构建。

关键实现：

| 项 | 值 |
| --- | --- |
| Flutter | 3.24.5（官方 Android CI 同版本） |
| NDK | r28c |
| Rust | 1.75 |
| cargo-ndk | 3.1.2 |
| vcpkg commit | `9e593bb18ea69cc5095e012465dcd675a822ed0d` |
| 签名 | debug 签名（`signingConfigs.release` → `signingConfigs.debug`），免 key.properties |
| TV 开关 | `--dart-define=TV_MODE=true` |
| bridge | 仓库不提交 `generated_bridge.dart`，workflow 内先跑 `flutter_rust_bridge_codegen` 生成 |

> 产物是 debug 签名的 release 包，**与官方正式包签名不同，二者不能覆盖安装，只能二选一**。
> 自建包也不会收到官方自动更新，升级要重新跑一次 workflow。

---

## 3. 确认盒子架构与系统

```bash
adb connect <盒子IP>:5555          # 盒子需先开启「开发者选项 → 网络 ADB」
adb devices
adb shell getprop ro.product.cpu.abi        # armeabi-v7a → armv7；arm64-v8a → arm64
adb shell getprop ro.build.version.sdk      # Android 7.1 = 25
```

装错架构会报 `INSTALL_FAILED_NO_MATCHING_ABIS`。

---

## 4. 装机四步（设计稿 D 板）

系统授权弹窗在电视上遥控器点不到，以下四步装机时用 ADB 一次做完。

```bash
# 1) 安装 APK
adb install -r rustdesk-tv-armv7-android7.apk

# 2) 开启无障碍服务「RustDesk Input」（被控端输入控制必需）
adb shell settings put secure enabled_accessibility_services \
  com.carriez.flutter_hbb/com.carriez.flutter_hbb.InputService
adb shell settings put secure accessibility_enabled 1
# 个别 ROM 用短写法，若上一条不生效再试：
# adb shell settings put secure enabled_accessibility_services com.carriez.flutter_hbb/.InputService

# 3) 授权屏幕录制 MediaProjection
adb shell monkey -p com.carriez.flutter_hbb -c android.intent.category.LEANBACK_LAUNCHER 1
# 在 App 内点「共享屏幕 / Start service」，系统弹窗出现后：
adb shell uiautomator dump /sdcard/ui.xml >/dev/null
adb shell cat /sdcard/ui.xml | tr '>' '\n' | grep -iE "立即开始|start now|允许|allow"
# 找到「立即开始」按钮的 bounds 中心坐标，例如 [960,620]，然后：
adb shell input tap 960 620
# 也可以纯按键：adb shell input keyevent 20  (DPAD_DOWN)  然后 66 (ENTER)

# 4) 关电池优化 + 允许后台自启
adb shell dumpsys deviceidle whitelist +com.carriez.flutter_hbb
```

启动入口已补 `LEANBACK_LAUNCHER`，盒子桌面能直接看到图标；
普通桌面用 `adb shell am start -n com.carriez.flutter_hbb/.MainActivity` 也能起。

自建服务器（ID Server / Key）在主界面「设置」→「打开官方设置」里填，
系统键盘在盒子上不好用，建议用 `adb shell input text "<服务器地址>"` 辅助输入，
或直接沿用公共服务器。

---

## 5. TV 版改了什么

### Android 层（`AndroidManifest.xml`）

- `android:screenOrientation="landscape"` 锁定横屏
- 新增 `LEANBACK_LAUNCHER` intent-filter，桌面可见
- `android:banner="@drawable/tv_banner"` 电视横幅（320×180 矢量）
- `android.hardware.touchscreen` / `software.leanback` / camera / microphone
  全部 `required="false"` —— 不这么写，无触摸屏的盒子会装不上或直接不显示图标

### Flutter 层（`flutter/lib/tv/`）

| 文件 | 作用 |
| --- | --- |
| `tv_entry.dart` | `kTvMode` 编译期开关（`--dart-define=TV_MODE=true`） |
| `tv_theme.dart` | 设计稿色板 + 1920×1080 像素换算 + 5% Overscan 安全区 + 焦点三态 |
| `tv_focus.dart` | D-pad 按键映射（方向键 / OK / 返回 / 菜单 / 数字键）+ 底部按键提示条 |
| `tv_keypad.dart` | 遥控器数字键盘（电视没有触屏输入法） |
| `tv_home_page.dart` | 主界面「连接到设备」，接官方 `connect()` / 本机 ID / 密码 / 服务状态 / 最近连接 |
| `tv_settings_page.dart` | 遥控器交互与首次配置说明页 |
| `tv_session_overlay.dart` | 会话中 HUD（可选叠加组件） |

`main.dart` 只改 3 处：两个 import、`runMobileApp()` 里锁横屏/沉浸式、
`home:` 按 `kTvMode` 选 `TvHomePage` 或原 `HomePage`。
**关掉 TV_MODE 就是官方原版，方便对照验证。**

### 可选：会话中 HUD

设计稿 C 板的 HUD / 工具栏做成了 `TvSessionOverlay` 组件，默认**不挂载**，
因为真实远程画面由官方 `RemotePage` 渲染，直接换页会破坏连接功能。
需要时在 `flutter/lib/mobile/pages/remote_page.dart` 的会话 Stack 顶层加：

```dart
if (kTvMode)
  Positioned.fill(
    child: TvSessionOverlay(
      peerName: gFFI.ffiModel.pi.hostname.isNotEmpty
          ? gFFI.ffiModel.pi.hostname
          : '远程设备',
      onDisconnect: () => gFFI.close(),
    ),
  ),
```

对应 import：`tv/tv_entry.dart`、`tv/tv_session_overlay.dart`。
`gFFI.close()` 若与当前版本不符，换成官方远程页里原有的断开调用即可。

---

## 6. 遥控器操作

| 按键 | 主界面 | 会话中 |
| --- | --- | --- |
| 方向键 上/下 | 栏内移动焦点 | 移动虚拟光标 |
| 方向键 左/右 | 左栏 ↔ 右栏跨栏 | 移动虚拟光标 |
| OK | 确认 / 调出数字键盘 | 左键（长按拖动） |
| 数字键 0–9 | 直接录入远程 ID | — |
| 菜单 | 打开设置 | 工具栏 |
| 返回 | 连按两次退出 | 右键 / 断开 |

焦点顺序：ID 输入框 → 连接 → 地址簿 / 设置 →（按右键）最近连接列表。
右栏「本机 ID 卡片」不可聚焦，符合设计稿 A 板「每屏唯一初始焦点」原则。

---

## 7. 常见坑

| 现象 | 原因 / 处理 |
| --- | --- |
| Actions 页没有运行按钮 | fork 仓库的 Actions 默认关闭，先点黄色提示条启用 |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | 架构选错，用 `getprop ro.product.cpu.abi` 确认后重编 |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 装过官方包，签名不同；先 `adb uninstall com.carriez.flutter_hbb` |
| 桌面看不到图标 | LEANBACK_LAUNCHER 未生效 / 桌面缓存；用 `am start` 验证，或换第三方桌面 |
| 连接后黑屏 / 不能控制 | 无障碍服务或 MediaProjection 没授权，回到第 4 节重新做 |
| 构建中途 Actions 超时（6h） | 拆成两次单 ABI 运行，vcpkg 二进制缓存会命中，第二次显著变快 |
| 磁盘不足 | workflow 已用 `free-disk-space` 清掉 dotnet / haskell / docker 镜像 |
| 官方源码更新后补丁失效 | `apply_tv_patch.py` 是幂等的，会提示找不到的锚点，按提示手工对齐 3 处字符串即可 |
