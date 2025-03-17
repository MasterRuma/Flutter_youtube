import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class YouTubeDownloader {
  final String saveDirectory;
  final YoutubeExplode yt = YoutubeExplode();
  final Function(String) onStatusChanged;
  final Function(int, int) onProgressChanged;

  YouTubeDownloader(
      this.saveDirectory, this.onStatusChanged, this.onProgressChanged);

  Future<void> download(String id, {bool flipHorizontal = false}) async {
    await requestPermissions();
    try {
      onStatusChanged('MP4 다운로드 중...');
      final video = await yt.videos.get(id);
      final manifest = await yt.videos.streamsClient.getManifest(id);

      final videoStream = manifest.videoOnly
          .where((stream) => stream.container.name == 'mp4')
          .withHighestBitrate();
      final videoData = yt.videos.streamsClient.get(videoStream);

      final audioStream = manifest.audioOnly
          .where((stream) => stream.container.name == 'mp4')
          .withHighestBitrate();
      final audioData = yt.videos.streamsClient.get(audioStream);

      final videoFileName = '${video.title}.${videoStream.container.name}'
          .replaceAll(RegExp(r'[\\/*?"<>|:]'), '');
      final audioFileName = '${video.title}.${audioStream.container.name}'
          .replaceAll(RegExp(r'[\\/*?"<>|:]'), '');

      final video_T = '${video.title}'.replaceAll(RegExp(r'[\\/*?"<>|:]'), '');

      final videoFile = File(path.join(saveDirectory, 'V_$videoFileName'));
      final audioFile = File(path.join(saveDirectory, 'A_$audioFileName'));

      if (await videoFile.exists()) videoFile.deleteSync();
      if (await audioFile.exists()) audioFile.deleteSync();

      await writeToFile(
          videoData, videoFile, videoStream.size.totalBytes, 'MP4');
      await writeToFile(
          audioData, audioFile, audioStream.size.totalBytes, 'MP3');

      onStatusChanged('영상 병합중...');
      await mergeVideoAndAudio(
          videoFile.path, audioFile.path, video_T, flipHorizontal);

      await deleteTempFiles();
      onStatusChanged(
          '다운로드 완료! ${path.join(saveDirectory, "${video.title}.mp4")}에 저장되었습니다!');
    } catch (e) {
      onStatusChanged('Error: $e');
    }
  }

  Future<void> downloadAudio(String id) async {
    await requestPermissions();
    try {
      onStatusChanged('MP3 다운로드 중...');
      final video = await yt.videos.get(id);
      final manifest = await yt.videos.streamsClient.getManifest(id);

      final audioStream = manifest.audioOnly
          .where((stream) => stream.container.name == 'mp4')
          .withHighestBitrate();
      final audioData = yt.videos.streamsClient.get(audioStream);

      final audioFileName = '${video.title}.${audioStream.container.name}'
          .replaceAll(RegExp(r'[\\/*?"<>|:]'), '');

      final video_T = '${video.title}'.replaceAll(RegExp(r'[\\/*?"<>|:]'), '');

      final audioFile = File(path.join(saveDirectory, 'A_$audioFileName'));

      if (await audioFile.exists()) audioFile.deleteSync();

      await writeToFile(
          audioData, audioFile, audioStream.size.totalBytes, 'MP3');
      await convertVideoToMP3(audioFile.path, video_T);

      await deleteTempFiles();
      onStatusChanged(
          '다운로드 완료! ${path.join(saveDirectory, "${video.title}.mp3")}에 저장되었습니다!');
    } catch (e) {
      onStatusChanged('Error: $e');
    }
  }

  Future<void> writeToFile(
      Stream<List<int>> stream, File file, int totalSize, String type) async {
    final output = file.openWrite();
    int downloaded = 0;

    await for (final data in stream) {
      downloaded += data.length;
      output.add(data);
      onProgressChanged(downloaded, totalSize);
      onStatusChanged(
          '$type 다운로드 중... ${_formatBytes(downloaded)}/${_formatBytes(totalSize)}');
    }
    await output.close();
  }

  Future<void> mergeVideoAndAudio(String videoPath, String audioPath,
      String title, bool flipHorizontal) async {
    final outputFilePath = flipHorizontal
        ? path.join(saveDirectory, 'M_$title.mp4')
        : path.join(saveDirectory, '$title.mp4');

    final ffmpegCommand = [
      '-i',
      '"$videoPath"',
      '-i',
      '"$audioPath"',
      '-c:v copy -c:a aac',
      '"$outputFilePath"',
    ];

    print('FFmpeg command: ${ffmpegCommand.join(' ')}');

    final result = await FFmpegKit.execute(ffmpegCommand.join(' '));
    final resultString = await result.getOutput();
    final resultCode = await result.getReturnCode();

    print('FFmpeg Result Code: $resultCode');
    print('FFmpeg Output: $resultString');

    if (flipHorizontal == true) {
      final outputFilePathMerge = path.join(saveDirectory, '$title.mp4');
      print('영상 돌리는 중...');
      final ffmpegFlipCommand = [
        '-i "$outputFilePath" -vf hflip -c:v mpeg4 "$outputFilePathMerge"',
      ];
      final resultFlip = await FFmpegKit.execute(ffmpegFlipCommand.join(' '));
      final resultStringFlip = await resultFlip.getOutput();
      final resultCodeFlip = await resultFlip.getReturnCode();

      print('FFmpeg Result Code: $resultCodeFlip');
      print('FFmpeg Output: $resultStringFlip');
    }

    if (resultCode != 0) {
      onStatusChanged('FFmpeg Error: $resultString');
    } else {
      onStatusChanged('FFmpeg Success');
    }
  }

  Future<void> convertVideoToMP3(String videoPath, String title) async {
    final mp3FilePath = path.join(saveDirectory, '$title.mp3');

    // FFmpeg 명령어 수정
    final ffmpegCommand = [
      '-i', "'$videoPath'",
      // MP3 코덱 설정
      "'$mp3FilePath'"
    ];

    print('FFmpeg command: ${ffmpegCommand.join(' ')}');

    final result = await FFmpegKit.execute(ffmpegCommand.join(' '));
    final resultString = await result.getOutput();
    final resultCode = await result.getReturnCode();

    print('FFmpeg Result Code: $resultCode');
    print('FFmpeg Output: $resultString');

    if (resultCode != 0) {
      onStatusChanged('FFmpeg Error: $resultString');
    } else {
      onStatusChanged('MP3 변환 완료! ${mp3FilePath}에 저장되었습니다!');
    }
  }

  Future<void> deleteTempFiles() async {
    final downloadsDir = Directory(saveDirectory);
    final files = downloadsDir.listSync();

    for (var file in files) {
      if (file is File) {
        final fileName = file.uri.pathSegments.last;
        if (fileName.startsWith('V_') ||
            fileName.startsWith('A_') ||
            fileName.startsWith('M_')) {
          await file.delete();
        }
      }
    }
  }

  Future<void> requestPermissions() async {
    var permission = await Permission.manageExternalStorage.request();
    if (await permission.isDenied) {
      throw Exception('Storage permission is required to proceed.');
    }
  }

  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes == 0) return '0 Bytes';
    final k = 1024;
    final sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(k)).floor();
    return '${(bytes / pow(k, i)).toStringAsFixed(decimals)} ${sizes[i]}';
  }
}
