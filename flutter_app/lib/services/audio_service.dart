import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _recordingPath;

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    if (await _recorder.hasPermission()) {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: _recordingPath!,
      );
    } else {
      throw Exception('Microphone permission denied');
    }
  }

  Future<List<int>?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      await file.delete(); // Clean up temp file
      return bytes;
    }
    return null;
  }

  Future<void> playBytes(List<int> audioBytes) async {
    await _player.stop();
    await _player.play(BytesSource(Uint8List.fromList(audioBytes)));
  }

  Future<void> playFile(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stop() async {
    await _player.stop();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<bool> get isRecording => _recorder.isRecording();

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
