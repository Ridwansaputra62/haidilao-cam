import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:haidilao_cam/core/services/watermark_service.dart';

class VideoWatermarkService {
  static const MethodChannel _channel = MethodChannel('com.haidilao.haidilao_cam/video_watermark');

  /// Applies aspect-ratio crop and transparent watermark overlay to the recorded video,
  /// matching the live camera viewfinder frame 1:1.
  /// Saves the final video to the dedicated HaidilaoCamera directory and device gallery.
  static Future<File?> applyWatermarkAndSave({
    required File inputVideoFile,
    required String locationText,
    double targetAspectRatio = 3 / 5,
    double viewfinderWidth = 390.0,
    String logoAssetPath = 'assets/images/haidilao_logo.png',
    bool isWatermarkVisible = true,
    bool saveToPublicGallery = true,
  }) async {
    File? watermarkPngFile;
    try {
      if (!inputVideoFile.existsSync()) {
        debugPrint('Input video file does not exist: ${inputVideoFile.path}');
        return null;
      }

      // Base width for full HD portrait video
      const double outW = 1080.0;
      // Output height rounded to even integer for hardware encoder compatibility
      final double outH = ((outW / targetAspectRatio) / 2.0).round() * 2.0;

      // Generate exact transparent watermark PNG if watermark is enabled
      if (isWatermarkVisible) {
        watermarkPngFile = await WatermarkService.generateTransparentWatermarkPng(
          targetWidth: outW,
          targetHeight: outH,
          locationText: locationText,
          viewfinderWidth: viewfinderWidth > 0 ? viewfinderWidth : 390.0,
          logoAssetPath: logoAssetPath,
        );
      }

      // Output destination in HaidilaoCamera storage directory
      final Directory targetDir = await WatermarkService.getHaidilaoCameraDirectory();
      final DateTime now = DateTime.now();
      final String fileName = 'HDL_VID_${DateFormat('yyyyMMdd_HHmm').format(now)}_${now.millisecond}.mp4';
      final String targetOutputPath = p.join(targetDir.path, fileName);

      debugPrint('Processing video watermark: input=${inputVideoFile.path}, output=$targetOutputPath');

      // Call native AndroidX Media3 Transformer pipeline
      final String? resultPath = await _channel.invokeMethod<String>('applyVideoWatermark', {
        'inputPath': inputVideoFile.path,
        'outputPath': targetOutputPath,
        'watermarkPngPath': watermarkPngFile?.path,
        'targetAspectRatio': targetAspectRatio,
      });

      final String finalPath = resultPath ?? targetOutputPath;
      final File savedVideo = File(finalPath);

      if (!savedVideo.existsSync()) {
        throw Exception('Transformed video file was not created');
      }

      // Save to device public gallery via Gal package
      if (saveToPublicGallery) {
        try {
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }
          await Gal.putVideo(savedVideo.path, album: 'HI CAM');
          debugPrint('Successfully saved watermarked video to public gallery (Gal)');
        } catch (galErr) {
          debugPrint('Gal video save notification: $galErr');
        }
      }

      // Clean up raw temp video
      try {
        if (inputVideoFile.existsSync() && inputVideoFile.path != savedVideo.path) {
          await inputVideoFile.delete();
        }
      } catch (_) {}

      return savedVideo;
    } catch (e) {
      debugPrint('Video watermark error: $e. Using fallback copy.');
      try {
        // Fallback: Copy raw video to HaidilaoCamera dir so user never loses their recording
        final Directory targetDir = await WatermarkService.getHaidilaoCameraDirectory();
        final DateTime now = DateTime.now();
        final String fileName = 'HDL_VID_${DateFormat('yyyyMMdd_HHmm').format(now)}_${now.millisecond}.mp4';
        final String fallbackPath = p.join(targetDir.path, fileName);
        final File copiedFile = await inputVideoFile.copy(fallbackPath);

        if (saveToPublicGallery) {
          try {
            await Gal.putVideo(copiedFile.path, album: 'HI CAM');
          } catch (_) {}
        }

        return copiedFile;
      } catch (fallbackErr) {
        debugPrint('Fallback copy also failed: $fallbackErr');
        return null;
      }
    } finally {
      // Clean up temporary watermark PNG
      if (watermarkPngFile != null && watermarkPngFile.existsSync()) {
        try {
          await watermarkPngFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Opens the video in the default system video player using FileProvider.
  static Future<bool> openVideo(String videoPath) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('openVideo', {
        'videoPath': videoPath,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error opening video: $e');
      return false;
    }
  }
}
