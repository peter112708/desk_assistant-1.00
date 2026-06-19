// lib/pages/sticky_notes_page.dart
import 'dart:convert';
//import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =========================================================================
// 🧠 数据模型：便签
// =========================================================================
class StickyTab {
  final String id;
  String title;
  String content;
  int colorIndex;
  final DateTime createdAt;

  StickyTab({
    required this.id,
    required this.title,
    required this.content,
    this.colorIndex = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StickyTab.fromJson(Map<String, dynamic> json) => StickyTab(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        colorIndex: json['colorIndex'] ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

// =========================================================================
// 📑 便签管理页面（在应用内管理，弹窗吸附在真实桌面）
// =========================================================================
class StickyNotesPage extends StatefulWidget {
  final Color themeColor;

  const StickyNotesPage({super.key, required this.themeColor});

  @override
  State<StickyNotesPage> createState() => _StickyNotesPageState();
}

class _StickyNotesPageState extends State<StickyNotesPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  static const _channel = MethodChannel('sticky_notes');
  static const _eventChannel = BasicMessageChannel<String>(
      'sticky_notes_events', StringCodec());

  List<StickyTab> _tabs = [];

  // 🎨 六色
  static const List<Color> _tabColors = [
    Color(0xFFFFD166),
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFFE889BD),
    Color(0xFFF9C74F),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTabs();
    _listenNativeEvents();
  }

  @override
  void dispose() {
    _eventChannel.setMessageHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 监听应用生命周期：隐藏到托盘时，便签弹窗保留在桌面
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 不做任何事 — 弹窗是独立 Win32 窗口，不受 Flutter 生命周期影响
  }

  // 📥 从本地恢复
  Future<void> _loadTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonStrings =
          prefs.getStringList('saved_sticky_tabs');
      if (jsonStrings != null && jsonStrings.isNotEmpty) {
        final loaded = <StickyTab>[];
        for (var str in jsonStrings) {
          try {
            loaded.add(StickyTab.fromJson(jsonDecode(str)));
          } catch (_) {}
        }
        if (mounted) setState(() => _tabs = loaded);
        // 恢复所有弹窗到桌面
        _syncAllPopups();
      }
    } catch (e) {
      debugPrint("🚨 恢复便签失败: $e");
    }
  }

