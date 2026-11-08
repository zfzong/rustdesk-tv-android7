// RustDesk TV · 主界面「连接到设备」（设计稿 B 板）
// 1920×1080 横屏、5% Overscan 安全区、D-pad 唯一焦点、一屏完成主流程。
// 真机数据来自官方模型：本机 ID / 一次性密码 / 服务状态 / 连接入口。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../models/platform_model.dart';
import 'tv_focus.dart';
import 'tv_keypad.dart';
import 'tv_settings_page.dart';
import 'tv_theme.dart';

class TvPeer {
  final String id;
  final String alias;
  const TvPeer({required this.id, required this.alias});
  Map<String, dynamic> toJson() => {'id': id, 'alias': alias};
  static TvPeer fromJson(Map<String, dynamic> m) =>
      TvPeer(id: (m['id'] ?? '').toString(), alias: (m['alias'] ?? '').toString());
}

class TvHomePage extends StatefulWidget {
  const TvHomePage({Key? key}) : super(key: key);

  @override
  State<TvHomePage> createState() => _TvHomePageState();
}

class _TvHomePageState extends State<TvHomePage> {
  static const _recentKey = 'tv-recent-peers';

  String _remoteId = '';
  List<TvPeer> _recent = [];
  int _focus = 0; // 0 ID / 1 连接 / 2 地址簿 / 3 设置 / 4+ 最近连接
  String? _toast;
  Timer? _tick;
  Timer? _toastTimer;
  bool _confirmExit = false;

  @override
  void initState() {
    super.initState();
    _load();
    // 本机 ID / 密码 / 服务状态由 Rust 侧异步刷新，这里做低频重绘
    _tick = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
    try {
      gFFI.serverModel.fetchID();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final last = await bind.mainGetLastRemoteId();
      if (last.isNotEmpty) _remoteId = last.replaceAll(RegExp(r'[^0-9]'), '');
    } catch (_) {}
    try {
      final raw = bind.mainGetLocalOption(key: _recentKey);
      if (raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _recent = list
            .whereType<Map<String, dynamic>>()
            .map(TvPeer.fromJson)
            .where((p) => p.id.isNotEmpty)
            .take(4)
            .toList();
      }
    } catch (_) {}
    if (_recent.isEmpty) {
      _recent = const [
        TvPeer(id: '', alias: '暂无最近连接'),
      ];
    }
    if (mounted) setState(() {});
  }

