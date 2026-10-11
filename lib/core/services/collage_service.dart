import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haidilao_cam/core/models/photo_crop_data.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';
import 'package:haidilao_cam/core/services/watermark_service.dart';
import 'package:image/image.dart' as img;
import 'package:easy_localization/easy_localization.dart';
import 'package:haidilao_cam/core/services/locale_service.dart';
import 'package:path/path.dart' as p;

enum CollageTemplateType {
  col1Vertical, // 1 Kolom Memanjang
  col2Vertical, // 2 Kolom Memanjang
  col3Vertical, // 3 Kolom Memanjang
  col4Vertical, // 4 Kolom Memanjang
}

extension CollageTemplateTypeExtension on CollageTemplateType {
  String get shortTitle {
    switch (this) {
      case CollageTemplateType.col1Vertical:
        return 'collage.col_1_short'.trSafe();
      case CollageTemplateType.col2Vertical:
        return 'collage.col_2_short'.trSafe();
      case CollageTemplateType.col3Vertical:
        return 'collage.col_3_short'.trSafe();
      case CollageTemplateType.col4Vertical:
        return 'collage.col_4_short'.trSafe();
    }
  }

  String get title {
    switch (this) {
      case CollageTemplateType.col1Vertical:
        return 'collage.col_1_title'.trSafe();
      case CollageTemplateType.col2Vertical:
        return 'collage.col_2_title'.trSafe();
      case CollageTemplateType.col3Vertical:
        return 'collage.col_3_title'.trSafe();
      case CollageTemplateType.col4Vertical:
        return 'collage.col_4_title'.trSafe();
    }
  }

  String get description {
    switch (this) {
      case CollageTemplateType.col1Vertical:
        return 'collage.col_1_desc'.trSafe();
      case CollageTemplateType.col2Vertical:
        return 'collage.col_2_desc'.trSafe();
      case CollageTemplateType.col3Vertical:
        return 'collage.col_3_desc'.trSafe();
      case CollageTemplateType.col4Vertical:
        return 'collage.col_4_desc'.trSafe();
    }
  }

  IconData get icon {
    switch (this) {
      case CollageTemplateType.col1Vertical:
        return Icons.view_stream_rounded;
      case CollageTemplateType.col2Vertical:
        return Icons.grid_view_rounded;
      case CollageTemplateType.col3Vertical:
        return Icons.grid_on_rounded;
      case CollageTemplateType.col4Vertical:
        return Icons.view_comfy_rounded;
    }
  }

  int get crossAxisCount {
    switch (this) {
      case CollageTemplateType.col1Vertical:
        return 1;
      case CollageTemplateType.col2Vertical:
        return 2;
      case CollageTemplateType.col3Vertical:
        return 3;
      case CollageTemplateType.col4Vertical:
        return 4;
    }
  }
}

