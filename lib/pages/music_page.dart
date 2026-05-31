// lib/pages/music_page.dart
import 'dart:async';
import 'dart:io'; 
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // 👈 引入存储库以同步设置项

// =========================================================================
// 🧠 第一部分：纯 Dart 打造的轻量级音频队列控制器（逻辑大脑）
// =========================================================================
class MusicController {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 核心状态变量
  List<Map<String, String>> currentList = [];
  Map<String, String>? currentSong;
  bool isPlaying = false;
  String playMode = 'list'; 

  // ⏳ 状态广播流
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<bool> _loadingController = StreamController<bool>.broadcast();
  final StreamController<Map<String, String>?> _currentSongController = StreamController<Map<String, String>?>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<Map<String, String>?> get currentSongStream => _currentSongController.stream;

  Duration _currentDuration = Duration.zero;
  Timer? _debounceTimer;
  bool _isEngineLoading = false;
  bool _isDisposed = false; 

  Function(String)? onLyricNeedReset;

  MusicController() {
    _audioPlayer.onPositionChanged.listen((pos) {
      if (_isDisposed) return; 
      _positionController.add(pos);
    });

    _audioPlayer.onDurationChanged.listen((dur) {
      if (_isDisposed) return; 
      if (dur.inSeconds > 0) {
        _currentDuration = dur;
        _durationController.add(dur);
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (_isDisposed) return; 
      playNext(); 
    });

    _audioPlayer.onPositionChanged.listen((pos) async {
      if (_isDisposed) return;
      _positionController.add(pos);

      if (_currentDuration.inSeconds == 0) {
        final platformDuration = await _audioPlayer.getDuration();
        if (platformDuration != null && platformDuration.inSeconds > 0) {
          _currentDuration = platformDuration;
          _durationController.add(platformDuration); 
        }
      }
    });
  }
  
  void playSong(Map<String, String> song) async {
    if (song['url'] == null || song['url']!.isEmpty || _isDisposed) return;

    currentSong = song;
    isPlaying = true;
    // 🛡️ 核心保障：如果发现当前播放的歌，不在排队队列里（说明被前端切换界面时污染了）
  // 或者是队列被意外清空了，立刻强行把这首歌作为独立种子锁进队列，确保切歌时绝不报错或卡死！
  final exist = currentList.any((s) => s['title'] == song['title'] && s['artist'] == song['artist']);
  if (!exist) {
    currentList = [song]; 
  }

    if (onLyricNeedReset != null) onLyricNeedReset!(song['title'] ?? '');
    _currentSongController.add(song);

    try {
      _loadingController.add(true);
      _positionController.add(Duration.zero);
      _durationController.add(Duration.zero);
      
      await _audioPlayer.stop(); 
      
      // 🔬 兼容性加固：判断是网络流还是本地绝对路径
      if (song['url']!.startsWith('http://') || song['url']!.startsWith('https://')) {
        await _audioPlayer.play(UrlSource(song['url']!)); 
      } else {
        await _audioPlayer.play(DeviceFileSource(song['url']!)); // 🚀 本地绝对路径播放源
      }
      
    } catch (e) {
      debugPrint("🚨 底层播放报错: $e");
    } finally {
      if (!_isDisposed) {
        _loadingController.add(false);
      }
    }
  } 

  Future<void> togglePlayPause() async {
    if (_isDisposed) return;
    
    if (currentSong == null) {
      if (currentList.isNotEmpty) playSong(currentList[0]);
      return;
    }

    if (isPlaying) {
      await _audioPlayer.pause();
      isPlaying = false;
    } else {
      await _audioPlayer.resume();
      isPlaying = true;
    }
  }

  void playNext() {
    if (currentList.isEmpty || _isDisposed) return;
    int nextIndex = 0;

    if (playMode == 'shuffle') {
      int randomIndex = Random().nextInt(currentList.length);
      if (currentList.length > 1) {
        final currentIndex = currentList.indexWhere((s) => s['title'] == currentSong?['title']);
        while (randomIndex == currentIndex) {
          randomIndex = Random().nextInt(currentList.length);
        }
      }
      nextIndex = randomIndex;
    } else {
      final currentIndex = currentList.indexWhere((s) => s['title'] == currentSong?['title']);
      if (currentIndex != -1) {
        nextIndex = (currentIndex + 1) % currentList.length;
      }
    }
    playSong(currentList[nextIndex]);
  }

  void playPrevious() {
    if (currentList.isEmpty || _isDisposed) return;
    int prevIndex = 0;

    if (playMode == 'shuffle') {
      prevIndex = Random().nextInt(currentList.length);
    } else {
      final currentIndex = currentList.indexWhere((s) => s['title'] == currentSong?['title']);
      if (currentIndex != -1) {
        prevIndex = (currentIndex - 1 + currentList.length) % currentList.length;
      }
    }
    playSong(currentList[prevIndex]);
  }

  void seekByPercent(double percent) async {
    if (_currentDuration.inSeconds == 0 || _isDisposed) return;
    final targetSeconds = (_currentDuration.inSeconds * percent).toInt();
    await _audioPlayer.seek(Duration(seconds: targetSeconds));
  }

  void togglePlayMode() {
    playMode = playMode == 'list' ? 'shuffle' : 'list';
  }

  void dispose() {
    _isDisposed = true; 
    _debounceTimer?.cancel();
    _audioPlayer.dispose();
    _positionController.close();
    _durationController.close();
    _loadingController.close();
    _currentSongController.close();
  }
}

// =========================================================================
// 🎨 第二部分：纯净、丝滑、无重构负担的 UI 展现层
// =========================================================================
class MusicPage extends StatefulWidget {
  final Color themeColor;

