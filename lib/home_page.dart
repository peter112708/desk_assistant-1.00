import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  
  // 用于更新顶部的实时时间
  String _currentTimeString = '';
  Timer? _timeTimer;

  final List<Widget> _pages = [
    const Center(child: Text('时钟功能开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),
    const Center(child: Text('便签功能开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),
    const Center(child: Text('笔记功能开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),
    const Center(child: Text('DeepSeek AI 对话开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),
    const Center(child: Text('爬虫音乐播放器开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),
  ];

  final List<Map<String, dynamic>> _labels = [
    {'icon': Icons.access_time_filled_rounded, 'title': '时钟'},
    {'icon': Icons.sticky_note_2_rounded, 'title': '便签'},
    {'icon': Icons.note_alt_rounded, 'title': '笔记'},
    {'icon': Icons.smart_toy_rounded, 'title': 'AI 助手'},
    {'icon': Icons.music_note_rounded, 'title': '音乐'},
  ];

  @override
  void initState() {
    super.initState();
    _startClock(); // 启动程序时开启时钟监听
  }

  // 每秒获取一次最新时间
  void _startClock() {
    _updateTime(); // 先初始化获取一次
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  // ✨ 纯原生 Dart 格式化时间，再也不需要 intl 库了！
  void _updateTime() {
    final DateTime now = DateTime.now();
    
    // 手动给个位数补零 (例如: 5月 变成 05月)
    String year = now.year.toString();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String hour = now.hour.toString().padLeft(2, '0');
    String minute = now.minute.toString().padLeft(2, '0');
    String second = now.second.toString().padLeft(2, '0');
    
    // 拼接成：2026年05月28日 14:30:05 星期四
    final String formatted = '$year年$month月$day日 $hour:$minute:$second ${_getChineseWeekday(now.weekday)}';
    
    setState(() {
      _currentTimeString = formatted;
    });
  }

  // 简易的星期转换器
  String _getChineseWeekday(int weekday) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[weekday - 1];
  }

  @override
  void dispose() {
    _timeTimer?.cancel(); // 销毁定时器
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFF1E1E2E),
          child: Row(
            children: [
              // ================= 左侧标签导航栏 =================
              Container(
                width: 200,
                color: const Color(0xFF181825),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (details) => windowManager.startDragging(),
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.only(left: 20),
                        alignment: Alignment.centerLeft,
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.blueAccent, size: 26),
                            SizedBox(width: 8),
                            Text(
                              '极简助手',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _labels.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.blueAccent.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(
                                _labels[index]['icon'],
                                color: isSelected ? Colors.blueAccent : Colors.white60,
                              ),
                              title: Text(
                                _labels[index]['title'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ================= 右侧主内容及窗口控制区 =================
              Expanded(
                child: Column(
                  children: [
                    // 右侧顶部：实时时间显示 + 窗口拖动区 + 右上角控制按钮
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) => windowManager.startDragging(),
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.only(left: 20),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white38),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentTimeString,
                                    style: const TextStyle(
                                      color: Colors.white70, 
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'monospace', 
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildRightTopControls(),
                      ],
                    ),
                    
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 0, right: 16, bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252538),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: _pages,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightTopControls() {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white60, size: 18),
            hoverColor: Colors.white12,
            onPressed: () => windowManager.minimize(),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white60, size: 18),
            hoverColor: Colors.redAccent.withValues(alpha: 0.8),
            onPressed: () => windowManager.close(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}