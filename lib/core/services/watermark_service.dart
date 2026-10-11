import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:haidilao_cam/core/services/locale_service.dart';

class WatermarkService {
  /// Processes captured image file bytes and bakes the exact TimeMark layout into the final photo.
  /// Uses native Flutter ui.Canvas & TextPainter to guarantee 100% vector-precise match
  /// with the live camera screen preview layout.
  static Future<File?> applyWatermarkAndSave({
    required File imageFile,
    required String locationText,
    double? targetAspectRatio,
    double viewfinderWidth = 390.0,
    double? latitude,
    double? longitude,
    String logoAssetPath = 'assets/images/haidilao_logo.png',
    bool saveToPublicGallery = true,
  }) async {
    try {
      final Uint8List rawBytes = await imageFile.readAsBytes();

      // Load camera photo into native ui.Image directly via C++ Skia engine (ultra fast)
      final ui.Codec codec = await ui.instantiateImageCodec(rawBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image photoUiImage = frameInfo.image;

      final double originalW = photoUiImage.width.toDouble();
      final double originalH = photoUiImage.height.toDouble();

      final double aspect = (targetAspectRatio != null && targetAspectRatio > 0)
          ? targetAspectRatio
          : (originalW / originalH);

      // Target high-resolution canvas size matching target aspect ratio exactly
      final double outW = originalW;
      final double outH = outW / aspect;

      // Calculate BoxFit.cover source crop rect from raw photo
      final double rawAspect = originalW / originalH;
      double srcW = originalW;
      double srcH = originalH;
      double srcX = 0;
      double srcY = 0;

      if (rawAspect > aspect) {
        // Raw photo is wider than target aspect ratio -> crop width (left & right)
        srcW = originalH * aspect;
        srcX = (originalW - srcW) / 2.0;
      } else {
        // Raw photo is taller than target aspect ratio -> crop height (top & bottom)
        srcH = originalW / aspect;
        srcY = (originalH - srcH) / 2.0;
      }

      final Rect srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);
      final Rect dstRect = Rect.fromLTWH(0, 0, outW, outH);

      // 3. Setup ui.Canvas & PictureRecorder
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder, dstRect);

      // Draw cropped camera photo on canvas
      canvas.drawImageRect(photoUiImage, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.high);

      // 4. Calculate scale factor relative to viewfinder screen width
      final double scale = outW / (viewfinderWidth > 0 ? viewfinderWidth : 390.0);

      // Layout constants matching CameraScreen preview 1:1
      final double marginL = 16.0 * scale;
      final double marginB = 24.0 * scale;
      bool isStandardLogo = logoAssetPath == 'assets/images/haidilao_logo.png';
      final double logoTargetHeight = isStandardLogo ? (54.0 * scale) : (120.0 * scale);
      final double rightConstraintWidth = (viewfinderWidth - 16.0 - 74.0) * scale;

      final DateTime now = DateTime.now();
      final String timeStr = DateFormat('HH:mm').format(now);
      final String dateStr = DateFormat('dd/MM/yyyy').format(now);
      final String dayStr = LocaleService.dayName(now);

      // Prepare Address Painter
      final TextPainter addressPainter = TextPainter(
        text: TextSpan(
          text: locationText,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12.0 * scale,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 5.0 * scale, color: Colors.black),
              Shadow(offset: Offset(-1.0 * scale, -1.0 * scale), blurRadius: 5.0 * scale, color: Colors.black),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 3,
      );
      addressPainter.layout(maxWidth: rightConstraintWidth > 100 ? rightConstraintWidth : (outW * 0.7));

      // Prepare Time Painter
      final TextPainter timePainter = TextPainter(
        text: TextSpan(
          text: timeStr,
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: 38.0 * scale,
            fontWeight: FontWeight.bold,
            letterSpacing: -1.0 * scale,
            height: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 5.0 * scale, color: Colors.black54),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      timePainter.layout();

      // Prepare Date Painter
      final TextPainter datePainter = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: 13.0 * scale,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 4.0 * scale, color: Colors.black54),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      datePainter.layout();

      // Prepare Day Painter
      final TextPainter dayPainter = TextPainter(
        text: TextSpan(
          text: dayStr,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12.0 * scale,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 4.0 * scale, color: Colors.black54),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      dayPainter.layout();

      // Prepare Haidilao Logo Image
      ui.Image? logoUiImage;
      double logoW = logoTargetHeight * 1.5;
      try {
        final ByteData logoData = await rootBundle.load(logoAssetPath);
        final ui.Codec logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
        final ui.FrameInfo logoFrame = await logoCodec.getNextFrame();
        logoUiImage = logoFrame.image;
        logoW = logoUiImage.width.toDouble() * (logoTargetHeight / logoUiImage.height.toDouble());
      } catch (logoErr) {
        debugPrint('Logo load error: $logoErr');
      }

      // Calculate vertical Y offsets from canvas bottom (matching Column layout)
      final double addressY = outH - marginB - addressPainter.height;
      final double dateTimeBlockHeight = timePainter.height > (datePainter.height + 2.0 * scale + dayPainter.height)
          ? timePainter.height
          : (datePainter.height + 2.0 * scale + dayPainter.height);

      final double timeDateY = addressY - (4.0 * scale) - dateTimeBlockHeight;
      final double logoY = timeDateY - (6.0 * scale) - logoTargetHeight;

      // 5. Draw Watermark Components on Canvas
      // Draw Logo
      if (logoUiImage != null) {
        canvas.drawImageRect(
          logoUiImage,
          Rect.fromLTWH(0, 0, logoUiImage.width.toDouble(), logoUiImage.height.toDouble()),
          Rect.fromLTWH(marginL, logoY, logoW, logoTargetHeight),
          Paint()..filterQuality = ui.FilterQuality.high,
        );
      }

      // Draw Time
      timePainter.paint(canvas, Offset(marginL, timeDateY));

      // Draw Vertical Line Divider |
      final double dividerX = marginL + timePainter.width + (8.0 * scale);
      final double dividerY = timeDateY + (4.0 * scale);
      final double dividerH = 30.0 * scale;
      canvas.drawRect(
        Rect.fromLTWH(dividerX, dividerY, 1.5 * scale, dividerH),
        Paint()..color = Colors.white.withOpacity(0.8),
      );

      // Draw Date & Day
      final double dateX = dividerX + (1.5 * scale) + (8.0 * scale);
      final double dateY = timeDateY + (2.0 * scale);
      datePainter.paint(canvas, Offset(dateX, dateY));

      final double dayY = dateY + datePainter.height + (2.0 * scale);
      dayPainter.paint(canvas, Offset(dateX, dayY));

      // Draw Address
      addressPainter.paint(canvas, Offset(marginL, addressY));

      // 6. Render Picture to Image -> PNG Bytes
      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalUiImage = await picture.toImage(outW.toInt(), outH.toInt());
      final ByteData? pngBytes = await finalUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes == null) return null;
      final Uint8List finalBytes = pngBytes.buffer.asUint8List();

      // 7. Save file to app local storage directory
      final Directory targetDir = await getHaidilaoCameraDirectory();
      final String fileName = 'HDL_${DateFormat('yyyyMMdd_HHmm').format(now)}_${now.millisecond}.png';
      final String targetPath = p.join(targetDir.path, fileName);

      final File savedFile = File(targetPath);
      await savedFile.writeAsBytes(finalBytes);

      debugPrint('Saved 100% screen-matched vector watermarked photo to: $targetPath');

      // 8. Save image to device public gallery via Gal package
      if (saveToPublicGallery) {
        try {
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }
          await Gal.putImage(savedFile.path, album: 'Haidilao Camera');
          debugPrint('Successfully saved watermarked photo to device gallery (Gal)');
        } catch (galError) {
          debugPrint('Gal save notification: $galError');
        }
      }