  const MusicPage({super.key, required this.themeColor});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final MusicController _controller = MusicController();

  // 状态变量区
  bool _isSearching = true;       
  String _selectedPlaylist = '本地歌单'; // 👈 默认选中改成“本地歌单”
  String _searchSource = 'cloud';       // 👈 'cloud' 代表云端搜索，'local' 代表本地搜索
  List<Map<String, String>> _allLocalSongs = []; // 👈 专门存储扫描出来的全部本地歌曲

  // 🎤 默认歌词滚动模板
  final List<String> _lyricLines = [
    "故事的小黄花 从出生那年就飘着",
    "童年的荡秋千 随记忆一直晃到现在",
    "Re S0 S0 Do Si La S0 La Si Si Si Si La Si La S0",
    "吹着前奏望着天空 我想起花瓣试着掉落",
    "为你翘课那天 花落的那天 教室的那一间 我怎么看不见",
    "消失的下雨天 我好想再淋一遍"
  ];
  int _lyricIndex = 0;
  Timer? _lyricTimer;
  String _currentLyricText = "期待你的第一首音乐...";

  // 模拟数据集（默认云端结果）
  final List<Map<String, String>> _searchResults = [
    {'title': '七里香 (测试音源1)', 'artist': '周杰伦', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
    {'title': '晴天 (测试音源2)', 'artist': '周杰伦', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'},
    {'title': '算什么男人 (测试音源3)', 'artist': '周杰伦', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'},
  ];

  late final Map<String, List<Map<String, String>>> _playlistsData;

  bool _isUserDraggingSlider = false;
  double _dragValue = 0.0;

  Process? _pythonProcess;
  int _serverPort = 18080;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 5),
  ));  

