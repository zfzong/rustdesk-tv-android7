// RustDesk TV · 遥控器交互与首次配置（设计稿 D 板）
// 系统授权弹窗在 Android TV 上遥控器点不到，必须在装机时用 ADB 一次做完，
// 这里把四步和按键映射常驻显示，避免装机人员另找文档。
import 'package:flutter/material.dart';

import '../mobile/pages/settings_page.dart';
import 'tv_focus.dart';
import 'tv_theme.dart';

class TvSettingsPage extends StatefulWidget {
  const TvSettingsPage({Key? key}) : super(key: key);

  @override
  State<TvSettingsPage> createState() => _TvSettingsPageState();
}

class _TvSettingsPageState extends State<TvSettingsPage> {
  int _focus = 0; // 0 官方设置 / 1 返回主页

  void _activate(int i) {
    if (i == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SettingsPage()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvDpad(
      onOk: () => _activate(_focus),
      onUp: () => setState(() => _focus = 0),
      onDown: () => setState(() => _focus = 1),
      onLeft: () => setState(() => _focus = 0),
      onRight: () => setState(() => _focus = 1),
      onBack: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: TvC.bg,
        body: LayoutBuilder(builder: (context, c) {
          final s = TvS(c);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: s.insetX, vertical: s.p(40)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('遥控器交互与首次配置',
                    style: tvText(c, 52, weight: FontWeight.w700)),
                SizedBox(height: s.p(10)),
                Text('D-pad 按键映射    焦点移动顺序    官方 APK 在电视盒子的落地步骤',
                    style: tvText(c, 26, color: TvC.text2)),
                SizedBox(height: s.p(24)),
                Container(height: s.p(2), width: s.p(1728), color: TvC.border),
                SizedBox(height: s.p(28)),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _card(c, s, '遥控器按键映射', const [
                        '方向键   移动焦点 / 会话中移动虚拟光标',
                        'OK   确认 / 左键 / 长按进入拖动',
                        '返回   退出 / 右键 / 关闭浮层',
                        '菜单   呼出本页与设置入口',
                        '数字键   直接录入远程 ID',
                      ])),
                      SizedBox(width: s.p(24)),
                      Expanded(child: _card(c, s, '首次配置四步（装机时一次完成）', const [
                        '1   ADB 安装 APK 并首次启动',
                        '2   ADB 开启无障碍服务「RustDesk Input」',
                        '3   ADB 授权屏幕录制 MediaProjection',
                        '4   关闭电池优化，配置自建 ID / Key 服务器',
                        '系统授权弹窗遥控器点不了，以上须借 ADB 完成',
                      ])),
                      SizedBox(width: s.p(24)),
                      Expanded(child: _card(c, s, 'TV 版落地清单', const [
                        '架构：armv7 优先，64 位盒子用 arm64',
                        '系统：Android 7 / API 24-25，minSdk 22 已兼容',
                        '方向：Manifest 锁定横屏 + 沉浸式全屏',
                        '入口：已补 LEANBACK_LAUNCHER，桌面可见图标',
                        '签名：自建构建为 debug 签名，与官方包二选一',
                        '升级：自建包不会自动更新，需重新构建',
                      ])),
                    ],
                  ),
                ),
                SizedBox(height: s.p(24)),
                Row(
                  children: [
                    TvFocusBox(
                      focused: _focus == 0,
                      width: 420,
                      height: 96,
                      radius: 10,
                      baseColor: TvC.accent,
                      padding: EdgeInsets.zero,
                      onTap: () => _activate(0),
                      child: Center(
                        child: Text('打开官方设置',
                            style: tvText(c, 30,
                                color: _focus == 0 ? TvC.text : TvC.ink,
                                weight: FontWeight.w700)),
                      ),
                    ),
                    SizedBox(width: s.p(24)),
                    TvFocusBox(
                      focused: _focus == 1,
                      width: 300,
                      height: 96,
                      radius: 10,
                      baseColor: TvC.panel2,
                      padding: EdgeInsets.zero,
                      onTap: () => _activate(1),
                      child: Center(
                        child: Text('返回主页',
                            style: tvText(c, 30, weight: FontWeight.w500)),
                      ),
                    ),
                    const Spacer(),
                    Text('自建服务器 ID / Key 请在「官方设置」中填写，或用 ADB 预置配置',
                        style: tvText(c, 22, color: TvC.text3)),
                  ],
                ),
                SizedBox(height: s.p(16)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _card(BoxConstraints c, TvS s, String title, List<String> lines) {
    return Container(
      padding: EdgeInsets.all(s.p(24)),
      decoration: BoxDecoration(
        color: TvC.panel,
        borderRadius: s.br(10),
        border: Border.all(color: TvC.border, width: s.p(1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tvText(c, 27, weight: FontWeight.w600)),
          SizedBox(height: s.p(16)),
          for (final line in lines) ...[
            Text(line, style: tvText(c, 22, color: TvC.text2, lineHeight: 34)),
            SizedBox(height: s.p(8)),
          ],
        ],
      ),
    );
  }
}
