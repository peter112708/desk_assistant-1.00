import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'home_page.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 600),          // 初始大小
    minimumSize: Size(700, 500),   // 最小大小
    center: true,                  // 居中显示
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏系统默认标题栏
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
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