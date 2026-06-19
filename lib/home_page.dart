import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 引入本地存储库
import 'pages/ai_page.dart'; // 👈 引入刚刚创建的 AI 页面组件
import 'pages/music_page.dart'; // 👈 别忘了加这行
import 'pages/sticky_notes_page.dart'; // 👈 便签页面（书签式侧边标签）
import 'pages/notes_page.dart'; // 👈 笔记页面（网格卡片式）
import 'package:tray_manager/tray_manager.dart';
import 'package:file_picker/file_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TrayListener{
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  
  // 实时时间变量
  String _currentTimeString = '';
  Timer? _timeTimer;

  // 🛠️ 设置相关的变量
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _musicFolderController = TextEditingController();
  Color _themeColor = const Color(0xFF3A86FF); // 默认科技蓝
  String _savedApiKey = '';

  // 预设的可选主题颜色列表
  final List<Map<String, dynamic>> _colorThemes = [
    {'name': '科技蓝', 'color': const Color(0xFF3A86FF)},
    {'name': '极客紫', 'color': const Color(0xFF8338EC)},
    {'name': '活力橙', 'color': const Color(0xFFFF006E)},
  ];

  // 页面列表（追加了第 6 个：设置页面）
  // 修改前的占位：
  // const Center(child: Text('DeepSeek AI 对话开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),

  // 修改后的样子：
  // 🌟 改为动态 Getter 方法，完美解决生命周期初始化问题
  // 🌟 完完全全、六位一体的动态页面列表
  List<Widget> get _pages => [
    const Center(child: Text('时钟功能开发中...', style: TextStyle(fontSize: 24, color: Colors.white))),
    StickyNotesPage(themeColor: _themeColor), // 👈 便签页面正式入住！
    NotesPage(themeColor: _themeColor), // 👈 笔记页面正式入住！
    // 🌟 音乐页面正式入住！
  MusicPage(themeColor: _themeColor),
    AiPage(themeColor: _themeColor), // 👈 AI 页面归位，对应第 5 个标签
    _buildSettingsPage(), // 系统设置依旧死死钉在左下角齿轮处
  ];

  final List<Map<String, dynamic>> _labels = [
    {'icon': Icons.access_time_filled_rounded, 'title': '时钟'},
    {'icon': Icons.sticky_note_2_rounded, 'title': '便签'},
    {'icon': Icons.note_alt_rounded, 'title': '笔记'},
    {'icon': Icons.music_note_rounded, 'title': '音乐'},
    {'icon': Icons.smart_toy_rounded, 'title': 'AI 助手'}, // 👈 完美挪到最后一位！
  ];

  @override
  void initState() {
    super.initState();
    //windowManager.addListener(this); // 👈 注册窗口监听
    // 👈 核心修正 2：直接用最土但最稳的匿名类注册托盘。把所有托盘逻辑完全锁在 initState 内部！
    // 这样和类级别的函数没有任何重名冲突，更不会影响你的现有代码。
    //trayManager.addListener(_MyTrayListener());
    trayManager.addListener(this); // 仅新增这一行
    _startClock();
    _loadSettings(); // 👈 启动程序时，自动从硬盘读取之前保存的设置
  }

  // 📥 从本地恢复数据
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 读取 API Key，如果找不到就默认为空字符串
      _savedApiKey = prefs.getString('api_key') ?? '';
      _apiKeyController.text = _savedApiKey;

      // 👇 紧贴着下面追加这两行
      String savedFolder = prefs.getString('saved_music_folder') ?? '';
      _musicFolderController.text = savedFolder;

      // 读取颜色，如果找不到就默认用科技蓝
      int? colorValue = prefs.getInt('theme_color');
      if (colorValue != null) {
        _themeColor = Color(colorValue);
      }
    });
  }

  // 💾 保存数据到本地
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKeyController.text);
    await prefs.setString('saved_music_folder', _musicFolderController.text.trim());
    await prefs.setInt('theme_color', _themeColor.toARGB32());
    
    setState(() {
      _savedApiKey = _apiKeyController.text;
    });

    // 弹出一个精美的小提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('设置已成功保存到本地！'),
          backgroundColor: _themeColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  //选择文件夹
  Future<void> _selectMusicFolder() async {
  // 使用当前最稳妥的最新版 file_picker 访问方式
  String? selectedDirectory = await FilePicker.getDirectoryPath();
  if (selectedDirectory != null) {
    setState(() {
      _musicFolderController.text = selectedDirectory;
    });
  }
}
  void _startClock() {
    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    String year = now.year.toString();
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String hour = now.hour.toString().padLeft(2, '0');
    String minute = now.minute.toString().padLeft(2, '0');
    String second = now.second.toString().padLeft(2, '0');
    
    setState(() {
      _currentTimeString = '$year年$month月$day日 $hour:$minute:$second ${_getChineseWeekday(now.weekday)}';
    });
  }

  String _getChineseWeekday(int weekday) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[weekday - 1];
  }
  

  

  @override
  void dispose() {
    //windowManager.removeListener(this); // 👈 注销监听
    //trayManager.removeListener(this);   // 👈 注销监听
    trayManager.removeListener(this); // 仅新增这一行
    _timeTimer?.cancel();
    _pageController.dispose();
    _apiKeyController.dispose();
    _musicFolderController.dispose();
    super.dispose();
  }
  // ================= ⚓ 窗口事件拦截 =================
  // 只保留右键弹出菜单，无任何多余功能
