// RustDesk TV · 构建期开关
//
// 同一份源码可产出两种包：
//   flutter build apk --dart-define=TV_MODE=true   → 电视盒子横屏 / D-pad 版
//   flutter build apk                              → 官方原版手机版
//
// 用编译期常量而不是运行期「是否 TV」探测，原因：
//   1. Android 7.1 盒子很多没有 android.software.leanback，运行期探测会漏判；
//   2. 不需要改动 Kotlin / Java 原生层，也不需要新增 MethodChannel；
//   3. 一个 fork 可同时维护两条产物线。
const bool kTvMode = bool.fromEnvironment('TV_MODE', defaultValue: false);
