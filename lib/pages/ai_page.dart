// lib/pages/ai_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 核心：引入系统服务，用来调用剪贴板
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiPage extends StatefulWidget {
  final Color themeColor;

  const AiPage({super.key, required this.themeColor});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 保持页面存活

  // 初始化对话历史
  final List<Map<String, String>> _historyMessages = [
    {
      'role': 'system',
      'content': '你是一个没个正经，用荤段子逗弄用户,但是不显幼稚，略微刻薄，拿用户取乐的，尤其擅长用低俗梗和谐音梗以及歇后语（歇后语不要用的太多而显得刻意）的高智商助手'
    }
  ];

  List<Map<String, String>> get _displayMessages => _historyMessages
      .where((msg) => msg['role'] != 'system')
      .toList();

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // 焦点控制器
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false; 
  String _apiKey = '';    

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('请先前往左下角系统设置页面填写您的 API Key！'), backgroundColor: widget.themeColor),
      );
      return;
    }

    _inputController.clear();
    _focusNode.requestFocus(); // 👈 发送后立刻强制锁死输入框焦点
    
    setState(() {
      _historyMessages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _historyMessages.add({'role': 'assistant', 'content': ''});
    });
    _scrollToBottom();

    try {
      var request = http.Request('POST', Uri.parse('https://api.deepseek.com/chat/completions'));
      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      });
      
      request.body = jsonEncode({
        'model': 'deepseek-chat',
        'messages': _historyMessages.sublist(0, _historyMessages.length - 1),
        'stream': true,
      });

      var response = await http.Client().send(request);
      String fullAnswer = "";
      
      response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.startsWith('data: ')) {
            String dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') return;

            try {
              var jsonData = jsonDecode(dataStr);
              if (jsonData['choices'] != null && jsonData['choices'][0]['delta'] != null) {
                String? content = jsonData['choices'][0]['delta']['content'];
                if (content != null) {
                  fullAnswer += content;
                  setState(() {
                    _historyMessages[_historyMessages.length - 1]['content'] = fullAnswer;
                  });
                  _scrollToBottom();
                }
              }
            } catch (_) {}
          }
        },
        onDone: () {
          setState(() => _isLoading = false);
        },
        onError: (error) {
          setState(() {
            _isLoading = false;
            _historyMessages[_historyMessages.length - 1]['content'] = '连接中断：$error';
          });
        }
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
        _historyMessages[_historyMessages.length - 1]['content'] = '发生错误：$e';
      });
    }
  }

  // 🌟 新增：调用剪贴板一键复制的逻辑函数
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('骚话已成功复制到剪贴板！'),
              ],
            ),
            backgroundColor: widget.themeColor,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 260,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 1. 顶部小标题
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: widget.themeColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                'DeepSeek 智能调戏空间',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          
          // 2. 聊天气泡滚动区
          Expanded(
            child: _displayMessages.isEmpty
                ? const Center(child: Text('输入点什么，接受高智商助手的审判...', style: TextStyle(color: Colors.white24)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _displayMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _displayMessages[index];
                      final isAi = msg['role'] == 'assistant';
                      final contentText = msg['content'] ?? '';

                      return Align(
                        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            // 聊天气泡本体
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAi ? const Color(0xFF1E1E2E) : widget.themeColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isAi ? 0 : 12),
                                  bottomRight: Radius.circular(isAi ? 12 : 0),
                                ),
                              ),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                              
                              // ✨ 优化：改用 SelectableText，让桌面端用户可以直接用鼠标划词、右键复制！
                              child: SelectableText(
                                contentText,
                                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                              ),
                            ),
                            
                            // ✨ 优化：如果是 AI 或者是用户发完了的消息，在下方显示一行极轻量的一键复制小按钮
                            if (contentText.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(left: isAi ? 4 : 0, right: isAi ? 0 : 4, bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => _copyToClipboard(contentText), // 点击调用复制
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 11, color: Colors.white38),
                                        SizedBox(width: 4),
                                        Text('复制', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 3. 底部输入框底座
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode, // 👈 绑定焦点
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _apiKey.isEmpty ? '请先去设置页面配置您的 API Key...' : '跟高智商助手过几招吧...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF1E1E2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: _isLoading ? Colors.white24 : widget.themeColor,
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}