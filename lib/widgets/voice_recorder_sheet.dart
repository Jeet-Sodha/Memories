import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Records a voice note (.m4a). Returns the file path via Navigator.pop.
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const VoiceRecorderSheet(),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final AudioRecorder _rec = AudioRecorder();
  Timer? _timer;
  bool _recording = false;
  int _seconds = 0;
  String? _error;

  static const int _maxSeconds = 600; // 10 min keeps files well under 50 MB

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'Microphone permission is needed to record.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(
          dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= _maxSeconds) _stop();
      });
      setState(() {
        _recording = true;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'Could not start recording.');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _recording = false);
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_recording ? 'Recording…' : 'Record a voice note',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Text(formatDuration(Duration(seconds: _seconds)),
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    color: AppColors.accentLight)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _recording ? _stop : _start,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.memory,
                  boxShadow: _recording
                      ? const [
                          BoxShadow(color: Color(0x80E47C7C), blurRadius: 24)
                        ]
                      : null,
                ),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic,
                    size: 36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Text(_recording ? 'Tap to stop and add' : 'Tap to start',
                style: const TextStyle(color: AppColors.textSecondary)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
