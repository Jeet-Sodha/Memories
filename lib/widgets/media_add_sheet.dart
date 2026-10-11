import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'app_states.dart';
import 'voice_recorder_sheet.dart';

/// Bottom sheet: photos / video / record voice / audio file.
/// [onPaths] receives the chosen file paths and the media kind
/// ('image' | 'video' | 'audio').
Future<void> showAddMediaSheet(
  BuildContext context, {
  required Future<void> Function(List<String> paths, String kind) onPaths,
}) {
  final picker = ImagePicker();

  Future<void> takePhoto() async {
    try {
      final f = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 92);
      if (f != null) await onPaths([f.path], 'image');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not open the camera. Check camera permission.');
      }
    }
  }

  Future<void> recordVideo() async {
    try {
      final f = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 2));
      if (f != null) await onPaths([f.path], 'video');
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not open the camera. Check camera permission.');
      }
    }
  }

  Future<void> pickPhotos() async {
    try {
      final files = await picker.pickMultiImage();
      if (files.isNotEmpty) {
        await onPaths(files.map((f) => f.path).toList(), 'image');
      }
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not open your photo library.');
    }
  }

  Future<void> pickVideo() async {
    try {
      final f = await picker.pickVideo(source: ImageSource.gallery);
      if (f != null) await onPaths([f.path], 'video');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not open your video library.');
    }
  }

  Future<void> pickAudio() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'm4a'],
      );
      final path = r?.files.single.path;
      if (path != null) await onPaths([path], 'audio');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not open that audio file.');
    }
  }

  Future<void> recordVoice() async {
    final path = await VoiceRecorderSheet.show(context);
    if (path != null) await onPaths([path], 'audio');
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    isScrollControlled: true,
    builder: (ctx) {
      Widget tile(IconData icon, String label, Future<void> Function() action) =>
          ListTile(
            leading: Icon(icon, color: AppColors.accentLight),
            title: Text(label),
            onTap: () {
              Navigator.pop(ctx);
              action();
            },
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(Icons.photo_camera_outlined, 'Take a photo', takePhoto),
              tile(Icons.photo_library_outlined, 'Choose photos', pickPhotos),
              tile(Icons.videocam_outlined, 'Record a video', recordVideo),
              tile(Icons.video_library_outlined, 'Choose a video', pickVideo),
              tile(Icons.mic_none, 'Record voice note', recordVoice),
              tile(Icons.audio_file_outlined, 'Audio file', pickAudio),
            ],
            ),
          ),
        ),
      );
    },
  );
}
