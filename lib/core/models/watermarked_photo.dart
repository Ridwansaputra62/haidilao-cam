import 'dart:io';

class WatermarkedPhoto {
  final String id;
  final String path;
  final DateTime dateTaken;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final String branchName;
  final int fileSize;

  WatermarkedPhoto({
    required this.id,
    required this.path,
    required this.dateTaken,
    required this.locationText,
    this.latitude,
    this.longitude,
    required this.branchName,
    required this.fileSize,
  });

  File get file => File(path);

  bool get exists => file.existsSync();

  bool get isVideo => path.toLowerCase().endsWith('.mp4');

  String get thumbnailPath {
    if (!isVideo) return path;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1) {
      final thumbCandidate = '${path.substring(0, dotIndex)}_thumb.jpg';
      if (File(thumbCandidate).existsSync()) {
        return thumbCandidate;
      }
    }
    return path;
  }

  bool get hasThumbnail {
    if (!isVideo) return exists;
    final tPath = thumbnailPath;
    return tPath != path && File(tPath).existsSync();
  }

  File get thumbnailFile => File(thumbnailPath);

  String get formattedSize {
    double kb = fileSize / 1024;
    if (kb >= 1024) {
      double mb = kb / 1024;
      return '${mb.toStringAsFixed(2)} MB';
    }
    return '${kb.toStringAsFixed(0)} KB';
  }
}