class CollageService {
  /// Generates a high-resolution compiled collage image file from selected photos.
  static Future<File?> generateCollage({
    required List<WatermarkedPhoto> photos,
    required CollageTemplateType templateType,
    PhotoSizeMode photoSizeMode = PhotoSizeMode.fullSize,
    Map<String, PhotoCropData>? photoCrops,
    Map<int, String>? rowNotes,
    String titleText = 'JUDUL',
    String subtitleText = 'SUB JUDUL',
    String descriptionText = 'DESKRIPSI',
    double titleFontSize = 44.0,
    double subtitleFontSize = 28.0,
    double descriptionFontSize = 20.0,
    bool showSubtitle = true,
    bool showDescription = true,
    bool showHeader = true,
    bool showFooter = true,
    double spacing = 12.0,
    bool isDarkMode = true,
  }) async {
    if (photos.isEmpty) return null;

    final Color backgroundColor = isDarkMode ? const Color(0xFF141414) : const Color(0xFFF5F5F7);
    final Color borderColor = isDarkMode ? const Color(0xFFC8102E) : const Color(0xFFD1D1D6);

    try {
      // 1. Load all upright ui.Images
      final List<ui.Image> loadedUiImages = [];
      final List<WatermarkedPhoto> validPhotos = [];

      for (var photo in photos) {
        final File file = File(photo.path);
        if (!file.existsSync()) continue;

        final Uint8List rawBytes = await file.readAsBytes();
        img.Image? decoded = img.decodeImage(rawBytes);
        if (decoded != null) {
          decoded = img.bakeOrientation(decoded);
          final Uint8List orientedJpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
          final ui.Codec codec = await ui.instantiateImageCodec(orientedJpg);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          loadedUiImages.add(frameInfo.image);
          validPhotos.add(photo);
        }
      }

      if (loadedUiImages.isEmpty) return null;

      // Load Haidilao Photographer Panda Mascot Image
      ui.Image? pandaUiImage;
      try {
        final ByteData pandaData = await rootBundle.load('assets/images/haidilao_panda.png');
        final Uint8List pandaBytes = pandaData.buffer.asUint8List();
        final ui.Codec pandaCodec = await ui.instantiateImageCodec(pandaBytes);
        final ui.FrameInfo pandaFrame = await pandaCodec.getNextFrame();
        pandaUiImage = pandaFrame.image;
      } catch (e) {
        try {
          final File pandaFile = File('assets/images/haidilao_panda.png');
          if (pandaFile.existsSync()) {
            final Uint8List pandaBytes = await pandaFile.readAsBytes();
            final ui.Codec pandaCodec = await ui.instantiateImageCodec(pandaBytes);
            final ui.FrameInfo pandaFrame = await pandaCodec.getNextFrame();
            pandaUiImage = pandaFrame.image;
          }
        } catch (err) {
          debugPrint('Error loading panda asset: $err');
        }
      }

      // 2. Render Collage according to selected Vertical Template Types (1 to 4 Columns)
      ui.Image collageImage;
      if (templateType == CollageTemplateType.col1Vertical) {
        collageImage = await _renderContinuousVertical(
          images: loadedUiImages,
          photos: validPhotos,
          photoSizeMode: photoSizeMode,
          photoCrops: photoCrops,
          rowNotes: rowNotes,
          titleText: titleText,
          subtitleText: subtitleText,
          descriptionText: descriptionText,
          titleFontSize: titleFontSize,
          subtitleFontSize: subtitleFontSize,
          descriptionFontSize: descriptionFontSize,
          showSubtitle: showSubtitle,
          showDescription: showDescription,
          showHeader: showHeader,
          showFooter: showFooter,
          spacing: spacing,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          isDarkMode: isDarkMode,
          pandaImage: pandaUiImage,
        );
      } else {
        final int crossCount = templateType.crossAxisCount;

        collageImage = await _renderGrid(
          images: loadedUiImages,
          photos: validPhotos,
          crossAxisCount: crossCount,
          photoSizeMode: photoSizeMode,
          photoCrops: photoCrops,
          rowNotes: rowNotes,
          titleText: titleText,
          subtitleText: subtitleText,
          descriptionText: descriptionText,
          titleFontSize: titleFontSize,
          subtitleFontSize: subtitleFontSize,
          descriptionFontSize: descriptionFontSize,
          showSubtitle: showSubtitle,
          showDescription: showDescription,
          showHeader: showHeader,
          showFooter: showFooter,
          spacing: spacing,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          isDarkMode: isDarkMode,
          pandaImage: pandaUiImage,
        );
      }

      // Convert ui.Image to bytes & encode high-quality JPG for optimal gallery scrolling & compatibility
      final ByteData? pngBytes = await collageImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) return null;

      final Uint8List rawPng = pngBytes.buffer.asUint8List();
      final img.Image? decodedCanvas = img.decodePng(rawPng);
      final Uint8List finalJpgBytes = decodedCanvas != null
          ? Uint8List.fromList(img.encodeJpg(decodedCanvas, quality: 92))
          : rawPng;

      // 3. Save Collage File to Disk (.jpg format for scrollable tall photos)
      final Directory targetDir = await WatermarkService.getHaidilaoCameraDirectory();
      final DateTime now = DateTime.now();
      final String fileName = 'HDL_KOLASE_${DateFormat('yyyyMMdd_HHmm').format(now)}_${now.millisecond}.jpg';
      final String targetPath = p.join(targetDir.path, fileName);

      final File savedFile = File(targetPath);
      await savedFile.writeAsBytes(finalJpgBytes);

      // Save to device public gallery via Gal package
      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(savedFile.path, album: 'Haidilao Camera');
      } catch (galError) {
        debugPrint('Gal save notification collage: $galError');
      }

