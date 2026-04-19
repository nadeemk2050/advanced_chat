import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../utils/blob_reader.dart';

class RecordedAudioData {
  final File? file;
  final Uint8List? bytes;
  final String fileName;

  const RecordedAudioData({
    required this.fileName,
    this.file,
    this.bytes,
  });
}

class AudioRecorderWidget extends StatefulWidget {
  final ValueChanged<RecordedAudioData> onStop;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;

  const AudioRecorderWidget({
    super.key, 
    required this.onStop,
    this.onStart,
    this.onCancel,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _seconds = 0;
  String? _recordingFileName;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  Timer? _timer;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _recordingFileName = kIsWeb ? 'audio_$timestamp.wav' : 'audio_$timestamp.m4a';

        final config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
        );

        if (kIsWeb) {
          await _audioRecorder.start(config, path: _recordingFileName!);
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final String path = '${directory.path}/$_recordingFileName';
          await _audioRecorder.start(config, path: path);
        }

        setState(() {
          _isRecording = true;
          _seconds = 0;
        });

        if (widget.onStart != null) widget.onStart!();
        _startTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required to send voice notes.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Recording Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording) {
        setState(() {
          _seconds++;
        });
        if (_seconds >= 60) {
          _stopRecording();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    final fileName = _recordingFileName;

    setState(() {
      _isRecording = false;
      _recordingFileName = null;
    });

    if (widget.onCancel != null) widget.onCancel!();

    if (path == null || fileName == null) {
      return;
    }

    if (kIsWeb) {
      final bytes = await readBlobUrlBytes(path);
      if (bytes != null) {
        widget.onStop(RecordedAudioData(fileName: fileName, bytes: bytes));
      }
      return;
    }

    widget.onStop(RecordedAudioData(fileName: fileName, file: File(path)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              '0:${_seconds.toString().padLeft(2, '0')} / 1:00',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: ChatTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SEND',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ChatTheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.mic_rounded, color: ChatTheme.primary, size: 28),
        onPressed: _startRecording,
        tooltip: 'Record Voice Note',
      ),
    );
  }
}
