// RustDesk TV · 遥控器数字键盘
// 电视盒子没有触屏输入法；远程 ID 全部由遥控器数字键录入。
// 支持两种输入方式：直接按数字键，或用方向键在九宫格上移动 + OK 选中。
import 'package:flutter/material.dart';

import 'tv_focus.dart';
import 'tv_theme.dart';

class TvKeypadResult {
  final String id;
  const TvKeypadResult(this.id);
}

class TvKeypad extends StatefulWidget {
  const TvKeypad({Key? key, required this.initial}) : super(key: key);
  final String initial;

  @override
  State<TvKeypad> createState() => _TvKeypadState();
}

class _TvKeypadState extends State<TvKeypad> {
  late String _raw;
  int _focus = 0; // 0..9 数字, 10 删除, 11 清空, 12 确定, 13 取消

  @override
  void initState() {
    super.initState();
    _raw = widget.initial.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String get _pretty => _raw.isEmpty
      ? '—'
      : _raw.replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m[1]} ');

  void _push(String d) {
    if (_raw.length >= 12) return;
    setState(() => _raw += d);
  }

  void _del() {
    if (_raw.isEmpty) return;
    setState(() => _raw = _raw.substring(0, _raw.length - 1));
  }

  void _activate(int i) {
    if (i <= 9) {
      _push('$i');
    } else {
      switch (i) {
        case 10:
          _del();
          break;
        case 11:
          setState(() => _raw = '');
          break;
        case 12:
          Navigator.of(context).pop(TvKeypadResult(_raw));
          break;
        case 13:
          Navigator.of(context).pop();
          break;
      }
    }
  }

  void _move(int delta) {
    setState(() => _focus = (_focus + delta + 14) % 14);
  }

  @override
  Widget build(BuildContext context) {
    return TvDpad(
      onOk: () => _activate(_focus),
      onUp: () => _move(_focus >= 10 ? -4 : -3),
      onDown: () => _move(_focus >= 10 ? 4 : 3),
      onLeft: () => _move(-1),
      onRight: () => _move(1),
      onBack: () => Navigator.of(context).pop(),
      onDigit: _push,
      child: Scaffold(
        backgroundColor: TvC.bgSession,
        body: LayoutBuilder(builder: (context, c) {
          final s = TvS(c);
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: s.insetX + s.p(200), vertical: s.insetY + s.p(40)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('输入远程 ID', style: tvText(c, 48, weight: FontWeight.w700)),
                SizedBox(height: s.p(12)),
                Text('直接按遥控器数字键，或方向键选择后按 OK',
                    style: tvText(c, 28, color: TvC.text2)),
                SizedBox(height: s.p(28)),
                Container(
                  width: double.infinity,
                  height: s.p(130),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: s.p(32)),
                  decoration: BoxDecoration(
                    color: TvC.focusBg,
                    borderRadius: s.br(10),
                    border: Border.all(color: TvC.accent, width: s.p(4)),
                  ),
                  child: Text(
                    _pretty,
                    style: tvText(c, 56,
                        color: TvC.text,
                        weight: FontWeight.w700,
                        numeric: true),
                  ),
                ),
                SizedBox(height: s.p(32)),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 12,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, childAspectRatio: 2.1),
                          itemBuilder: (context, i) {
                            final label = i == 9 ? '删除' : i == 10 ? '清空' : i == 11 ? '0' : '${i + 1}';
                            final idx = i == 9 ? 10 : i == 10 ? 11 : i == 11 ? 0 : i + 1;
                            return Padding(
                              padding: EdgeInsets.all(s.p(8)),
                              child: TvFocusBox(
                                focused: _focus == idx,
                                radius: 10,
                                baseColor: TvC.panel2,
                                padding: EdgeInsets.zero,
                                onTap: () => _activate(idx),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: tvText(c, 36,
                                        color: _focus == idx ? TvC.text : TvC.text2,
                                        weight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: s.p(24)),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(s.p(8)),
                                child: TvFocusBox(
                                  focused: _focus == 12,
                                  radius: 10,
                                  baseColor: TvC.accent,
                                  padding: EdgeInsets.zero,
                                  onTap: () => _activate(12),
                                  child: Center(
                                    child: Text('确 定',
                                        style: tvText(c, 36,
                                            color: TvC.ink,
                                            weight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(s.p(8)),
                                child: TvFocusBox(
                                  focused: _focus == 13,
                                  radius: 10,
                                  baseColor: TvC.panel2,
                                  padding: EdgeInsets.zero,
                                  onTap: () => _activate(13),
                                  child: Center(
                                    child: Text('取 消',
                                        style: tvText(c, 32,
                                            color: TvC.text2,
                                            weight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
