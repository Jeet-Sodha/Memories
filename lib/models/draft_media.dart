import 'dart:io';

/// A media item the user picked but has not uploaded yet.
class DraftMedia {
  final String id;
  final File file;
  final String kind; // image | video | audio
  const DraftMedia({required this.id, required this.file, required this.kind});
}