      return savedFile;
    } catch (e) {
      debugPrint('Error generating collage: $e');
      return null;
    }
  }

  /// Calculates dynamic header height based on text content and custom font sizes
  static double _calculateHeaderHeight({
    required String title,
    required String subtitle,
    required String description,
    required double titleFontSize,
    required double subtitleFontSize,
    required double descriptionFontSize,
    bool showSubtitle = true,
    bool showDescription = true,
    required double width,
  }) {
    double calcH = 40.0;
    const double textMaxWidth = 630.0; // Left side text width leaving ~400px for panda

    if (title.isNotEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title.toUpperCase(),
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: textMaxWidth);
      calcH += titlePainter.height + 14.0;
    }

    if (showSubtitle && subtitle.isNotEmpty) {
      final subPainter = TextPainter(
        text: TextSpan(
          text: subtitle.toUpperCase(),
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: textMaxWidth);
      calcH += subPainter.height + 14.0;
    }

    if (showDescription && description.isNotEmpty) {
      final descPainter = TextPainter(
        text: TextSpan(
          text: description.toUpperCase(),
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: descriptionFontSize,
            height: 1.25,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: textMaxWidth);
      calcH += descPainter.height + 16.0;
    }

    calcH += 125.0; // Metadata info lines (Date & Total Photos) & bottom gap
    return calcH < 410.0 ? 410.0 : calcH;
  }

  /// Template: Continuous Vertical Collage (1-Kolom Panjang Kebawah)
  static Future<ui.Image> _renderContinuousVertical({
    required List<ui.Image> images,
    required List<WatermarkedPhoto> photos,
    required PhotoSizeMode photoSizeMode,
    Map<String, PhotoCropData>? photoCrops,
    Map<int, String>? rowNotes,
    required String titleText,
    required String subtitleText,
    required String descriptionText,
    required double titleFontSize,
    required double subtitleFontSize,
    required double descriptionFontSize,
    bool showSubtitle = true,
    bool showDescription = true,
    required bool showHeader,
    required bool showFooter,
    required double spacing,
    required Color backgroundColor,
    required Color borderColor,
    required bool isDarkMode,
    ui.Image? pandaImage,
  }) async {
    const double canvasW = 1080.0;
    final double padding = spacing;

    final double headerH = showHeader
        ? _calculateHeaderHeight(
            title: titleText,
            subtitle: subtitleText,
            description: descriptionText,
            titleFontSize: titleFontSize,
            subtitleFontSize: subtitleFontSize,
            descriptionFontSize: descriptionFontSize,
            showSubtitle: showSubtitle,
            showDescription: showDescription,
            width: canvasW,
          )
        : 0.0;
    final double footerH = showFooter ? 120.0 : 0.0;

    double totalPhotosH = 0.0;
    final List<double> itemHeights = [];
    final List<Rect> photoSrcRects = [];

    for (int i = 0; i < images.length; i++) {
      final imgItem = images[i];
      final photo = photos[i];
      final crop = photoCrops?[photo.id] ?? const PhotoCropData();

      final double imgW = imgItem.width.toDouble();
      final double imgH = imgItem.height.toDouble();

      Rect srcRect;
      if (photoSizeMode == PhotoSizeMode.square && crop.isDefault) {
        if (imgW > imgH) {
          final double l = (imgW - imgH) / 2.0;
          srcRect = Rect.fromLTWH(l, 0, imgH, imgH);
        } else {
          final double t = (imgH - imgW) / 2.0;
          srcRect = Rect.fromLTWH(0, t, imgW, imgW);
        }
      } else {
        srcRect = crop.toRect(imgW, imgH);
      }

      photoSrcRects.add(srcRect);

      final double availableW = canvasW - (padding * 2);
      final double calcH = photoSizeMode == PhotoSizeMode.square
          ? availableW
          : availableW / (srcRect.width / srcRect.height);

      itemHeights.add(calcH);

      final String? note = rowNotes?[i];
      if (note != null && note.trim().isNotEmpty) {
        totalPhotosH += calcH + spacing;
        final double noteW = canvasW - (padding * 2);
        final double noteH = _calculateRowNoteHeight(text: note, width: noteW);
        totalPhotosH += noteH + spacing;
      } else {
        totalPhotosH += calcH + 6.0; // Mepet gap when no note is present
      }
    }

    final double canvasH = headerH + padding + totalPhotosH + footerH;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    canvas.drawRect(Rect.fromLTWH(0, 0, canvasW, canvasH), Paint()..color = backgroundColor);

    double currentY = 0.0;

    if (showHeader) {
      currentY += _drawHeaderBanner(
        canvas: canvas,
        width: canvasW,
        height: headerH,
        title: titleText,
        subtitle: subtitleText,
        description: descriptionText,
        titleFontSize: titleFontSize,
        subtitleFontSize: subtitleFontSize,
        descriptionFontSize: descriptionFontSize,
        showSubtitle: showSubtitle,
        showDescription: showDescription,
        photoCount: images.length,
        tag: '1 KOLOM MEMANJANG',
        isDarkMode: isDarkMode,
        pandaImage: pandaImage,
      );
    } else {
      currentY += padding;
    }

    for (int i = 0; i < images.length; i++) {
      final imgItem = images[i];
      final itemH = itemHeights[i];
      final double itemW = canvasW - (padding * 2);

      final Rect dstRect = Rect.fromLTWH(padding, currentY, itemW, itemH);
      final Rect srcRect = photoSrcRects[i];

      canvas.drawImageRect(imgItem, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.high);

      if (borderColor != Colors.transparent) {
        canvas.drawRect(
          dstRect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0,
        );
      }

      final String? note = rowNotes?[i];
      if (note != null && note.trim().isNotEmpty) {
        currentY += itemH + spacing;
        final double noteW = canvasW - (padding * 2);
        _drawRowNoteBox(
          canvas: canvas,
          text: note,
          x: padding,
          y: currentY - spacing / 2.0,
          width: noteW,
          isDarkMode: isDarkMode,
        );
        final double noteH = _calculateRowNoteHeight(text: note, width: noteW);
        currentY += noteH + spacing;
      } else {
        currentY += itemH + 6.0; // Mepet gap when no note is present
      }
    }

    if (showFooter) {
      _drawFooterBanner(canvas, canvasW, canvasH - footerH, footerH, isDarkMode);
    }

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(canvasW.toInt(), canvasH.toInt());
  }

  /// Template: Grid Collage (1-Kolom / 2-Kolom / 3-Kolom / 4-Kolom Memanjang Kebawah)
  static Future<ui.Image> _renderGrid({
    required List<ui.Image> images,
    required List<WatermarkedPhoto> photos,
    required int crossAxisCount,
    required PhotoSizeMode photoSizeMode,
    Map<String, PhotoCropData>? photoCrops,
    Map<int, String>? rowNotes,
    required String titleText,
    required String subtitleText,
    required String descriptionText,
    required double titleFontSize,
    required double subtitleFontSize,
    required double descriptionFontSize,
    bool showSubtitle = true,
    bool showDescription = true,
    required bool showHeader,
    required bool showFooter,
    required double spacing,
    required Color backgroundColor,
    required Color borderColor,
    required bool isDarkMode,
    ui.Image? pandaImage,
  }) async {
    const double canvasW = 1080.0;
    final double padding = spacing;

    final double headerH = showHeader
        ? _calculateHeaderHeight(
            title: titleText,
            subtitle: subtitleText,
            description: descriptionText,
            titleFontSize: titleFontSize,
            subtitleFontSize: subtitleFontSize,
            descriptionFontSize: descriptionFontSize,
            showSubtitle: showSubtitle,
            showDescription: showDescription,
            width: canvasW,
          )
        : 0.0;
    final double footerH = showFooter ? 120.0 : 0.0;

    final double availableW = canvasW - (padding * (crossAxisCount + 1));
    final double columnW = availableW / crossAxisCount;

    final double startY = showHeader ? headerH + padding : padding;

    final int totalPhotos = images.length;
    final int numRows = (totalPhotos / crossAxisCount).ceil();

    final List<Rect> photoDstRects = List.filled(totalPhotos, Rect.zero);
    final List<Rect> photoSrcRects = List.filled(totalPhotos, Rect.zero);
    final List<double> rowYPositions = [];

    double currentY = startY;

    for (int r = 0; r < numRows; r++) {
      rowYPositions.add(currentY);
      final int startIdx = r * crossAxisCount;
      final int endIdx = (startIdx + crossAxisCount < totalPhotos) ? startIdx + crossAxisCount : totalPhotos;

      double maxRowH = 0.0;
      for (int i = startIdx; i < endIdx; i++) {
        final imgItem = images[i];
        final photo = photos[i];
        final crop = photoCrops?[photo.id] ?? const PhotoCropData();

        final double imgW = imgItem.width.toDouble();
        final double imgH = imgItem.height.toDouble();

        Rect srcRect;
        if (photoSizeMode == PhotoSizeMode.square && crop.isDefault) {
          if (imgW > imgH) {
            final double l = (imgW - imgH) / 2.0;
            srcRect = Rect.fromLTWH(l, 0, imgH, imgH);
          } else {
            final double t = (imgH - imgW) / 2.0;
            srcRect = Rect.fromLTWH(0, t, imgW, imgW);
          }
        } else {
          srcRect = crop.toRect(imgW, imgH);
        }

        photoSrcRects[i] = srcRect;

        final double calcH = photoSizeMode == PhotoSizeMode.square
            ? columnW
            : columnW / (srcRect.width / srcRect.height);

        if (calcH > maxRowH) maxRowH = calcH;
      }

      for (int i = startIdx; i < endIdx; i++) {
        final int col = i % crossAxisCount;
        final double posX = padding + (col * (columnW + padding));
        photoDstRects[i] = Rect.fromLTWH(posX, currentY, columnW, maxRowH);
      }

      currentY += maxRowH + spacing;

      final String? note = rowNotes?[r];
      if (note != null && note.trim().isNotEmpty) {
        final double noteW = canvasW - (padding * 2);
        final double noteH = _calculateRowNoteHeight(text: note, width: noteW);
        currentY += noteH + spacing;
      }
    }

    final double canvasH = currentY + footerH;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    canvas.drawRect(Rect.fromLTWH(0, 0, canvasW, canvasH), Paint()..color = backgroundColor);

    if (showHeader) {
      _drawHeaderBanner(
        canvas: canvas,
        width: canvasW,
        height: headerH,
        title: titleText,
        subtitle: subtitleText,
        description: descriptionText,
        titleFontSize: titleFontSize,
        subtitleFontSize: subtitleFontSize,
        descriptionFontSize: descriptionFontSize,
        showSubtitle: showSubtitle,
        showDescription: showDescription,
        photoCount: images.length,
        tag: '$crossAxisCount KOLOM MEMANJANG',
        isDarkMode: isDarkMode,
        pandaImage: pandaImage,
      );
    }

    for (int i = 0; i < images.length; i++) {
      final imgItem = images[i];
      final Rect dstRect = photoDstRects[i];
      final Rect srcRect = photoSrcRects[i];

      canvas.drawImageRect(imgItem, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.high);

      if (borderColor != Colors.transparent) {
        canvas.drawRect(
          dstRect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0,
        );
      }
    }

    // Draw Row Notes
    for (int r = 0; r < numRows; r++) {
      final String? note = rowNotes?[r];
      if (note != null && note.trim().isNotEmpty) {
        final int startIdx = r * crossAxisCount;
        final double maxRowH = photoDstRects[startIdx].height;
        final double noteY = rowYPositions[r] + maxRowH + spacing / 2;
        final double noteW = canvasW - (padding * 2);

        _drawRowNoteBox(
          canvas: canvas,
          text: note,
          x: padding,
          y: noteY,
          width: noteW,
          isDarkMode: isDarkMode,
        );
      }
    }

    if (showFooter) {
      _drawFooterBanner(canvas, canvasW, canvasH - footerH, footerH, isDarkMode);
    }

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(canvasW.toInt(), canvasH.toInt());
  }

  /// Calculates height required for a row note box
  static double _calculateRowNoteHeight({required String text, required double width}) {
    if (text.trim().isEmpty) return 0.0;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text.trim(),
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          height: 1.35,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: ui.TextAlign.center,
      maxLines: 6,
    );
    textPainter.layout(maxWidth: width - 36.0);
    return textPainter.height + 28.0;
  }

  /// Draws a styled row note box on the canvas
  static double _drawRowNoteBox({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double width,
    required bool isDarkMode,
  }) {
    if (text.trim().isEmpty) return 0.0;

    final Color bgColor = isDarkMode ? const Color(0xFF26262A) : const Color(0xFFF3F3F7);
    final Color textColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF111111);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text.trim(),
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: textColor,
          height: 1.35,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: ui.TextAlign.center,
      maxLines: 6,
    );

    textPainter.layout(maxWidth: width - 36.0);

    final double boxH = textPainter.height + 28.0;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, boxH),
      const Radius.circular(10.0),
    );

    canvas.drawRRect(rrect, Paint()..color = bgColor);

    textPainter.paint(
      canvas,
      Offset(x + (width - textPainter.width) / 2.0, y + 14.0),
    );

    return boxH;
  }

  /// Draws Header Banner (Left-aligned text + Right side Haidilao Photographer Panda Mascot)
  static double _drawHeaderBanner({
    required Canvas canvas,
    required double width,
    required double height,
    required String title,
    required String subtitle,
    required String description,
    required double titleFontSize,
    required double subtitleFontSize,
    required double descriptionFontSize,
    bool showSubtitle = true,
    bool showDescription = true,
    required int photoCount,
    required String tag,
    required bool isDarkMode,
    ui.Image? pandaImage,
  }) {
    final List<Color> bgColors = isDarkMode
        ? [const Color(0xFF7A141E), const Color(0xFF38070D)]
        : [const Color(0xFFFFFFFF), const Color(0xFFF8F8FA)];

    final Paint bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(width, height),
        bgColors,
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    final Color accentLineColor = isDarkMode ? const Color(0xFFE2C474) : const Color(0xFFC8102E);
    final Color titleColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final Color subtitleColor = isDarkMode ? const Color(0xFFE2C474) : const Color(0xFFC8102E);
    final Color descriptionColor = isDarkMode ? const Color(0xFFE0E0E6) : const Color(0xFF4A4A4A);

    // Bottom Accent Line
    canvas.drawRect(Rect.fromLTWH(0, height - 4, width, 4), Paint()..color = accentLineColor);

    double currentY = 32.0;
    const double textMaxWidth = 630.0; // Left side text max width leaving room for larger mascot

    // 1. Judul Utama (Title UPPERCASE - Left Aligned)
    if (title.isNotEmpty) {
      final TextPainter titlePainter = TextPainter(
        text: TextSpan(
          text: title.toUpperCase(),
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
            color: titleColor,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: ui.TextAlign.left,
        maxLines: 2,
      );
      titlePainter.layout(maxWidth: textMaxWidth);
      titlePainter.paint(canvas, Offset(40, currentY));
      currentY += titlePainter.height + 12.0;
    }

    // 2. Sub Judul (Subtitle UPPERCASE - Left Aligned)
    if (showSubtitle && subtitle.isNotEmpty) {
      final TextPainter subtitlePainter = TextPainter(
        text: TextSpan(
          text: subtitle.toUpperCase(),
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: ui.TextAlign.left,
        maxLines: 2,
      );
      subtitlePainter.layout(maxWidth: textMaxWidth);
      subtitlePainter.paint(canvas, Offset(40, currentY));
      currentY += subtitlePainter.height + 12.0;
    }

    // 3. Deskripsi (Description UPPERCASE - Left Aligned)
    if (showDescription && description.isNotEmpty) {
      final TextPainter descPainter = TextPainter(
        text: TextSpan(
          text: description.toUpperCase(),
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: descriptionFontSize,
            fontWeight: FontWeight.w800,
            color: descriptionColor,
            height: 1.25,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: ui.TextAlign.left,
        maxLines: 3,
      );
      descPainter.layout(maxWidth: textMaxWidth);
      descPainter.paint(canvas, Offset(40, currentY));
      currentY += descPainter.height + 14.0;
    }

    // 4. Metadata Strip (2 Lines: Date above Total Photos, attached right above bottom border line)
    final String dateFormatted = LocaleService.fullDate(DateTime.now());

    final TextPainter datePainter = TextPainter(
      text: TextSpan(
        text: '📅 $dateFormatted',
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 28.0,
          fontWeight: FontWeight.w900,
          color: subtitleColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    datePainter.layout(maxWidth: textMaxWidth);

    final TextPainter photoPainter = TextPainter(
      text: TextSpan(
        text: '📷 ${LocaleService.totalPhotos(photoCount)}',
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 28.0,
          fontWeight: FontWeight.w900,
          color: subtitleColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    photoPainter.layout(maxWidth: textMaxWidth);

    final double photoY = height - 4.0 - photoPainter.height - 12.0;
    final double dateY = photoY - 8.0 - datePainter.height;

    final double minAllowedDateY = currentY + 24.0;
    final double effectiveDateY = dateY > minAllowedDateY ? dateY : minAllowedDateY;
    final double effectivePhotoY = effectiveDateY + datePainter.height + 8.0;

    datePainter.paint(canvas, Offset(40, effectiveDateY));
    photoPainter.paint(canvas, Offset(40, effectivePhotoY));

    // 5. Draw Right Side Haidilao Photographer Panda Mascot (Transparent Background)
    if (pandaImage != null) {
      const double pandaW = 380.0;
      const double pandaH = 410.0;
      final double pandaX = width - pandaW - 20.0;
      final double pandaY = (height - pandaH) / 2.0 - 8.0;

      final Rect pandaDst = Rect.fromLTWH(pandaX, pandaY > 6 ? pandaY : 6, pandaW, pandaH);
      final Rect pandaSrc = Rect.fromLTWH(0, 0, pandaImage.width.toDouble(), pandaImage.height.toDouble());

      canvas.drawImageRect(pandaImage, pandaSrc, pandaDst, Paint()..filterQuality = ui.FilterQuality.high);
    }

    return height;
  }

  /// Draws Haidilao Branding Footer Banner (Theme mode dynamic colors)
  static void _drawFooterBanner(Canvas canvas, double width, double startY, double height, bool isDarkMode) {
    final Color footerBg = isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFEBEBEF);
    final Color textColor = isDarkMode ? Colors.white60 : const Color(0xFF555555);
    final Color topAccent = isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFC8102E);

    canvas.drawRect(
      Rect.fromLTWH(0, startY, width, height),
      Paint()..color = footerBg,
    );

    // Top Accent Line
    canvas.drawRect(Rect.fromLTWH(0, startY, width, 4), Paint()..color = topAccent);

    final TextPainter footerText = TextPainter(
      text: TextSpan(
        text: 'HAIDILAO HOTPOT OFFICIAL CAMERA DOCUMENTATION SYSTEM',
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerText.layout();
    footerText.paint(canvas, Offset((width - footerText.width) / 2.0, startY + 45.0));
  }
}
