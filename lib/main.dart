import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'youtube_downloader.dart'; // YouTubeDownloader 클래스를 정의한 파일을 import

void main() {
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

  Future<void> _requestPermissions() async {
    var permission = await Permission.manageExternalStorage.request();
    if (await permission.isDenied) {
      // None!
    }
  }

  Future<void> _pickDirectory() async {
    // Check if storage permission is granted before attempting to open the file picker
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
        SnackBar(
          content: Text('Permission is not granted.'),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a valid URL and select a directory.'),
      ));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a valid URL and select a directory.'),
      ));
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
                    _selectedDirectory ?? 'No directory selected',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _pickDirectory,
                  child: Text('Select Directory'),
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
                Text('Flip Video Horizontally'),
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
                  child: Text('Download MP4'),
                ),
                ElevatedButton(
                  onPressed: _downloadAudio,
                  child: Text('Download MP3'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