  // 💾 全量落盘
  Future<void> _saveTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStrings = _tabs.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('saved_sticky_tabs', jsonStrings);
    } catch (e) {
      debugPrint("🚨 保存便签失败: $e");
    }
  }

  // 🔄 同步所有弹窗到桌面
  Future<void> _syncAllPopups() async {
    // 先清理旧弹窗
    await _channel.invokeMethod('destroyAllPopups');
    // 重新创建
    for (int i = 0; i < _tabs.length; i++) {
      await _showPopup(_tabs[i], index: i);
    }
  }

  // 🪟 Create a single sticky popup on the desktop
  Future<void> _showPopup(StickyTab tab, {int index = 0}) async {
    double screenWidth = 1920;
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final view = dispatcher.views.first;
      screenWidth = view.physicalSize.width / view.devicePixelRatio;
    } catch (e) {
      debugPrint("Screen size detection failed: $e");
    }

    final x = (screenWidth - 280).toInt();
    final y = 60 + index * 50;

    try {
      await _channel.invokeMethod('createPopup', {
        'id': tab.id,
        'title': tab.title,
        'content': tab.content,
        'colorIndex': tab.colorIndex,
        'x': x.clamp(0, 3000),
        'y': y.clamp(0, 2000),
      });
      debugPrint("Popup created: ${tab.title} at ($x, $y)");
    } catch (e) {
      debugPrint("Popup creation failed: $e");
    }
  }

  // 🗑️ 从桌面销毁单个弹窗
  Future<void> _hidePopup(String id) async {
    try {
      await _channel.invokeMethod('destroyPopup', {'id': id});
    } catch (e) {
      debugPrint("🚨 销毁桌面弹窗失败: $e");
    }
  }

  // 👂 监听 native 端弹窗被用户右键删除的事件
  void _listenNativeEvents() {
    _eventChannel.setMessageHandler((String? message) {
      if (message == null) return Future<String>.value('');
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        if (data['method'] == 'popupDeleted') {
          final deletedId = data['id'] as String;
          debugPrint("🔄 Native 通知：便签 $deletedId 已被用户从桌面删除");
          // 同步删除数据
          setState(() {
            _tabs.removeWhere((t) => t.id == deletedId);
          });
          _saveTabs();
        }
      } catch (_) {}
      return Future<String>.value('');
    });
  }

  // ➕ 新建便签
  Future<void> _createTab() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    int selectedColor = DateTime.now().millisecondsSinceEpoch % _tabColors.length;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.92),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('📝 新建桌面便签',
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '便签标题...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF161626).withValues(alpha: 0.75),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '便签内容...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF161626).withValues(alpha: 0.75),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(_tabColors.length, (i) {
                        final selected = selectedColor == i;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = i),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: _tabColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: _tabColors[i]
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消',
                      style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.of(ctx).pop({
                      'title': title,
                      'content': contentController.text.trim(),
                      'colorIndex': selectedColor,
                    });
                  },
                  child: const Text('添加到桌面',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();

    if (result == null) return;

    final newTab = StickyTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: result['title'] as String,
      content: result['content'] as String,
      colorIndex: result['colorIndex'] as int,
      createdAt: DateTime.now(),
    );

    setState(() => _tabs.insert(0, newTab));
    await _saveTabs();
    await _syncAllPopups();
  }

  // Delete sticky (from manager)
  Future<void> _deleteTab(StickyTab tab) async {
    await _hidePopup(tab.id);
    setState(() => _tabs.removeWhere((t) => t.id == tab.id));
    await _saveTabs();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ================= 顶部标题栏 =================
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded,
                  color: widget.themeColor, size: 22),
              const SizedBox(width: 8),
              const Text('桌面便签',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_tabs.length} 枚已钉在桌面',
                    style: TextStyle(
                        color: widget.themeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createTab,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建便签'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),

          // ================= 便签管理列表 =================
          Expanded(
            child: _tabs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_outlined,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 12),
                        const Text(
                          '还没有桌面便签\n点击"新建便签"即可钉一枚到桌面上',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) {
                      return _buildManageRow(_tabs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ================= 管理列表行 =================
  Widget _buildManageRow(StickyTab tab) {
    final Color accent = _tabColors[tab.colorIndex % _tabColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tab.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                if (tab.content.isNotEmpty)
                  Text(tab.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          // Edit button
          _actionIcon(
            icon: Icons.edit_rounded,
            onTap: () => _editTab(tab),
          ),
          const SizedBox(width: 4),
          // Delete button
          _actionIcon(
            icon: Icons.delete_outline_rounded,
            color: Colors.redAccent,
            onTap: () => _confirmDelete(tab),
          ),
        ],
      ),
    );
  }

  // Edit sticky tab
  Future<void> _editTab(StickyTab tab) async {
    final titleController = TextEditingController(text: tab.title);
    final contentController = TextEditingController(text: tab.content);
    int selectedColor = tab.colorIndex;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.92),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('✏️ 编辑便签',
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '便签标题...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF161626).withValues(alpha: 0.75),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '便签内容...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF161626).withValues(alpha: 0.75),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(_tabColors.length, (i) {
                        final selected = selectedColor == i;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = i),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: _tabColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: _tabColors[i]
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消',
                      style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.of(ctx).pop({
                      'title': title,
                      'content': contentController.text.trim(),
                      'colorIndex': selectedColor,
                    });
                  },
                  child: const Text('保存',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();

    if (result == null) return;

    setState(() {
      tab.title = result['title'] as String;
      tab.content = result['content'] as String;
      tab.colorIndex = result['colorIndex'] as int;
    });
    await _saveTabs();
    await _syncAllPopups();
  }

  // Delete confirmation
  void _confirmDelete(StickyTab tab) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.92),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('确认删除',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除便签「${tab.title}」吗？\n桌面弹窗将同步消失，此操作不可恢复。',
          style: const TextStyle(color: Colors.white60, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _deleteTab(tab);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔘 操作图标
  Widget _actionIcon({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? Colors.white38;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: c),
      ),
    );
  }
}
