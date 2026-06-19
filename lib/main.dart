import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart'; // 👈 1. 引入系统级毛玻璃库
import 'package:tray_manager/tray_manager.dart'; // 👈 引入托盘库
import 'home_page.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 初始化毛玻璃管理器
  await Window.initialize();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 600),          // 初始大小
    minimumSize: Size(700, 500),   // 最小大小
    center: true,                  // 居中显示
    backgroundColor: Colors.transparent, // 👈 3. 必须确保背景完全透明
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏系统默认标题栏
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 4. 开启 Windows 10/11 的亚克力磨砂玻璃效果，并给一个极淡的底色
    await Window.setEffect(
      effect: WindowEffect.acrylic,
      color: const Color(0x10000000), // 极其透明的黑色底，让桌面壁纸透过来
    );
    await windowManager.show();
    await windowManager.focus();
    await initTray(); // 初始化托盘图标+右键菜单
  });
  //await _initSystemTray();
  runApp(const MyApp());
}

// 托盘配置，右键菜单：恢复窗口 / 彻底退出
Future<void> initTray() async {
  await trayManager.setIcon('assets/app_icon.ico');
  await trayManager.setToolTip('粑粑科技');

  final menu = Menu(items: [
    MenuItem(
      label: '恢复窗口',
      onClick: (_) async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setSkipTaskbar(false);
      },
    ),
    MenuItem.separator(),
    MenuItem(
      label: '完全退出',
      onClick: (_) async {
        await trayManager.destroy();
        await windowManager.destroy();
      },
    ),
  ]);
  await trayManager.setContextMenu(menu);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DeskAssistant',
      theme: ThemeData(
        brightness: Brightness.dark, // 默认暗黑模式，更有极客感
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}