      return savedFile;
    } catch (e) {
      debugPrint('Error applying watermark: $e');
      return null;
    }
  }

  /// Generates a transparent PNG image containing ONLY the watermark layer,
  /// perfectly scaled to [targetWidth] x [targetHeight] matching the live camera viewfinder.
  static Future<File?> generateTransparentWatermarkPng({
    required double targetWidth,
    required double targetHeight,
    required String locationText,
    double viewfinderWidth = 390.0,
    String logoAssetPath = 'assets/images/haidilao_logo.png',
    DateTime? customDateTime,
  }) async {
    try {
      final double outW = targetWidth;
      final double outH = targetHeight;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

      // Calculate scale factor relative to viewfinder screen width, reduced slightly for video
      final double scale = (outW / (viewfinderWidth > 0 ? viewfinderWidth : 390.0)) * 0.85;

      final double marginL = 32.0 * scale;
      final double marginB = 44.0 * scale;
      final bool isStandardLogo = logoAssetPath == 'assets/images/haidilao_logo.png';
      final double logoTargetHeight = isStandardLogo ? (54.0 * scale) : (120.0 * scale);
      final double rightConstraintWidth = (viewfinderWidth - 32.0 - 60.0) * scale;

      final DateTime now = customDateTime ?? DateTime.now();
      final String timeStr = DateFormat('HH:mm').format(now);
      final String dateStr = DateFormat('dd/MM/yyyy').format(now);
      final String dayStr = LocaleService.dayName(now);

      // Prepare Address Painter
      final TextPainter addressPainter = TextPainter(
        text: TextSpan(
          text: locationText,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12.0 * scale,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 5.0 * scale, color: Colors.black),
              Shadow(offset: Offset(-1.0 * scale, -1.0 * scale), blurRadius: 5.0 * scale, color: Colors.black),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 3,
      );
      addressPainter.layout(maxWidth: rightConstraintWidth > 100 ? rightConstraintWidth : (outW * 0.7));

      // Prepare Time Painter
      final TextPainter timePainter = TextPainter(
        text: TextSpan(
          text: timeStr,
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: 38.0 * scale,
            fontWeight: FontWeight.bold,
            letterSpacing: -1.0 * scale,
            height: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 5.0 * scale, color: Colors.black54),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      timePainter.layout();

      // Prepare Date Painter
      final TextPainter datePainter = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: 13.0 * scale,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 4.0 * scale, color: Colors.black54),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      datePainter.layout();

      // Prepare Day Painter
      final TextPainter dayPainter = TextPainter(
        text: TextSpan(
          text: dayStr,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12.0 * scale,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(1.0 * scale, 1.0 * scale), blurRadius: 4.0 * scale, color: Colors.black54),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      dayPainter.layout();

      // Prepare Logo Image
      ui.Image? logoUiImage;
      double logoW = logoTargetHeight * 1.5;
      try {
        final ByteData logoData = await rootBundle.load(logoAssetPath);
        final ui.Codec logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
        final ui.FrameInfo logoFrame = await logoCodec.getNextFrame();
        logoUiImage = logoFrame.image;
        logoW = logoUiImage.width.toDouble() * (logoTargetHeight / logoUiImage.height.toDouble());
      } catch (logoErr) {
        debugPrint('Logo load error: $logoErr');
      }

      // Vertical layout offsets from bottom
      final double addressY = outH - marginB - addressPainter.height;
      final double dateTimeBlockHeight = timePainter.height > (datePainter.height + 2.0 * scale + dayPainter.height)
          ? timePainter.height
          : (datePainter.height + 2.0 * scale + dayPainter.height);

      final double timeDateY = addressY - (4.0 * scale) - dateTimeBlockHeight;
      final double logoY = timeDateY - (6.0 * scale) - logoTargetHeight;

      // Draw Logo
      if (logoUiImage != null) {
        canvas.drawImageRect(
          logoUiImage,
          Rect.fromLTWH(0, 0, logoUiImage.width.toDouble(), logoUiImage.height.toDouble()),
          Rect.fromLTWH(marginL, logoY, logoW, logoTargetHeight),
          Paint()..filterQuality = ui.FilterQuality.high,
        );
      }

      // Draw Time
      timePainter.paint(canvas, Offset(marginL, timeDateY));

      // Draw Vertical Line Divider
      final double dividerX = marginL + timePainter.width + (8.0 * scale);
      final double dividerY = timeDateY + (4.0 * scale);
      final double dividerH = 30.0 * scale;
      canvas.drawRect(
        Rect.fromLTWH(dividerX, dividerY, 1.5 * scale, dividerH),
        Paint()..color = Colors.white.withOpacity(0.8),
      );

      // Draw Date & Day
      final double dateX = dividerX + (1.5 * scale) + (8.0 * scale);
      final double dateY = timeDateY + (2.0 * scale);
      datePainter.paint(canvas, Offset(dateX, dateY));

      final double dayY = dateY + datePainter.height + (2.0 * scale);
      dayPainter.paint(canvas, Offset(dateX, dayY));

      // Draw Address
      addressPainter.paint(canvas, Offset(marginL, addressY));

      // Render to Image -> PNG
      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalUiImage = await picture.toImage(outW.toInt(), outH.toInt());
      final ByteData? pngBytes = await finalUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes == null) return null;

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = p.join(tempDir.path, 'video_wm_${DateTime.now().millisecondsSinceEpoch}.png');
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(pngBytes.buffer.asUint8List());

      return tempFile;
    } catch (e) {
      debugPrint('Error generating transparent watermark PNG: $e');
      return null;
    }
  }

  /// Get dedicated local directory for storing Haidilao Camera photos.
  static Future<Directory> getHaidilaoCameraDirectory() async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory();
      final Directory publicPictures = Directory('/storage/emulated/0/Pictures/HaidilaoCamera');
      try {
        if (!publicPictures.existsSync()) {
          publicPictures.createSync(recursive: true);
        }
        return publicPictures;
      } catch (_) {
        // Fallback to app external storage pictures
      }
    }

    baseDir ??= await getApplicationDocumentsDirectory();
    final Directory haidilaoDir = Directory(p.join(baseDir.path, 'HaidilaoCamera'));
    if (!haidilaoDir.existsSync()) {
      haidilaoDir.createSync(recursive: true);
    }
    return haidilaoDir;
  }
}
