// lib/pages/notes_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =========================================================================
// 🧠 数据模型：纯 Dart 轻量级笔记结构体
// =========================================================================
class Note {
  final String id;
  String title;
  String content;
  int colorIndex; // 预设颜色索引 0~5
  final DateTime createdAt;

  Note({
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

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        colorIndex: json['colorIndex'] ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

// =========================================================================
// 🎨 笔记主页面组件
// =========================================================================
class NotesPage extends StatefulWidget {
  final Color themeColor;

  const NotesPage({super.key, required this.themeColor});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Note> _notes = [];

  // 🎨 六色便签纸经典色系，在暗色背景下温润不刺眼
  static const List<Color> _noteColors = [
    Color(0xFFFFD166), // 暖黄
    Color(0xFFEF476F), // 珊瑚粉
    Color(0xFF06D6A0), // 薄荷绿
    Color(0xFF118AB2), // 深海蓝
    Color(0xFFE889BD), // 丁香紫
    Color(0xFFF9C74F), // 金盏橙
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // 📥 从本地硬件落盘恢复笔记
  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonStrings = prefs.getStringList('saved_notes');
      if (jsonStrings != null && jsonStrings.isNotEmpty) {
        final loaded = <Note>[];
        for (var str in jsonStrings) {
          try {
            loaded.add(Note.fromJson(jsonDecode(str)));
          } catch (_) {}
        }
        if (mounted) setState(() => _notes = loaded);
      }
    } catch (e) {
      debugPrint("🚨 恢复笔记失败: $e");
    }
  }

  // 💾 全量落盘所有笔记
  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStrings = _notes.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList('saved_notes', jsonStrings);
    } catch (e) {
      debugPrint("🚨 保存笔记失败: $e");
    }
  }

  // ✏️ 弹出新建 / 编辑对话框
  Future<void> _openNoteEditor({Note? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    int selectedColor =
        existing?.colorIndex ?? (DateTime.now().millisecondsSinceEpoch % _noteColors.length);

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
              title: Text(
                existing != null ? '✏️ 编辑笔记' : '📝 新建笔记',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '笔记标题...',
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
                    // 正文
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '写点什么...',
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
                    // 🎨 颜色选择条
                    Row(
                      children: List.generate(_noteColors.length, (i) {
                        final isSelected = selectedColor == i;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = i),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: _noteColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: _noteColors[i]
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
                    if (title.isEmpty) return; // 标题不许空
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
      if (existing != null) {
        existing.title = result['title'] as String;
        existing.content = result['content'] as String;
        existing.colorIndex = result['colorIndex'] as int;
      } else {
        _notes.insert(
          0,
          Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: result['title'] as String,
            content: result['content'] as String,
            colorIndex: result['colorIndex'] as int,
            createdAt: DateTime.now(),
          ),
        );
      }
    });
    await _saveNotes();
  }

  // 🗑️ 删除笔记
  Future<void> _deleteNote(Note note) async {
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    await _saveNotes();
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
              Icon(Icons.note_alt_rounded,
                  color: widget.themeColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                '我的笔记',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // 计数
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_notes.length} 篇',
                  style: TextStyle(
                      color: widget.themeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              // ➕ 新建按钮
              ElevatedButton.icon(
                onPressed: () => _openNoteEditor(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建笔记'),
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

          // ================= 笔记网格区 =================
          Expanded(
            child: _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_alt_outlined,
                            size: 56, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 12),
                        const Text(
                          '还没有笔记，点击上方按钮创建一篇吧~',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(top: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) =>
                        _buildNoteCard(_notes[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // ================= 🃏 单篇笔记卡片 =================
  Widget _buildNoteCard(Note note) {
    final Color bg = _noteColors[note.colorIndex % _noteColors.length];

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.10),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 主内容区
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      note.content,
                      style: const TextStyle(
                        color: Color(0xFF2D2D44),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatDate(note.createdAt),
                      style: TextStyle(
                        color: const Color(0xFF1A1A2E).withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔘 悬浮操作按钮组
            Positioned(
              top: 2,
              right: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniIconButton(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
                    onTap: () => _openNoteEditor(existing: note),
                  ),
                  _miniIconButton(
                    icon: Icons.close_rounded,
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.92),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          title: const Text('确认删除',
                              style: TextStyle(color: Colors.white)),
                          content: Text(
                            '确定要删除笔记「${note.title}」吗？此操作不可恢复。',
                            style: const TextStyle(color: Colors.white60),
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
                                _deleteNote(note);
                                Navigator.of(ctx).pop();
                              },
                              child: const Text('删除',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
