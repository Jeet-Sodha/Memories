import 'package:latlong2/latlong.dart';

class Memory {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final double latitude;
  final double longitude;
  final String? locationName;
  final DateTime? memoryDate;

  /// Storage PATH (not a URL) of the cover image, e.g. USER/MEMORY/1.jpg
  final String? coverImagePath;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int imageCount;
  final int videoCount;
  final int audioCount;

  const Memory({
    required this.id,
    required this.userId,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.locationName,
    this.memoryDate,
    this.coverImagePath,
    this.isFavorite = false,
    this.imageCount = 0,
    this.videoCount = 0,
    this.audioCount = 0,
  });

  factory Memory.fromJson(Map<String, dynamic> j) {
    final media = (j['memory_media'] as List?) ?? const [];
    int count(String t) =>
        media.where((m) => (m as Map)['media_type'] == t).length;
    return Memory(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      locationName: j['location_name'] as String?,
      memoryDate: j['memory_date'] == null
          ? null
          : DateTime.parse(j['memory_date'] as String),
      coverImagePath: j['cover_image_url'] as String?,
      isFavorite: (j['is_favorite'] as bool?) ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      imageCount: count('image'),
      videoCount: count('video'),
      audioCount: count('audio'),
    );
  }

  Memory copyWith({bool? isFavorite}) => Memory(
        id: id,
        userId: userId,
        title: title,
        description: description,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        memoryDate: memoryDate,
        coverImagePath: coverImagePath,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt,
        updatedAt: updatedAt,
        imageCount: imageCount,
        videoCount: videoCount,
        audioCount: audioCount,
      );

  LatLng get latLng => LatLng(latitude, longitude);
  DateTime get displayDate => memoryDate ?? createdAt;
  int get mediaCount => imageCount + videoCount + audioCount;

  /// e.g. "5 photos · 1 video · 1 voice note"
  String get mediaSummary {
    final parts = <String>[];
    if (imageCount > 0) {
      parts.add('$imageCount photo${imageCount == 1 ? '' : 's'}');
    }
    if (videoCount > 0) {
      parts.add('$videoCount video${videoCount == 1 ? '' : 's'}');
    }
    if (audioCount > 0) {
      parts.add('$audioCount voice note${audioCount == 1 ? '' : 's'}');
    }
    return parts.isEmpty ? 'No media' : parts.join(' · ');
  }
}
