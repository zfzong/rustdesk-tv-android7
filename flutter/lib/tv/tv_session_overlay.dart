// RustDesk TV · 远程会话 HUD（设计稿 C 板）
//
// 这是「可叠加组件」，不是独立页面：真实远程画面仍由官方 RemotePage 渲染。
// 挂载方式见 TV_BUILD.md「可选：会话中 HUD」一节 —— 在远程页 Stack 顶部
// 放一层 TvSessionOverlay 即可，默认不启用，不影响原有连接功能。
import 'package:flutter/material.dart';

import 'tv_focus.dart';
import 'tv_theme.dart';

class TvSessionOverlay extends StatefulWidget {
  const TvSessionOverlay({
    Key? key,
    required this.peerName,
    required this.onDisconnect,
    this.resolution = '1080P',
    this.latency = '— ms',
  }) : super(key: key);

  final String peerName;
  final VoidCallback onDisconnect;
  final String resolution;
  final String latency;

  @override
  State<TvSessionOverlay> createState() => _TvSessionOverlayState();
}

class _TvSessionOverlayState extends State<TvSessionOverlay> {
  int _focus = 0; // 0 断开连接

  @override
  Widget build(BuildContext context) {
    return TvDpad(
      onOk: widget.onDisconnect,
      onUp: () => setState(() => _focus = 0),
      onDown: () => setState(() => _focus = 0),
      onLeft: () => setState(() => _focus = 0),
      onRight: () => setState(() => _focus = 0),
      onBack: widget.onDisconnect,
      child: LayoutBuilder(builder: (context, c) {
        final s = TvS(c);
        return Stack(children: [
          // 顶部状态条
          Positioned(
            left: s.insetX,
            top: s.p(54),
            width: s.p(1728),
            height: s.p(96),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: s.p(28)),
              decoration: BoxDecoration(
                color: TvC.panel,
                borderRadius: s.br(12),
                border: Border.all(color: TvC.border, width: s.p(1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.peerName}   ·   已连接',
                      style: tvText(c, 32, weight: FontWeight.w700)),
                  Text('${widget.resolution}   ·   ${widget.latency}   ·   硬件解码',
                      style: tvText(c, 24,
                          color: TvC.success, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // 中央按键提示
          Positioned(
            left: s.p(880),
            top: s.p(676),
            width: s.p(560),
            height: s.p(64),
            child: Container(
              decoration: BoxDecoration(
                color: TvC.panel,
                borderRadius: s.br(8),
                border: Border.all(color: TvC.border, width: s.p(1)),
              ),
              child: Center(
                child: Text('方向键移动光标     OK 左键',
                    style: tvText(c, 24, weight: FontWeight.w500)),
              ),
            ),
          ),
          // 底部工具栏
          Positioned(
            left: s.insetX,
            top: s.p(886),
            width: s.p(1728),
            height: s.p(140),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: s.p(32)),
              decoration: BoxDecoration(
                color: TvC.panel,
                borderRadius: s.br(12),
                border: Border.all(color: TvC.border, width: s.p(1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('OK  左键', style: tvText(c, 25, color: TvC.text2)),
                      SizedBox(width: s.p(36)),
                      Text('返回  右键', style: tvText(c, 25, color: TvC.text2)),
                      SizedBox(width: s.p(36)),
                      Text('菜单  工具栏', style: tvText(c, 25, color: TvC.text2)),
                      SizedBox(width: s.p(36)),
                      Text('长按 OK  拖动', style: tvText(c, 25, color: TvC.text2)),
                    ],
                  ),
                  TvFocusBox(
                    focused: _focus == 0,
                    width: 300,
                    height: 84,
                    radius: 10,
                    baseColor: TvC.dangerBg,
                    borderWidth: 3,
                    padding: EdgeInsets.zero,
                    onTap: widget.onDisconnect,
                    child: Center(
                      child: Text('断开连接',
                          style: tvText(c, 28,
                              color: TvC.danger, weight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
