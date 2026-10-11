class MemoryMedia {
  final String id;
  final String memoryId;
  final String mediaType; // image | video | audio
  final String mediaPath; // storage path inside the private bucket
  final int displayOrder;

  const MemoryMedia({
    required this.id,
    required this.memoryId,
    required this.mediaType,
    required this.mediaPath,
    required this.displayOrder,
  });

  factory MemoryMedia.fromJson(Map<String, dynamic> j) => MemoryMedia(
        id: j['id'] as String,
        memoryId: j['memory_id'] as String,
        mediaType: j['media_type'] as String,
        mediaPath: j['media_url'] as String,
        displayOrder: (j['display_order'] as num).toInt(),
      );
}