  @override
  void initState() {
    super.initState();
    
    // 👈 重构初始化歌单架构
    _playlistsData = {
      '本地歌单': [],
      '本地爱心歌单': [],
    };

    _controller.currentList = _searchResults;

    _controller.onLyricNeedReset = (title) {
      if (!mounted) return; 
      setState(() {
        _lyricIndex = 0;
        _currentLyricText = _lyricLines[_lyricIndex];
      });
    };

    _controller._audioPlayer.onPositionChanged.listen((pos) async {
      if (!mounted) return;
      if (_controller._currentDuration.inSeconds == 0) {
        final platformDuration = await _controller._audioPlayer.getDuration();
        if (platformDuration != null && platformDuration.inSeconds > 0) {
          setState(() {
            _controller._currentDuration = platformDuration;
            _controller._durationController.add(platformDuration);
          });
        }
      }
    });

    _lyricTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel(); 
        return;
      }
      if (_controller.isPlaying && _controller.currentSong != null) {
        setState(() {
          _lyricIndex = (_lyricIndex + 1) % _lyricLines.length;
          _currentLyricText = _lyricLines[_lyricIndex];
        });
      }
    });

    _startPythonServer(); 
    _loadAndScanLocalMusic(); // 🚀 启动时自动从存储中加载并扫描本地音源
  }

  // 📂 读取本地设置路径并异步抓取 MP3 文件
  Future<void> _loadAndScanLocalMusic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFolder = prefs.getString('saved_music_folder') ?? '';
      
      if (savedFolder.isEmpty) return;
      final dir = Directory(savedFolder);
      if (!await dir.exists()) return;

      List<Map<String, String>> localFiles = [];
      
      // 遍历指定的本地音源文件夹下的第一层文件
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
          // 提取纯文件名并干掉后缀
          String fileName = entity.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
          String title = fileName;
          String artist = '本地音频';
          
          // 如果文件名带有经典的 " - " 格式，自动切分歌手与歌名
          if (fileName.contains(' - ')) {
            var parts = fileName.split(' - ');
            artist = parts[0].trim();
            title = parts[1].trim();
          }

          localFiles.add({
            'title': title,
            'artist': artist,
            'url': entity.path, // 播放核心会通过 DeviceFileSource 播放此绝对路径
          });
        }
      }

      setState(() {
        _allLocalSongs = localFiles;
        _playlistsData['本地歌单'] = _allLocalSongs; // 动态挂载到本地歌单容器中
        
        // 如果当前正好停留在本地歌单视图，同步刷新控制器的队列大脑
        //if (!_isSearching && _selectedPlaylist == '本地歌单') {
      //    _controller.currentList = _allLocalSongs;
      //  }
      });
      debugPrint("🎵 成功抓取本地音源库：共找到 ${_allLocalSongs.length} 首歌曲");
    } catch (e) {
      debugPrint("🚨 扫描本地音乐文件夹出现异常: $e");
    }
  }

  void _startPythonServer() async {
    try {
      ServerSocket socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _serverPort = socket.port;
      await socket.close();
    } catch (_) {}

    int myPid = pid;

    try {
      _pythonProcess = await Process.start(
        'py', 
        ['-3.14', 'spider.py', '--port', '$_serverPort', '--ppid', '$myPid'],
        runInShell: true,
      );
      debugPrint("🚀 【工业级加固】Python 3.14 后端微服务已成功拉起！端口: $_serverPort");
    } catch (e) {
      debugPrint("🚨 自动拉起 Python 失败: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lyricTimer?.cancel(); 
    _controller.dispose();  
    _pythonProcess?.kill(); 
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentPlaylistSongs = _playlistsData[_selectedPlaylist] ?? [];

    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory, 
        hoverColor: Colors.white.withValues(alpha: 0),       
      ),

      child: Column(
        children: [
          // ================= 1. 顶部搜索栏 (集成胶囊切换器) =================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Tooltip(
                  message: _isSearching ? '切换到我的歌单' : '返回搜索界面',
                  child: IconButton(
                    icon: Icon(_isSearching ? Icons.library_music_rounded : Icons.search_rounded, color: widget.themeColor),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        //_controller.currentList = _isSearching ? _searchResults : currentPlaylistSongs;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isSearching 
                          ? (_searchSource == 'cloud' ? '云端搜素：输入歌名或歌手...' : '本地检索：在本地音源夹中过滤...') 
                          : '在当前歌单中过滤...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1E1E2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                
                // 💊 ================= 新增：高质感胶囊双模切换器 =================
                if (_isSearching) ...[
                  const SizedBox(width: 12),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E), 
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _searchSource = 'cloud'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _searchSource == 'cloud' ? widget.themeColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '云端搜索',
                              style: TextStyle(
                                color: _searchSource == 'cloud' ? Colors.white : Colors.white38,
                                fontSize: 11,
                                fontWeight: _searchSource == 'cloud' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _searchSource = 'local');
                            _loadAndScanLocalMusic(); // 顺手做一次静默增量刷新
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _searchSource == 'local' ? widget.themeColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '本地搜索',
                              style: TextStyle(
                                color: _searchSource == 'local' ? Colors.white : Colors.white38,
                                fontSize: 11,
                                fontWeight: _searchSource == 'local' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // ==========================================================

                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final keyword = _searchController.text.trim();
                    if (keyword.isEmpty) return;

                    // ================= 🔍 分流 1：如果是本地搜索 =================
                    if (_searchSource == 'local') {
                      final localResults = _allLocalSongs.where((song) {
                        final title = (song['title'] ?? '').toLowerCase();
                        final artist = (song['artist'] ?? '').toLowerCase();
                        final key = keyword.toLowerCase();
                        return title.contains(key) || artist.contains(key);
                      }).toList();

                      if (mounted) {
                        setState(() {
                          _isSearching = true; // 👈 确保处于搜索结果视图，不跳回歌单
                          _searchResults.clear();
                          _searchResults.addAll(localResults);
                          //_controller.currentList = _searchResults; 
                        });
                      }
                      return; // 纯内存筛选，闪电拦截，不唤醒 Python 后端
                    }

                    // ================= 🌐 分流 2：如果是网络云端爬取 =================
                    if (!_isSearching) setState(() => _isSearching = true);
                    
                    _controller.playSong({'title': '正在拼命爬取网络音源...', 'artist': keyword, 'url': ''});

                    try {
                      final response = await _dio.get('http://127.0.0.1:$_serverPort/search', queryParameters: {'keyword': keyword});
                      
                      if (response.statusCode == 200 && response.data['code'] == 200) {
                        List<dynamic> serverData = response.data['data'] ?? [];
                        
                        List<Map<String, String>> webResults = [];
                        for (var item in serverData) {
                          webResults.add({
                            'title': item['title'] ?? '未知歌名',
                            'artist': item['artist'] ?? '未知歌手',
                            'url': item['url'] ?? '',
                          });
                        }

                        if (mounted) {
                          setState(() {
                            
                            _searchResults.clear();
                            _searchResults.addAll(webResults);
                            //_controller.currentList = _searchResults; 
                          });
                        }
                      }
                    } catch (e) {
                      debugPrint("📡 前端请求本地 Python 失败: $e");
                    } finally {
                      if (mounted) setState(() => _isSearching = true); 
                    }
                  },
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('搜索'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // ================= 2. 中部核心展示区 =================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isSearching ? _buildSearchResultsView() : _buildPlaylistsView(currentPlaylistSongs),
            ),
          ),

          // ================= 3. 底部常驻控制条 =================
          Container(
            height: 105, 
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                StreamBuilder<Duration>(
                  stream: _controller.durationStream,
                  builder: (context, durationSnapshot) {
                    final dur = durationSnapshot.data ?? Duration.zero;
                    
                    return StreamBuilder<Duration>(
                      stream: _controller.positionStream,
                      builder: (context, positionSnapshot) {
                        final pos = positionSnapshot.data ?? Duration.zero;
                        
                        double currentLivePercent = 0.0;
                        if (dur.inSeconds > 0) {
                          currentLivePercent = (pos.inSeconds / dur.inSeconds).clamp(0.0, 1.0);
                        }

                        double displayValue = _isUserDraggingSlider ? _dragValue : currentLivePercent;

                        return Row(
                          children: [
                            Text(
                              _isUserDraggingSlider 
                                  ? _formatDuration(Duration(seconds: (dur.inSeconds * _dragValue).toInt()))
                                  : _formatDuration(pos), 
                              style: const TextStyle(color: Colors.white38, fontSize: 11)
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: widget.themeColor,
                                  inactiveTrackColor: Colors.white10,
                                  thumbColor: widget.themeColor,
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: 1.0, 
                                  value: displayValue,
                                  onChanged: (value) {
                                    setState(() {
                                      _isUserDraggingSlider = true;
                                      _dragValue = value;
                                    });
                                  },
                                  onChangeEnd: (value) {
                                    _controller.seekByPercent(value);
                                    setState(() {
                                      _isUserDraggingSlider = false; 
                                    });
                                  },
                                ),
                              ),
                            ),
                            Text(_formatDuration(dur), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 4),

                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: widget.themeColor, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      
                      SizedBox(
                        width: 120, 
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _controller.currentSong != null ? (_controller.currentSong!['title'] ?? '未知歌名') : '等待播放...',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _controller.currentSong != null ? (_controller.currentSong!['artist'] ?? '未知歌手') : '未知歌手',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 0), 
                      alignment: Alignment.centerLeft,
                      child: StreamBuilder<bool>(
                        stream: _controller.loadingStream,
                        builder: (context, snapshot) {
                          final isLoading = snapshot.data ?? false;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            key: const ValueKey<String>('global_lyric_switcher'),
                            child: Text(
                              isLoading ? "正在全力缓冲流媒体中..." : _currentLyricText,
                              key: ValueKey<String>(isLoading ? "loading" : _currentLyricText),
                              style: TextStyle(
                                color: _controller.isPlaying ? widget.themeColor.withValues(alpha: 0.8) : Colors.white24, 
                                fontSize: 15, 
                                fontStyle: FontStyle.italic
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }
                      ),
                    ),
                  ),

                  Tooltip(
                    message: '上一首',
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                      onPressed: () => _controller.playPrevious(), //=> setState(() 
                    ),
                  ),
                  
                  Tooltip(
                    message: _controller.isPlaying ? '暂停' : '播放', 
                    child: Container(
                      decoration: BoxDecoration(color: widget.themeColor, shape: BoxShape.circle),
                      child: IconButton(
                        icon: Icon(
                          _controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                          color: Colors.white, 
                          size: 24
                        ),
                        onPressed: () async {
                          await _controller.togglePlayPause();
                          if (mounted) setState(() {}); 
                        }, 
                      ),
                    ),
                  ),
                  
                  Tooltip(
                    message: '下一首',
                    child: IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                      onPressed: ()  => _controller.playNext(), //=> setState(()
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Tooltip(
                    message: _controller.playMode == 'list' ? '当前：顺序播放' : '当前：随机播放',
                    child: IconButton(
                      icon: Icon(
                        _controller.playMode == 'list' ? Icons.playlist_play_rounded : Icons.shuffle_rounded, 
                        color: _controller.playMode == 'list' ? Colors.white60 : widget.themeColor, 
                        size: 20
                      ),
                      onPressed: () {
                        setState(() {
                          _controller.togglePlayMode();
                        });
                      },
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
}

  Widget _buildSearchResultsView() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E2E).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_searchSource == 'cloud' ? '🔍 在线搜索结果' : '📁 本地筛选结果', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _searchResults.isEmpty 
                ? const Center(child: Text('没有找到匹配的歌曲明细~', style: TextStyle(color: Colors.white24, fontSize: 12)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) => _buildSongRow(_searchResults[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsView(List<Map<String, String>> currentPlaylistSongs) {
    // 👈 动态绑定本地重塑后的歌单图标
    final Map<String, IconData> playlistIcons = {
      '本地歌单': Icons.folder_special_rounded,
      '本地爱心歌单': Icons.favorite_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            children: _playlistsData.keys.map((name) {
              final isSelected = _selectedPlaylist == name;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPlaylist = name;
                      // 如果用户选了本地歌单，顺手刷一下最新的本地目录文件
                      if (name == '本地歌单') {
                        _loadAndScanLocalMusic();
                      }
                      //// 🧠 删掉了强行覆盖 currentList 的这行！眼睛切换视图不应该干扰耳朵正在听的队列
                      //_controller.currentList = _playlistsData[name] ?? [];
                      
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.themeColor.withValues(alpha: 0.15) : const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? widget.themeColor : Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(playlistIcons[name] ?? Icons.music_note_rounded, color: isSelected ? widget.themeColor : Colors.white60, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name, 
                            style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1E1E2E).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Text('🎵 $_selectedPlaylist (${currentPlaylistSongs.length}首)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: currentPlaylistSongs.isEmpty ? null : () {
                          setState(() {
                            _controller.currentList = List<Map<String, String>>.from(currentPlaylistSongs);
                            _controller.playSong(currentPlaylistSongs[0]);
                          });
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('一键播放', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: currentPlaylistSongs.isEmpty
                      ? Center(
                          child: Text(
                            _selectedPlaylist == '本地歌单' ? '本地暂未扫描到任何歌曲，请先去系统设置配置路径~' : '歌单空空如也，快去搜索添加吧~', 
                            style: const TextStyle(color: Colors.white24, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: currentPlaylistSongs.length,
                          itemBuilder: (context, index) => _buildSongRow(currentPlaylistSongs[index], isInPlaylist: true),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongRow(Map<String, String> song, {bool isInPlaylist = false}) {
    return StreamBuilder<Map<String, String>?>(
  stream: _controller.currentSongStream,
  builder: (context, snapshot) {
    // 🧠 1. 不管流有没有延迟，直接去大脑控制器拿绝对准确的静态新歌数据比对
    final bool isThisSong = _controller.currentSong != null && 
                            _controller.currentSong!['title'] == song['title'] && 
                            _controller.currentSong!['artist'] == song['artist'];

    // 🧠 2. 只有当确实是这首歌，并且控制器处于播放状态时，才亮起双竖线
    final bool isThisSongPlaying = isThisSong && _controller.isPlaying;
    final bool isFavorite = _playlistsData['本地爱心歌单']?.any((element) => 
            element['title'] == song['title'] && element['artist'] == song['artist']
        ) ?? false;
        return ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isThisSongPlaying ? widget.themeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04), 
              borderRadius: BorderRadius.circular(6)
            ),
            child: Icon(
              isThisSongPlaying ? Icons.volume_up_rounded : Icons.music_note_rounded, 
              color: isThisSongPlaying ? widget.themeColor : Colors.white38, 
              size: 18
            ),
          ),
          title: Text(
            song['title'] ?? '未知歌名', 
            style: TextStyle(
              color: isThisSongPlaying ? widget.themeColor : Colors.white, 
              fontSize: 13,
              fontWeight: isThisSongPlaying ? FontWeight.bold : FontWeight.normal
            )
          ),
          subtitle: Text(song['artist'] ?? '未知歌手', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: isFavorite ? '取消收藏' : '收藏到爱心歌单',
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    color: isFavorite ? Colors.redAccent : Colors.white38, 
                    size: 18
                  ),
                  onPressed: () {
                    setState(() {
                      if (isFavorite) {
                        // 💔 如果已经收藏了，点击就是精准“取消收藏”（从爱心歌单里消灭它）
                        _playlistsData['本地爱心歌单']?.removeWhere((element) => 
                            element['title'] == song['title'] && element['artist'] == song['artist']
                        );
                      } else {
                        // ❤️ 如果没收藏，点击就给它加进爱心歌单（深拷贝一份，防止指针污染）
                        _playlistsData['本地爱心歌单']?.add({
                          'title': song['title'] ?? '未知歌名',
                          'artist': song['artist'] ?? '未知歌手',
                          'url': song['url'] ?? '',
                        });
                      }
                    });
                  },
                ),
              ),
              Tooltip(
                message: isThisSongPlaying && _controller.isPlaying ? '暂停播放' : '立刻试听这首歌',
                child: IconButton(
                  icon: Icon(
                    isThisSongPlaying //&& _controller.isPlaying 
                        ? Icons.pause_circle_filled_rounded  
                        : Icons.play_circle_fill_rounded,    
                    color: widget.themeColor, 
                    size: 26
                  ),
                  // 找到 _buildSongRow 尾部的试听 IconButton 里的 onPressed：
                  onPressed: () async {
          if (isThisSongPlaying) {
            await _controller.togglePlayPause();
             } else {
                 // ⚡ 核心大招：试听新歌时，动态判定用户是在哪个视图点的，并把对应整条列表灌入大脑
              setState(() {
              if (_isSearching) {
                     // 如果在搜索页点歌，把整个搜索结果作为当下的临时播放队列
                   _controller.currentList = List<Map<String, String>>.from(_searchResults);
               } else {
               // 如果在歌单页点歌，把当前选中的歌单（本地或爱心）作为排队队列
                  final currentPlaylistSongs = _playlistsData[_selectedPlaylist] ?? [];
                  _controller.currentList = List<Map<String, String>>.from(currentPlaylistSongs);
            }
             });
    
             _controller.playSong(song);
           }
                  if (mounted) setState(() {}); 
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}