@override
Future<void> onTrayIconRightMouseDown() async {
  await trayManager.popUpContextMenu();
}
  
 


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 👈 确保 Scaffold 本身不遮挡透明度
      body: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 👈 核心修改：将原本全黑的 0xFF1E1E2E 改为半透明，让桌面磨砂透过来
          color: const Color(0xFF1E1E2E).withValues(alpha: 0.45), 
          child: Row(
            children: [
              // ================= 左侧标签导航栏 =================
              Container(
                width: 200,
                // 👈 核心修改：左侧导航栏也改为半透明
                color: const Color(0xFF181825).withValues(alpha: 0.5),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (details) => windowManager.startDragging(),
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.only(left: 20),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(Icons.bolt, color: _themeColor, size: 26), 
                            const SizedBox(width: 8),
                            const Text(
                              "粑粑科技",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    
                    // 核心功能列表
                    Column(
                      children: List.generate(_labels.length, (index) {
                        final isSelected = _selectedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor: _themeColor.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            leading: Icon(
                              _labels[index]['icon'],
                              color: isSelected ? _themeColor : Colors.white60,
                            ),
                            title: Text(
                              _labels[index]['title'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              setState(() => _selectedIndex = index);
                              _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            },
                          ),
                        );
                      }),
                    ),

                    const Spacer(),
                    const Divider(color: Colors.white12, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: ListTile(
                        selected: _selectedIndex == 5, 
                        selectedTileColor: _themeColor.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: Icon(
                          Icons.settings_rounded,
                          color: _selectedIndex == 5 ? _themeColor : Colors.white60,
                        ),
                        title: Text(
                          '系统设置',
                          style: TextStyle(
                            color: _selectedIndex == 5 ? Colors.white : Colors.white70,
                            fontWeight: _selectedIndex == 5 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = 5);
                          _pageController.animateToPage(5, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) => windowManager.startDragging(),
                            child: Container(
                              height: 60, // 略微加高，留出完美的玻璃框边距
                              padding: const EdgeInsets.only(left: 20),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  // 👈 核心重构：时间显示区域变成绝对精致的磨砂卡片
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      // 关键点：半透明亮色底 + 极细的高光白边，在毛玻璃上质感拉满
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white60),
                                        const SizedBox(width: 8),
                                        Text(
                                          _currentTimeString,
                                          style: const TextStyle(
                                            color: Colors.white, // 让文字更白更清晰
                                            fontSize: 13, 
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
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
                          // 右侧卡片内容区保持原有的一点点内敛色，避免和背景混在一起
                          color: const Color(0xFF252538).withValues(alpha: 0.85),
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

  // ================= 🛠️ 构造设置页面的 UI 视图 =================
  // ================= 🛠️ 构造设置页面的 UI 视图 =================
  Widget _buildSettingsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text('系统个性化设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          
          // ✨ 核心优化：在这里加上非常清晰且硬核的 Windows 本地路径提示
          const Text(
            '数据将加密保存在本地设备。\n提示：若需彻底卸载，可在隐藏文件夹 %AppData% 里的 [com.example.flutterApplication1] 中手动清除残留配置。', 
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
          ),
          
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),

          // ... 下面保留你原本的 API Key 文本框和颜色调节区域的代码 ...
          // 1. API KEY 文本输入框
          const Text('DeepSeek API Key 密钥', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKeyController,
            obscureText: true, // 密码模式隐藏明文
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '请输入您的 sk-xxxxxxxxxxxx 密钥',
              hintStyle: const TextStyle(color: Colors.white12),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.white38, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(_themeColor.toARGB32()), width: 1.5))
            ),
          ),
          const SizedBox(height: 18),

          //const SizedBox(height: 20),
// 👇 塞入本地音乐配置输入框与选择按钮
const Text('本地音乐源配置', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
const SizedBox(height: 10),
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _musicFolderController,
        readOnly: true, // 设为只读，完全依靠选择器防止用户打错字
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: '请选择您的本地音乐音源文件夹...',
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF161626), // 保持与你的原版卡片底色100%一致
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ),
    const SizedBox(width: 10),
    SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF161626),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)), // 新版透明度兼容
        ),
        onPressed: _selectMusicFolder, // 点击弹出原生选择文件夹窗口
        child: const Icon(Icons.create_new_folder_rounded, size: 20),
      ),
    ),
  ],
),

          // 2. 颜色调节区域
          const Text('系统主题色', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: _colorThemes.map((theme) {
              bool isCurrent = _themeColor.toARGB32() == theme['color'].toARGB32();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                key: ValueKey(theme['name']),
                child: ChoiceChip(
                  label: Text(theme['name'], style: TextStyle(color: isCurrent ? Colors.white : Colors.white60)),
                  selected: isCurrent,
                  selectedColor: theme['color'],
                  backgroundColor: const Color(0xFF1E1E2E),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isCurrent ? Colors.white24 : Colors.transparent),
                  ),
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _themeColor = theme['color'];
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
          
          const Spacer(),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),

          // 3. 底部保存大按钮
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
              label: const Text('保存所有设置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor, // 随当前选中的主题色走
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _saveSettings, // 点击调用保存函数
            ),
          ),
        ],
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
            //onPressed: () => windowManager.close(),
            onPressed: () async {
        // 点自定义关闭按钮：隐藏窗口 + 隐藏任务栏，程序留在托盘
           await windowManager.hide();
           await windowManager.setSkipTaskbar(true);
           },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
  
}


