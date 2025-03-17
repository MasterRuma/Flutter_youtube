import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'youtube_downloader.dart'; // YouTubeDownloader 클래스가 정의된 파일을 import

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: YouTubeDownloaderScreen(),
    );
  }
}

class YouTubeDownloaderScreen extends StatefulWidget {
  @override
  _YouTubeDownloaderScreenState createState() =>
      _YouTubeDownloaderScreenState();
}

class _YouTubeDownloaderScreenState extends State<YouTubeDownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _selectedDirectory;
  bool _flipHorizontal = false;
  String _statusMessage = '';
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // Android 11 이상에서는 MANAGE_EXTERNAL_STORAGE 권한 요청 방식을 분기
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (status.isDenied) {
        await Permission.manageExternalStorage.request();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  Future<void> _pickDirectory() async {
    // 파일 피커 사용 전 권한 상태 확인
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        setState(() {
          _selectedDirectory = directoryPath;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('권한이 부여되지 않았습니다.')),
      );
    }
  }

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  void _updateProgress(int downloaded, int total) {
    setState(() {
      _downloadedBytes = downloaded;
      _totalBytes = total;
    });
  }

  Future<void> _downloadVideo() async {
    if (_urlController.text.isEmpty || _selectedDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('유효한 URL과 디렉토리를 선택해주세요.')),
      );
      return;
    }

    var downloader = YouTubeDownloader(
      _selectedDirectory!,
      _updateStatus,
      _updateProgress,
    );
    await downloader.download(_urlController.text,
        flipHorizontal: _flipHorizontal);
  }

  Future<void> _downloadAudio() async {
    if (_urlController.text.isEmpty || _selectedDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('유효한 URL과 디렉토리를 선택해주세요.')),
      );
      return;
    }

    var downloader = YouTubeDownloader(
      _selectedDirectory!,
      _updateStatus,
      _updateProgress,
    );
    await downloader.downloadAudio(_urlController.text);
  }

  @override
  Widget build(BuildContext context) {
    double progress = _totalBytes > 0 ? (_downloadedBytes / _totalBytes) : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('YouTube Downloader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDirectory ?? '디렉토리가 선택되지 않음',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _pickDirectory,
                  child: Text('디렉토리 선택'),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Checkbox(
                  value: _flipHorizontal,
                  onChanged: (bool? value) {
                    setState(() {
                      _flipHorizontal = value ?? false;
                    });
                  },
                ),
                Text('비디오 좌우 반전'),
              ],
            ),
            SizedBox(height: 16.0),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
            ),
            SizedBox(height: 8.0),
            Text(_statusMessage),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _downloadVideo,
                  child: Text('MP4 다운로드'),
                ),
                ElevatedButton(
                  onPressed: _downloadAudio,
                  child: Text('MP3 다운로드'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
