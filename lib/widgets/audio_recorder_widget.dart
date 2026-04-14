import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(File) onStop;

  const AudioRecorderWidget({super.key, required this.onStop});

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _seconds = 0;
        });

        _startTimer();
      }
    } catch (e) {
      print('Recording Error: $e');
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        setState(() => _seconds++);
        if (_seconds >= 60) {
          _stopRecording(); // 1 minute limit
        } else {
          _startTimer();
        }
      }
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      widget.onStop(File(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isRecording 
      ? Row(
          children: [
            const Icon(Icons.mic, color: Colors.red),
            const SizedBox(width: 8),
            Text('0:${_seconds.toString().padLeft(2, '0')} / 1:00', style: const TextStyle(color: Colors.red)),
            const Spacer(),
            TextButton(
              onPressed: _stopRecording, 
              child: const Text('Send', style: TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      : IconButton(
          icon: const Icon(Icons.mic_rounded, color: ChatTheme.primary),
          onPressed: _startRecording,
        );
  }
}
