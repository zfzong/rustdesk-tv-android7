// RustDesk TV · 10-foot UI 设计规范
// 取自设计稿 1920×1080 横屏画板的节点读取值（色板 / 字号 / 尺寸 / 安全区）。
// 本文件不依赖任何业务模型，可独立编译。
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 设计稿色板
class TvC {
  static const bg = Color(0xFF0B0C0F);
  static const bgSession = Color(0xFF050608);
  static const remoteBg = Color(0xFF0C1220);
  static const panel = Color(0xFF17181D);
  static const panel2 = Color(0xFF22242B);
  static const border = Color(0xFF2D2D33);
  static const borderStrong = Color(0xFF3F3F46);
  static const text = Color(0xFFFFFFFF);
  static const text2 = Color(0xFFA1A1AA);
  static const text3 = Color(0xFF6B6B75);
  static const accent = Color(0xFF16C8FF);
  static const focusBg = Color(0xFF123644);
  static const success = Color(0xFF11D080);
  static const danger = Color(0xFFF23F43);
  static const dangerBg = Color(0xFF3A1B1F);
  static const warn = Color(0xFFFFB454);
  static const ink = Color(0xFF0B0C0F);
}

/// 设计稿 1920×1080 参考像素 → 当前屏幕逻辑像素的换算。
///
/// 电视盒子通常输出 1080p / xhdpi(density 2)，此时逻辑尺寸约 960×540，
/// scale ≈ 0.5，设计稿的 24 px 字号正好落到 12 dp = 24 物理像素。
/// 720p / tvdpi 盒子同理按最小边等比换算，避免硬编码 dp 造成溢出。
class TvS {
  final double w;
  final double h;
  TvS(BoxConstraints c) : w = c.maxWidth, h = c.maxHeight;

  /// 供嵌在 Row / Column / GridView 里的子组件使用。
  /// 这些组件自身的 LayoutBuilder constraints 已被父级收紧，
  /// 若按自身尺寸算 scale，同一个「设计稿 1050px」会缩小一半以上。
  /// 统一回到屏幕尺寸，保证全屏只有一个缩放基准。
  factory TvS.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return TvS(BoxConstraints(maxWidth: size.width, maxHeight: size.height));
  }

  double get scale => math.min(w / 1920.0, h / 1080.0);

  /// 设计稿 px → 逻辑像素
  double p(double px) => px * scale;

  /// 安全区：四周 5% Overscan（1920×1080 → 1728×972）
  double get insetX => p(96);
  double get insetY => p(54);

  double f(double px) => p(px); // 字号同样按设计稿换算

  Radius r(double px) => Radius.circular(p(px));
  BorderRadius br(double px) => BorderRadius.circular(p(px));
}

/// 焦点三态：默认 / 焦点（4px 青蓝描边 + 背景提亮 + 放大）/ 按下
class TvFocusBox extends StatelessWidget {
  const TvFocusBox({
    Key? key,
    required this.focused,
    required this.child,
    this.onTap,
    this.baseColor = TvC.panel,
    this.radius = 10,
    this.padding,
    this.width,
    this.height,
    this.borderWidth = 1,
  }) : super(key: key);

  final bool focused;
  final Widget child;
  final VoidCallback? onTap;
  final Color baseColor;
  final double radius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    // 关键：用屏幕尺寸而非自身 LayoutBuilder 的约束做缩放，
    // 否则被 Column / Row 收紧约束后所有焦点框会等比缩小。
    final s = TvS.of(context);
    return AnimatedScale(
      scale: focused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 160),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width == null ? null : s.p(width!),
          height: height == null ? null : s.p(height!),
          padding: padding ?? EdgeInsets.all(s.p(22)),
          decoration: BoxDecoration(
            color: focused ? TvC.focusBg : baseColor,
            borderRadius: s.br(radius),
            border: Border.all(
              color: focused ? TvC.accent : TvC.border,
              width: focused ? s.p(4) : s.p(borderWidth),
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: TvC.accent.withOpacity(0.12),
                      blurRadius: s.p(16),
                      spreadRadius: s.p(4),
                    )
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 设计稿字号阶梯：64 / 48 / 36 / 30 / 24 px，最小 24 px
TextStyle tvText(
  BoxConstraints c,
  double px, {
  Color color = TvC.text,
  FontWeight weight = FontWeight.w400,
  bool numeric = false,
  double? lineHeight,
}) {
  final s = TvS(c);
  return TextStyle(
    fontSize: s.f(px),
    color: color,
    fontWeight: weight,
    height: lineHeight == null ? 1.2 : lineHeight / px,
    letterSpacing: numeric ? s.p(1) : 0,
  );
}
