// RustDesk TV · 遥控器 D-pad 按键层
// 遥控器没有 hover、没有滑动、没有多点触控；所有交互收敛到方向键 / OK / 返回。
// 这里不接管 Flutter 的 FocusNode 遍历，而是把按键映射成语义回调，
// 由页面自己维护「唯一焦点索引」，避免二维跳跃（设计稿 A 板原则 1）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tv_theme.dart';

/// 把遥控器 / 键盘按键翻译成语义动作的透明壳层。
class TvDpad extends StatelessWidget {
  const TvDpad({
    Key? key,
    required this.child,
    required this.onOk,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.onBack,
    this.onDigit,
    this.onMenu,
  }) : super(key: key);

  final Widget child;
  final VoidCallback onOk;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onBack;
  final ValueChanged<String>? onDigit;
  final VoidCallback? onMenu;

  static String? digitOf(LogicalKeyboardKey k) {
    // LogicalKeyboardKey 的 == 是自定义实现（比较 keyId），没有 primitive
    // equality，不能作为 const map 的 key；否则 Dart 在 kernel_snapshot 阶段
    // 报 "Constant evaluation error"。这里必须是运行期 final。
    final digits = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return digits[k];
  }

  static bool isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.space;

  // 用 keyLabel 兜底，避免不同 Flutter 版本对 Android KEYCODE_BACK / MENU
  // 的 LogicalKeyboardKey 常量命名差异导致编译失败。
  static bool isBack(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.escape ||
      k == LogicalKeyboardKey.backspace ||
      k.keyLabel == 'Go Back';

  static bool isMenu(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.contextMenu ||
      k == LogicalKeyboardKey.f10 ||
      k.keyLabel == 'Context Menu';

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      // 不要显示 Flutter 自带的焦点高亮，高亮由 TvFocusBox 按设计规范绘制
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowUp) {
          onUp?.call();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          onDown?.call();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          onLeft?.call();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          onRight?.call();
          return KeyEventResult.handled;
        }
        if (isOk(k)) {
          onOk();
          return KeyEventResult.handled;
        }
        if (isBack(k)) {
          if (onBack != null) {
            onBack!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (isMenu(k)) {
          if (onMenu != null) {
            onMenu!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        final d = digitOf(k);
        if (d != null && onDigit != null) {
          onDigit!(d);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// 底部常驻按键提示条（设计稿 A 板原则 3）
class TvKeyHints extends StatelessWidget {
  const TvKeyHints({Key? key, required this.items}) : super(key: key);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final full = BoxConstraints(maxWidth: size.width, maxHeight: size.height);
    final s = TvS.of(context);
    return Container(
      height: s.p(72),
      padding: EdgeInsets.symmetric(horizontal: s.p(24)),
      decoration: BoxDecoration(
        color: TvC.panel,
        borderRadius: s.br(10),
        border: Border.all(color: TvC.border, width: s.p(1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: s.p(40)),
            Text(
              items[i],
              style: tvText(full, 26,
                  color: i == 0 ? TvC.accent : TvC.text2,
                  weight: i == 0 ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }
}
