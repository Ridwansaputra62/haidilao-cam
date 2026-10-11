import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';
import 'package:haidilao_cam/core/services/watermark_service.dart';

enum PhotoFilter {
  today,      // Hari Ini / Today / 今天
  thisWeek,   // Minggu Ini / This Week / 本周
  thisMonth,  // Bulan Ini / This Month / 本月
  all         // Semua Foto / All Photos / 全部
}

extension PhotoFilterExtension on PhotoFilter {
  String get label {
    switch (this) {
      case PhotoFilter.today:
        return 'filter.today'.tr();
      case PhotoFilter.thisWeek:
        return 'filter.this_week'.tr();
      case PhotoFilter.thisMonth:
        return 'filter.this_month'.tr();
      case PhotoFilter.all:
        return 'filter.all'.tr();
    }
  }
}


class PhotoStorageService {
  /// Alias for loadPhotos
  static Future<List<WatermarkedPhoto>> getPhotos() => loadPhotos();

  /// Loads all watermarked photos saved in local memory.
  static Future<List<WatermarkedPhoto>> loadPhotos() async {
    final List<WatermarkedPhoto> photos = [];
    try {
      final Directory dir = await WatermarkService.getHaidilaoCameraDirectory();

      if (!dir.existsSync()) {
        return photos;
      }

      final List<FileSystemEntity> entities = dir.listSync();

      for (var entity in entities) {
        if (entity is File) {
          final String lowerPath = entity.path.toLowerCase();
          // Skip companion video thumbnails from appearing as independent photos
          if (lowerPath.endsWith('_thumb.jpg') || lowerPath.endsWith('_thumb.png')) {
            continue;
          }

          final bool isPhoto = lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.png');
          final bool isVideo = lowerPath.endsWith('.mp4');

          if (isPhoto || isVideo) {
            try {
              final FileStat stat = entity.statSync();
              final String filename = entity.path.split(Platform.pathSeparator).last;
              
              // Extract branch name or metadata from filename or default
              String branch = 'Haidilao Store';
              if (filename.contains('HDL_')) {
                branch = 'Haidilao Official';
              }

              photos.add(WatermarkedPhoto(
                id: entity.path,
                path: entity.path,
                dateTaken: stat.modified,
                locationText: 'Haidilao Store Area',
                branchName: branch,
                fileSize: stat.size,
              ));
            } catch (e) {
              debugPrint('Error reading photo entity ${entity.path}: $e');
            }
          }
        }
      }

      // Sort newest photo first
      photos.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
    } catch (e) {
      debugPrint('Error loading photos from disk: $e');
    }

    return photos;
  }

  /// Filters a list of photos according to the selected filter type.
  static List<WatermarkedPhoto> filterPhotos(List<WatermarkedPhoto> photos, PhotoFilter filter) {
    final DateTime now = DateTime.now();

    switch (filter) {
      case PhotoFilter.today:
        return photos.where((p) {
          return p.dateTaken.year == now.year &&
              p.dateTaken.month == now.month &&
              p.dateTaken.day == now.day;
        }).toList();

      case PhotoFilter.thisWeek:
        final DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final DateTime beginningOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return photos.where((p) => p.dateTaken.isAfter(beginningOfWeek) || p.dateTaken.isAtSameMomentAs(beginningOfWeek)).toList();

      case PhotoFilter.thisMonth:
        return photos.where((p) {
          return p.dateTaken.year == now.year && p.dateTaken.month == now.month;
        }).toList();

      case PhotoFilter.all:
        return List.from(photos);
    }
  }

  /// Batch deletes a list of photos permanently from both local memory & phone public gallery.
  static Future<int> deletePhotos(List<WatermarkedPhoto> photosToDelete) async {
    int deletedCount = 0;
    for (var photo in photosToDelete) {
      try {
        final String filename = photo.path.split(Platform.pathSeparator).last;

        // 1. Delete physical file in public Pictures album locations
        final List<String> possiblePublicPaths = [
          '/storage/emulated/0/Pictures/HaidilaoCamera/$filename',
          '/storage/emulated/0/Pictures/Haidilao Camera/$filename',
          '/storage/emulated/0/Pictures/HI CAM/$filename',
        ];

        for (var pPath in possiblePublicPaths) {
          final File pubFile = File(pPath);
          if (pubFile.existsSync()) {
            try {
              await pubFile.delete();
            } catch (e) {
              debugPrint('Error deleting public file $pPath: $e');
            }
          }
        }

        // 2. Delete main physical file from disk
        final File file = File(photo.path);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        } else {
          deletedCount++;
        }

        // 3. Delete companion video thumbnail if exists
        if (photo.isVideo) {
          final File thumbFile = photo.thumbnailFile;
          if (thumbFile.path != photo.path && await thumbFile.exists()) {
            try {
              await thumbFile.delete();
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Failed to delete file ${photo.path}: $e');
      }
    }
    return deletedCount;
  }
}