  void _saveRecent(String id) {
    final next = <TvPeer>[TvPeer(id: id, alias: '远程设备')];
    for (final p in _recent) {
      if (p.id.isNotEmpty && p.id != id && next.length < 4) next.add(p);
    }
    _recent = next;
    try {
      bind.mainSetLocalOption(
          key: _recentKey,
          value: jsonEncode(_recent.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _notify(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  String get _idPretty => _remoteId.isEmpty
      ? '— — —'
      : _remoteId.replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m[1]} ');

  String get _myId {
    try {
      return gFFI.serverModel.serverId.text.trim();
    } catch (_) {
      return '— — —';
    }
  }

  String get _myPassword {
    try {
      return gFFI.serverModel.serverPasswd.text.trim();
    } catch (_) {
      return '— — —';
    }
  }

  bool get _serviceStarted {
    try {
      return gFFI.serverModel.isStart;
    } catch (_) {
      return false;
    }
  }

  int get _focusCount => 4 + _recent.length;

  int _columnOf(int i) => i < 4 ? 0 : 1;

  void _moveVertical(int dir) {
    final col = _columnOf(_focus);
    final candidates = List<int>.generate(
        _focusCount, (i) => i).where((i) => _columnOf(i) == col).toList();
    if (candidates.isEmpty) return;
    final pos = candidates.indexOf(_focus);
    setState(() => _focus = candidates[(pos + dir + candidates.length) % candidates.length]);
  }

  void _moveHorizontal(int dir) {
    final col = _columnOf(_focus);
    final target = (col + dir).clamp(0, 1).toInt();
    if (target == col) return;
    if (target == 0) {
      setState(() => _focus = 0);
    } else {
      setState(() => _focus = _recent.isEmpty ? 3 : 4);
    }
  }

  Future<void> _openKeypad() async {
    final res = await Navigator.of(context).push<TvKeypadResult>(
      MaterialPageRoute(builder: (_) => TvKeypad(initial: _remoteId)),
    );
    if (res != null) {
      setState(() {
        _remoteId = res.id;
        _focus = 0;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TvSettingsPage()),
    );
    if (mounted) setState(() => _focus = 3);
  }

  void _connect([String? preset]) {
    final id = (preset ?? _remoteId).replaceAll(RegExp(r'[^0-9]'), '');
    if (id.isEmpty) {
      _notify('请先按 OK 输入远程 ID');
      setState(() => _focus = 0);
      return;
    }
    setState(() => _remoteId = id);
    _saveRecent(id);
    _notify('正在连接 $id …');
    // 官方连接入口：会拉起密码框并进入官方远程会话页
    connect(context, id);
  }

  void _activate(int i) {
    if (i == 0) {
      _openKeypad();
    } else if (i == 1) {
      _connect();
    } else if (i == 2) {
      // 设计稿：地址簿 → 焦点移至右栏「最近连接」
      setState(() => _focus = _recent.isEmpty ? 3 : 4);
      _notify('地址簿 → 最近连接');
    } else if (i == 3) {
      _openSettings();
    } else {
      final idx = i - 4;
      if (idx < _recent.length) {
        final p = _recent[idx];
        if (p.id.isEmpty) {
          _notify('暂无最近连接');
        } else {
          _connect(p.id);
        }
      }
    }
  }

  void _onBack() {
    if (_confirmExit) {
      SystemNavigator.pop();
      return;
    }
    _confirmExit = true;
    _notify('再按一次「返回」退出 RustDesk TV');
    Timer(const Duration(seconds: 3), () => _confirmExit = false);
  }

  void _onDigit(String d) {
    if (_remoteId.length >= 12) return;
    setState(() {
      _remoteId += d;
      _focus = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _onBack();
        return false;
      },
      child: TvDpad(
        onOk: () => _activate(_focus),
        onUp: () => _moveVertical(-1),
        onDown: () => _moveVertical(1),
        onLeft: () => _moveHorizontal(-1),
        onRight: () => _moveHorizontal(1),
        onBack: _onBack,
        onMenu: _openSettings,
        onDigit: _onDigit,
        child: Scaffold(
          backgroundColor: TvC.bg,
          body: LayoutBuilder(builder: (context, c) {
            final s = TvS(c);
            return Stack(
              children: [
                // ── 顶栏 ────────────────────────────────────────────
                Positioned(
                  left: s.insetX,
                  top: s.p(64),
                  width: s.p(1728),
                  height: s.p(80),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('RustDesk',
                          style: tvText(c, 40,
                              weight: FontWeight.w700, numeric: true)),
                      Text('电视盒子版 · 遥控器操作        ${_clock()}',
                          style: tvText(c, 26, color: TvC.text2)),
                    ],
                  ),
                ),
                Positioned(
                  left: s.insetX,
                  top: s.p(210),
                  width: s.p(1728),
                  height: s.p(2),
                  child: const ColoredBox(color: TvC.border),
                ),

                // ── 左栏：连接流程 ───────────────────────────────────
                Positioned(
                  left: s.insetX,
                  top: s.p(232),
                  width: s.p(1050),
                  height: s.p(710),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('连接到设备',
                          style: tvText(c, 48, weight: FontWeight.w700)),
                      SizedBox(height: s.p(10)),
                      Text('输入对方 ID，按 OK 键发起连接',
                          style: tvText(c, 28, color: TvC.text2)),
                      SizedBox(height: s.p(24)),
                      _idCard(c, s),
                      SizedBox(height: s.p(24)),
                      _connectButton(c, s),
                      SizedBox(height: s.p(24)),
                      _subRow(c, s),
                      SizedBox(height: s.p(20)),
                      Text('首次使用请先在「设置」中完成授权与自建服务器配置',
                          style: tvText(c, 24, color: TvC.warn)),
                    ],
                  ),
                ),

                // ── 右栏：本机信息 / 最近连接 ─────────────────────────
                Positioned(
                  left: s.p(1210),
                  top: s.p(232),
                  width: s.p(614),
                  height: s.p(710),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _myIdCard(c, s),
                      SizedBox(height: s.p(24)),
                      Text('最近连接',
                          style: tvText(c, 30, weight: FontWeight.w600)),
                      SizedBox(height: s.p(16)),
                      for (var i = 0; i < _recent.length; i++) ...[
                        _peerCard(c, s, i),
                        SizedBox(height: s.p(16)),
                      ],
                      const Spacer(),
                      _serverRow(c, s),
                    ],
                  ),
                ),

                // ── 底部按键提示 ─────────────────────────────────────
                Positioned(
                  left: s.insetX,
                  top: s.p(972),
                  width: s.p(1728),
                  child: TvKeyHints(items: const [
                    'OK   确认',
                    '返回   退出',
                    '菜单   设置',
                    '方向键   移动焦点',
                    '数字键   输入 ID',
                  ]),
                ),

                // ── Toast ────────────────────────────────────────────
                if (_toast != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: s.p(40),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: s.p(26), vertical: s.p(14)),
                        decoration: BoxDecoration(
                          color: const Color(0xEE123644),
                          borderRadius: s.br(10),
                          border: Border.all(color: TvC.accent, width: s.p(1)),
                        ),
                        child: Text(_toast!, style: tvText(c, 26)),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _idCard(BoxConstraints c, TvS s) {
    return TvFocusBox(
      focused: _focus == 0,
      width: 1050,
      height: 130,
      radius: 10,
      baseColor: TvC.panel,
      padding: EdgeInsets.symmetric(horizontal: s.p(32)),
      onTap: _openKeypad,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('远程 ID', style: tvText(c, 26, color: TvC.text2)),
          Text(_idPretty,
              style: tvText(c, 56,
                  weight: FontWeight.w700, numeric: true)),
          Text('OK 调出数字键盘', style: tvText(c, 22, color: TvC.accent)),
        ],
      ),
    );
  }

  Widget _connectButton(BoxConstraints c, TvS s) {
    return TvFocusBox(
      focused: _focus == 1,
      width: 420,
      height: 118,
      radius: 10,
      baseColor: TvC.accent,
      padding: EdgeInsets.zero,
      onTap: () => _connect(),
      child: Center(
        child: Text('连  接',
            style: tvText(c, 36,
                color: _focus == 1 ? TvC.text : TvC.ink,
                weight: FontWeight.w700)),
      ),
    );
  }

  Widget _subRow(BoxConstraints c, TvS s) {
    return Row(
      children: [
        TvFocusBox(
          focused: _focus == 2,
          width: 300,
          height: 96,
          radius: 10,
          baseColor: TvC.panel2,
          padding: EdgeInsets.zero,
          onTap: () => _activate(2),
          child: Center(
            child: Text('地址簿',
                style: tvText(c, 30, weight: FontWeight.w500)),
          ),
        ),
        SizedBox(width: s.p(24)),
        TvFocusBox(
          focused: _focus == 3,
          width: 300,
          height: 96,
          radius: 10,
          baseColor: TvC.panel2,
          padding: EdgeInsets.zero,
          onTap: _openSettings,
          child: Center(
            child: Text('设  置',
                style: tvText(c, 30, weight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _myIdCard(BoxConstraints c, TvS s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(s.p(30)),
      decoration: BoxDecoration(
        color: TvC.panel,
        borderRadius: s.br(10),
        border: Border.all(color: TvC.border, width: s.p(1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本机 ID（可被控）', style: tvText(c, 24, color: TvC.text2)),
          SizedBox(height: s.p(10)),
          Text(_myId.isEmpty ? '— — —' : _myId,
              style: tvText(c, 56, weight: FontWeight.w700, numeric: true)),
          SizedBox(height: s.p(10)),
          Text('密码   ${_myPassword.isEmpty ? '— — —' : _myPassword}',
              style: tvText(c, 26,
                  color: TvC.accent, weight: FontWeight.w600, numeric: true)),
          SizedBox(height: s.p(10)),
          Text(
            _serviceStarted ? '共享屏幕服务已开启' : '共享屏幕服务未开启 · 请先在设置中授权',
            style: tvText(c, 22,
                color: _serviceStarted ? TvC.success : TvC.warn),
          ),
        ],
      ),
    );
  }

  Widget _peerCard(BoxConstraints c, TvS s, int i) {
    final p = _recent[i];
    return TvFocusBox(
      focused: _focus == 4 + i,
      width: 614,
      height: 110,
      radius: 10,
      baseColor: TvC.panel,
      padding: EdgeInsets.all(s.p(24)),
      onTap: () => _activate(4 + i),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(p.alias,
              style: tvText(c, 28,
                  weight: _focus == 4 + i
                      ? FontWeight.w700
                      : FontWeight.w500)),
          SizedBox(height: s.p(6)),
          Text(p.id.isEmpty ? '按 OK 输入对方 ID 后会记录在这里' : 'ID  ${p.id}   ·   按 OK 连接',
              style: tvText(c, 22, color: TvC.text2, numeric: true)),
        ],
      ),
    );
  }

  Widget _serverRow(BoxConstraints c, TvS s) {
    return Container(
      width: double.infinity,
      height: s.p(88),
      padding: EdgeInsets.symmetric(horizontal: s.p(24)),
      decoration: BoxDecoration(
        color: TvC.panel,
        borderRadius: s.br(10),
        border: Border.all(color: TvC.border, width: s.p(1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('中继服务器', style: tvText(c, 26, color: TvC.text2)),
          Text('公共 / 自建', style: tvText(c, 26, color: TvC.success)),
        ],
      ),
    );
  }

  String _clock() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
}
