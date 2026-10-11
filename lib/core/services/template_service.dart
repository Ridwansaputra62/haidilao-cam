import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haidilao_cam/core/models/template_data.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:haidilao_cam/core/services/locale_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TemplateService {
  /// Generates Blue Card (General Cleaning) report image file.
  static Future<File?> generateBlueCardImage(BlueCardData data) async {
    try {
      const double canvasWidth = 1080.0;
      final bool is3Box = data.isThreeBox;

      // 1. Load Panda Mascot Image
      ui.Image? pandaUiImage = await _loadPandaMascot();

      // 2. Load Slot Photos
      final List<ui.Image?> loadedSlotImages = [];
      for (var slot in data.slots) {
        if (slot.photo != null) {
          final File file = File(slot.photo!.path);
          if (file.existsSync()) {
            final Uint8List rawBytes = await file.readAsBytes();
            img.Image? decoded = img.decodeImage(rawBytes);
            if (decoded != null) {
              decoded = img.bakeOrientation(decoded);
              final Uint8List orientedJpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
              final ui.Codec codec = await ui.instantiateImageCodec(orientedJpg);
              final ui.FrameInfo frameInfo = await codec.getNextFrame();
              loadedSlotImages.add(frameInfo.image);
            } else {
              loadedSlotImages.add(null);
            }
          } else {
            loadedSlotImages.add(null);
          }
        } else {
          loadedSlotImages.add(null);
        }
      }

      // Ensure we have correct number of slots
      final int requiredSlotCount = is3Box ? 3 : 2;
      while (loadedSlotImages.length < requiredSlotCount) {
        loadedSlotImages.add(null);
      }

      // 3. Calculate Canvas Height
      const double headerHeight = 360.0;
      final double slotPhotoHeight = is3Box ? 560.0 : 740.0;
      const double slotSpacing = 24.0;
      final double totalPhotosHeight = (requiredSlotCount * slotPhotoHeight) + ((requiredSlotCount - 1) * slotSpacing);
      const double footerHeight = 120.0;
      const double topPadding = 30.0;
      const double bottomPadding = 30.0;

      final double totalCanvasHeight = topPadding + headerHeight + 30.0 + totalPhotosHeight + 30.0 + footerHeight + bottomPadding;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // 4. Draw Canvas Background (Rich Deep Blue Gradient for Blue Card)
      final Rect bgRect = Rect.fromLTWH(0, 0, canvasWidth, totalCanvasHeight);
      final Paint bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A192F), // Deep navy blue
            Color(0xFF102A43),
            Color(0xFF061426),
          ],
        ).createShader(bgRect);
      canvas.drawRect(bgRect, bgPaint);

      // 5. Draw Header Section
      double currentY = topPadding;
      _drawBlueCardHeader(
        canvas,
        width: canvasWidth,
        startY: currentY,
        height: headerHeight,
        data: data,
      );
      currentY += headerHeight + 30.0;

      // 6. Draw Photo Slots (2-box or 3-box vertical layout)
      const double slotMargin = 40.0;
      const double slotWidth = canvasWidth - (slotMargin * 2);

      for (int i = 0; i < requiredSlotCount; i++) {
        final String label = is3Box
            ? (i == 0 ? 'BEFORE (SEBELUM)' : (i == 1 ? 'PROSES (PROSES CLEANING)' : 'AFTER (SESUDAH)'))
            : (i == 0 ? 'BEFORE (SEBELUM)' : 'AFTER (SESUDAH)');

        final Color badgeColor = is3Box
            ? (i == 0 ? const Color(0xFFE53935) : (i == 1 ? const Color(0xFFFB8C00) : const Color(0xFF43A047)))
            : (i == 0 ? const Color(0xFFE53935) : const Color(0xFF43A047));

        final ui.Image? imgToDraw = i < loadedSlotImages.length ? loadedSlotImages[i] : null;

        _drawPhotoSlot(
          canvas,
          rect: Rect.fromLTWH(slotMargin, currentY, slotWidth, slotPhotoHeight),
          label: label,
          badgeColor: badgeColor,
          image: imgToDraw,
        );

        currentY += slotPhotoHeight + slotSpacing;
      }

      currentY += 10.0;

      // 7. Draw Footer
      _drawBlueCardFooter(
        canvas,
        width: canvasWidth,
        startY: currentY,
        height: footerHeight,
        pandaImage: pandaUiImage,
        dateText: data.dateText,
      );

      // 8. Export to Image File
      final ui.Picture picture = recorder.endRecording();
      final ui.Image renderedImage = await picture.toImage(canvasWidth.toInt(), totalCanvasHeight.toInt());
      final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'BLUE_CARD_GC_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
      final String filePath = p.join(tempDir.path, fileName);
      final File file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Save to Gallery
      try {
        await Gal.putImage(filePath);
      } catch (e) {
        debugPrint('Gal error saving Blue Card: $e');
      }

      return file;
    } catch (e) {
      debugPrint('Error generating Blue Card: $e');
      return null;
    }
  }

  /// Generates Shift Checklist (Closing / Opening) report image file.
  static Future<File?> generateShiftChecklistImage(ShiftChecklistData data) async {
    try {
      const double canvasWidth = 1080.0;

      // 1. Load Panda Mascot Image
      ui.Image? pandaUiImage = await _loadPandaMascot();

      // 2. Load Photos attached
      final List<ui.Image> loadedPhotoImages = [];
      for (var photo in data.photos) {
        final File file = File(photo.path);
        if (file.existsSync()) {
          final Uint8List rawBytes = await file.readAsBytes();
          img.Image? decoded = img.decodeImage(rawBytes);
          if (decoded != null) {
            decoded = img.bakeOrientation(decoded);
            final Uint8List orientedJpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
            final ui.Codec codec = await ui.instantiateImageCodec(orientedJpg);
            final ui.FrameInfo frameInfo = await codec.getNextFrame();
            loadedPhotoImages.add(frameInfo.image);
          }
        }
      }

      // 3. Calculate Canvas Height
      const double topPadding = 30.0;
      const double headerHeight = 320.0;
      const double sectionSpacing = 28.0;

      // Calculate Checklist Height
      const double checklistItemHeight = 64.0;
      const double checklistHeaderHeight = 70.0;
      const double checklistPadding = 40.0;
      final double checklistTotalHeight = data.items.isEmpty
          ? 120.0
          : (checklistHeaderHeight + (data.items.length * checklistItemHeight) + checklistPadding);

      // Calculate Photos Section Height (Full Uncropped 1 Column Vertical)
      const double photoHeaderHeight = 70.0;
      const double photoSpacing = 24.0;
      const double margin = 40.0;
      const double cardWidth = canvasWidth - (margin * 2);

      double photosTotalHeight = 0.0;
      if (loadedPhotoImages.isEmpty) {
        photosTotalHeight = 120.0;
      } else {
        photosTotalHeight = photoHeaderHeight;
        for (int i = 0; i < loadedPhotoImages.length; i++) {
          final img = loadedPhotoImages[i];
          final double photoH = (cardWidth / img.width) * img.height;
          photosTotalHeight += photoH;
          if (i < loadedPhotoImages.length - 1) {
            photosTotalHeight += photoSpacing;
          }
        }
        photosTotalHeight += 30.0;
      }

      const double footerHeight = 120.0;
      const double bottomPadding = 30.0;

      final double totalCanvasHeight = topPadding +
          headerHeight +
          sectionSpacing +
          checklistTotalHeight +
          sectionSpacing +
          photosTotalHeight +
          sectionSpacing +
          footerHeight +
          bottomPadding;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // 4. Draw Canvas Background (Dark Theme)
      final Rect bgRect = Rect.fromLTWH(0, 0, canvasWidth, totalCanvasHeight);
      canvas.drawRect(bgRect, Paint()..color = const Color(0xFF121212));

      // 5. Draw Header Section
      double currentY = topPadding;
      _drawShiftHeader(
        canvas,
        width: canvasWidth,
        startY: currentY,
        height: headerHeight,
        data: data,
      );
      currentY += headerHeight + sectionSpacing;

      // 6. Draw Checklist Section (Directly below Header!)
      _drawChecklistSection(
        canvas,
        width: canvasWidth,
        startY: currentY,
        height: checklistTotalHeight,
        items: data.items,
      );
      currentY += checklistTotalHeight + sectionSpacing;

      // 7. Draw Photos Section (Below Checklist!)
      _drawPhotosSection(
        canvas,
        width: canvasWidth,
        startY: currentY,
        images: loadedPhotoImages,
        photoSpacing: photoSpacing,
      );
      currentY += photosTotalHeight + sectionSpacing;

      // 8. Draw Footer
      _drawShiftFooter(
        canvas,
        width: canvasWidth,
        startY: currentY,
        height: footerHeight,
        pandaImage: pandaUiImage,
        dateText: data.dateText,
      );

      // 9. Export to Image File
      final ui.Picture picture = recorder.endRecording();
      final ui.Image renderedImage = await picture.toImage(canvasWidth.toInt(), totalCanvasHeight.toInt());
      final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'SHIFT_CHECKLIST_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
      final String filePath = p.join(tempDir.path, fileName);
      final File file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Save to Gallery
      try {
        await Gal.putImage(filePath);
      } catch (e) {
        debugPrint('Gal error saving Shift Checklist: $e');
      }

      return file;
    } catch (e) {
      debugPrint('Error generating Shift Checklist card: $e');
      return null;
    }
  }

  // --- Helper Methods ---

  static Future<ui.Image?> _loadPandaMascot() async {
    try {
      final ByteData pandaData = await rootBundle.load('assets/images/haidilao_panda.png');
      final Uint8List pandaBytes = pandaData.buffer.asUint8List();
      final ui.Codec pandaCodec = await ui.instantiateImageCodec(pandaBytes);
      final ui.FrameInfo pandaFrame = await pandaCodec.getNextFrame();
      return pandaFrame.image;
    } catch (e) {
      try {
        final File pandaFile = File('assets/images/haidilao_panda.png');
        if (pandaFile.existsSync()) {
          final Uint8List pandaBytes = await pandaFile.readAsBytes();
          final ui.Codec pandaCodec = await ui.instantiateImageCodec(pandaBytes);
          final ui.FrameInfo pandaFrame = await pandaCodec.getNextFrame();
          return pandaFrame.image;
        }
      } catch (_) {}
    }
    return null;
  }

  static void _drawBlueCardHeader(
    Canvas canvas, {
    required double width,
    required double startY,
    required double height,
    required BlueCardData data,
  }) {
    const double margin = 40.0;
    final double cardWidth = width - (margin * 2);
    final Rect cardRect = Rect.fromLTWH(margin, startY, cardWidth, height);

    // Card Container (Deep Blue Glass Card)
    final Paint cardBgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF16293D), Color(0xFF0F1E2E)],
      ).createShader(cardRect);

    final RRect roundCard = RRect.fromRectAndRadius(cardRect, const Radius.circular(24));
    canvas.drawRRect(roundCard, cardBgPaint);

    // Card Border (Haidilao Gold Accent)
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(roundCard, borderPaint);

    double textY = startY + 28.0;

    // Header Badge: LAPORAN GENERAL CLEANING
    final TextPainter headerTitlePainter = TextPainter(
      text: TextSpan(
        text: data.title.toUpperCase(),
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 34.0,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFD700),
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    headerTitlePainter.layout(maxWidth: cardWidth - 40);
    headerTitlePainter.paint(canvas, Offset(margin + 24, textY));
    textY += headerTitlePainter.height + 12.0;

    // Store Name / Outlet
    final TextPainter storePainter = TextPainter(
      text: TextSpan(
        text: data.storeName.isNotEmpty ? data.storeName : 'Haidilao Night Shift',
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 24.0,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    storePainter.layout(maxWidth: cardWidth - 40);
    storePainter.paint(canvas, Offset(margin + 24, textY));
    textY += storePainter.height + 16.0;

    // Divider Line
    canvas.drawLine(
      Offset(margin + 24, textY),
      Offset(margin + cardWidth - 24, textY),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.5,
    );
    textY += 16.0;

    // Info Row: Penanggung Jawab & Tanggal
    final String picText = 'PIC: ${data.picName.isNotEmpty ? data.picName : "-"}';
    final String dateStr = data.dateText.isNotEmpty
        ? data.dateText
        : LocaleService.mediumDate(DateTime.now());

    final TextPainter picPainter = TextPainter(
      text: TextSpan(
        text: picText,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF90CAF9),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    picPainter.layout(maxWidth: (cardWidth - 60) / 2);
    picPainter.paint(canvas, Offset(margin + 24, textY));

    final TextPainter datePainter = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 17.0,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    datePainter.layout(maxWidth: (cardWidth - 60) / 2);
    datePainter.paint(canvas, Offset(margin + cardWidth - 24 - datePainter.width, textY));

    textY += picPainter.height + 18.0;

    // Catatan Box (If note provided)
    if (data.noteText.trim().isNotEmpty) {
      final Rect noteRect = Rect.fromLTWH(margin + 20, textY, cardWidth - 40, 75);
      final RRect noteRRect = RRect.fromRectAndRadius(noteRect, const Radius.circular(12));
      canvas.drawRRect(noteRRect, Paint()..color = const Color(0xFF0A1420));
      canvas.drawRRect(
        noteRRect,
        Paint()
          ..color = Colors.blueAccent.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final TextPainter notePainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Catatan: ',
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 17.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
              ),
            ),
            TextSpan(
              text: data.noteText,
              style: TextStyle(
                fontFamily: GoogleFonts.inter().fontFamily,
                fontSize: 17.0,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      );
      notePainter.layout(maxWidth: cardWidth - 64);
      notePainter.paint(canvas, Offset(margin + 32, textY + 14));
    }
  }

  static void _drawPhotoSlot(
    Canvas canvas, {
    required Rect rect,
    required String label,
    required Color badgeColor,
    required ui.Image? image,
  }) {
    final RRect roundRect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Draw Background Frame
    canvas.drawRRect(roundRect, Paint()..color = const Color(0xFF101F30));

    if (image != null) {
      canvas.save();
      canvas.clipRRect(roundRect);

      // Scale Image Center Cover
      final double scaleX = rect.width / image.width;
      final double scaleY = rect.height / image.height;
      final double scale = scaleX > scaleY ? scaleX : scaleY;

      final double drawWidth = image.width * scale;
      final double drawHeight = image.height * scale;
      final double dx = rect.left + (rect.width - drawWidth) / 2.0;
      final double dy = rect.top + (rect.height - drawHeight) / 2.0;

      final Rect dstRect = Rect.fromLTWH(dx, dy, drawWidth, drawHeight);
      final Rect srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

      canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.high);
      canvas.restore();
    } else {
      // Empty Photo Placeholder
      final TextPainter emptyText = TextPainter(
        text: TextSpan(
          text: '📷 Foto Belum Dipilih\nKetuk di aplikasi untuk memilih foto',
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            height: 1.4,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      emptyText.layout(maxWidth: rect.width - 40);
      emptyText.paint(
        canvas,
        Offset(rect.left + (rect.width - emptyText.width) / 2, rect.top + (rect.height - emptyText.height) / 2),
      );
    }

    // Outer Border
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(roundRect, borderPaint);

    // Draw Top Badge Tag (BEFORE / PROSES / AFTER)
    final RRect badgeRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(rect.left + 20, rect.top + 20, 260, 48),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );

    canvas.drawRRect(badgeRRect, Paint()..color = badgeColor);

    final TextPainter badgeText = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 16.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    badgeText.layout();
    badgeText.paint(
      canvas,
      Offset(rect.left + 20 + (260 - badgeText.width) / 2, rect.top + 20 + (48 - badgeText.height) / 2),
    );
  }

  static void _drawBlueCardFooter(
    Canvas canvas, {
    required double width,
    required double startY,
    required double height,
    required ui.Image? pandaImage,
    required String dateText,
  }) {
    canvas.drawRect(Rect.fromLTWH(0, startY, width, height), Paint()..color = const Color(0xFF08121E));
    canvas.drawRect(Rect.fromLTWH(0, startY, width, 4), Paint()..color = const Color(0xFFFFD700));

    final TextPainter footerTitle = TextPainter(
      text: TextSpan(
        text: 'HAIDILAO GENERAL CLEANING REPORT TEMPLATE',
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 20.0,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFD700),
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerTitle.layout();
    footerTitle.paint(canvas, Offset(40, startY + 30));

    final TextPainter footerSub = TextPainter(
      text: TextSpan(
        text: 'Dokumentasi Kebersihan & Sanitasi Resmi Haidilao Hotpot',
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
          color: Colors.white60,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerSub.layout();
    footerSub.paint(canvas, Offset(40, startY + 62));

    // Panda Mascot on Right Footer
    if (pandaImage != null) {
      const double pWidth = 140.0;
      const double pHeight = 150.0;
      final Rect dst = Rect.fromLTWH(width - pWidth - 30, startY - 45, pWidth, pHeight);
      final Rect src = Rect.fromLTWH(0, 0, pandaImage.width.toDouble(), pandaImage.height.toDouble());
      canvas.drawImageRect(pandaImage, src, dst, Paint()..filterQuality = ui.FilterQuality.high);
    }
  }

  static void _drawShiftHeader(
    Canvas canvas, {
    required double width,
    required double startY,
    required double height,
    required ShiftChecklistData data,
  }) {
    const double margin = 40.0;
    final double cardWidth = width - (margin * 2);
    final Rect cardRect = Rect.fromLTWH(margin, startY, cardWidth, height);

    // Card Background (Haidilao Red Gradient)
    final Paint cardBgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFC8102E), Color(0xFF8B0000)],
      ).createShader(cardRect);

    final RRect roundCard = RRect.fromRectAndRadius(cardRect, const Radius.circular(24));
    canvas.drawRRect(roundCard, cardBgPaint);

    // Gold Accent Top/Border
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(roundCard, borderPaint);

    double textY = startY + 28.0;

    // Header Title (e.g. CLOSINGAN NIGHT SHIFT)
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: (data.headerTitle.isNotEmpty ? data.headerTitle : 'Closingan Night Shift').toUpperCase(),
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 34.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    titlePainter.layout(maxWidth: cardWidth - 40);
    titlePainter.paint(canvas, Offset(margin + 24, textY));
    textY += titlePainter.height + 10.0;

    // Sub-Header: Nama Penanggung Jawab
    final String picText = 'Penanggung Jawab: ${data.picName.isNotEmpty ? data.picName : "-"}';
    final TextPainter picPainter = TextPainter(
      text: TextSpan(
        text: picText,
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 20.0,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFD700),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    picPainter.layout(maxWidth: cardWidth - 40);
    picPainter.paint(canvas, Offset(margin + 24, textY));
    textY += picPainter.height + 16.0;

    // Date & Time Line
    final String dateStr = data.dateText.isNotEmpty
        ? data.dateText
        : LocaleService.mediumDate(DateTime.now());
    final TextPainter datePainter = TextPainter(
      text: TextSpan(
        text: '📅 $dateStr',
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    datePainter.layout(maxWidth: cardWidth - 40);
    datePainter.paint(canvas, Offset(margin + 24, textY));
    textY += datePainter.height + 18.0;

    // Catatan Box (replaces description field)
    final Rect noteRect = Rect.fromLTWH(margin + 20, textY, cardWidth - 40, 75);
    final RRect noteRRect = RRect.fromRectAndRadius(noteRect, const Radius.circular(12));
    canvas.drawRRect(noteRRect, Paint()..color = Colors.black.withOpacity(0.35));

    final String catText = data.noteText.trim().isNotEmpty ? data.noteText : 'Tidak ada catatan tambahan';
    final TextPainter notePainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Catatan: ',
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 17.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),
          TextSpan(
            text: catText,
            style: TextStyle(
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 17.0,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    notePainter.layout(maxWidth: cardWidth - 64);
    notePainter.paint(canvas, Offset(margin + 32, textY + 14));
  }

  static void _drawChecklistSection(
    Canvas canvas, {
    required double width,
    required double startY,
    required double height,
    required List<ChecklistItem> items,
  }) {
    const double margin = 40.0;
    final double cardWidth = width - (margin * 2);
    final Rect cardRect = Rect.fromLTWH(margin, startY, cardWidth, height);

    // Card Container (Dark Grey Card)
    final RRect roundCard = RRect.fromRectAndRadius(cardRect, const Radius.circular(24));
    canvas.drawRRect(roundCard, Paint()..color = const Color(0xFF1E1E1E));
    canvas.drawRRect(
      roundCard,
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    double currentY = startY + 20.0;

    // Section Title
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: '📋 DAFTAR CEKLIS SHIFT',
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFD700),
          letterSpacing: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    titlePainter.layout(maxWidth: cardWidth - 40);
    titlePainter.paint(canvas, Offset(margin + 24, currentY));
    currentY += titlePainter.height + 16.0;

    // Draw Items
    if (items.isEmpty) {
      final TextPainter emptyPainter = TextPainter(
        text: TextSpan(
          text: 'Belum ada item ceklis yang ditambahkan.',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 18.0,
            color: Colors.white38,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      emptyPainter.layout();
      emptyPainter.paint(canvas, Offset(margin + 24, currentY + 10));
      return;
    }

    for (var item in items) {
      final double itemY = currentY;

      // Checkbox Box Icon
      final Rect boxRect = Rect.fromLTWH(margin + 24, itemY + 4, 32, 32);
      final RRect boxRRect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));

      if (item.isChecked) {
        canvas.drawRRect(boxRRect, Paint()..color = const Color(0xFF2E7D32)); // Emerald Green
        // Draw Checkmark `✓`
        final TextPainter checkPainter = TextPainter(
          text: const TextSpan(
            text: '✓',
            style: TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        checkPainter.layout();
        checkPainter.paint(canvas, Offset(margin + 30, itemY + 6));
      } else {
        canvas.drawRRect(
          boxRRect,
          Paint()
            ..color = const Color(0xFF666666)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      // Item Text & Worker Name
      final List<InlineSpan> textSpans = [
        TextSpan(
          text: item.text,
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 20.0,
            fontWeight: item.isChecked ? FontWeight.w600 : FontWeight.w400,
            color: item.isChecked ? Colors.white : Colors.white54,
            decoration: TextDecoration.none,
          ),
        ),
      ];

      if (item.workerName.trim().isNotEmpty) {
        textSpans.add(
          TextSpan(
            text: '  👤 ${item.workerName.trim()}',
            style: TextStyle(
              fontFamily: GoogleFonts.outfit().fontFamily,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),
        );
      }

      final TextPainter itemTextPainter = TextPainter(
        text: TextSpan(children: textSpans),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      );
      itemTextPainter.layout(maxWidth: cardWidth - 90);
      itemTextPainter.paint(canvas, Offset(margin + 70, itemY + 6));

      currentY += 64.0;
    }
  }

  static void _drawPhotosSection(
    Canvas canvas, {
    required double width,
    required double startY,
    required List<ui.Image> images,
    required double photoSpacing,
  }) {
    const double margin = 40.0;
    final double cardWidth = width - (margin * 2);

    double currentY = startY;

    // Section Header Text
    final TextPainter sectionTitle = TextPainter(
      text: TextSpan(
        text: '📸 DOKUMENTASI FOTO SHIFT',
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    sectionTitle.layout(maxWidth: cardWidth);
    sectionTitle.paint(canvas, Offset(margin, currentY));
    currentY += sectionTitle.height + 20.0;

    if (images.isEmpty) {
      final Rect emptyRect = Rect.fromLTWH(margin, currentY, cardWidth, 120);
      final RRect emptyRRect = RRect.fromRectAndRadius(emptyRect, const Radius.circular(20));
      canvas.drawRRect(emptyRRect, Paint()..color = const Color(0xFF1E1E1E));

      final TextPainter emptyText = TextPainter(
        text: TextSpan(
          text: 'Belum ada foto yang dilampirkan.',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 18.0,
            color: Colors.white38,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      emptyText.layout();
      emptyText.paint(
        canvas,
        Offset(margin + (cardWidth - emptyText.width) / 2, currentY + (120 - emptyText.height) / 2),
      );
      return;
    }

    // Render Each Photo 1 Column Vertical (Full Uncropped)
    for (int i = 0; i < images.length; i++) {
      final ui.Image img = images[i];
      final double photoHeight = (cardWidth / img.width) * img.height;
      final Rect photoRect = Rect.fromLTWH(margin, currentY, cardWidth, photoHeight);
      final RRect photoRRect = RRect.fromRectAndRadius(photoRect, const Radius.circular(20));

      canvas.save();
      canvas.clipRRect(photoRRect);

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        photoRect,
        Paint()..filterQuality = ui.FilterQuality.high,
      );

      canvas.restore();

      // Border outline
      canvas.drawRRect(
        photoRRect,
        Paint()
          ..color = const Color(0xFF333333)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );

      currentY += photoHeight + photoSpacing;
    }
  }

  static void _drawShiftFooter(
    Canvas canvas, {
    required double width,
    required double startY,
    required double height,
    required ui.Image? pandaImage,
    required String dateText,
  }) {
    canvas.drawRect(Rect.fromLTWH(0, startY, width, height), Paint()..color = const Color(0xFF181818));
    canvas.drawRect(Rect.fromLTWH(0, startY, width, 4), Paint()..color = const Color(0xFFC8102E));

    final TextPainter footerTitle = TextPainter(
      text: TextSpan(
        text: 'HAIDILAO SHIFT CHECKLIST & REPORT SYSTEM',
        style: TextStyle(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontSize: 20.0,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFD700),
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerTitle.layout();
    footerTitle.paint(canvas, Offset(40, startY + 30));

    final TextPainter footerSub = TextPainter(
      text: TextSpan(
        text: 'Laporan Operasional Shift & Ceklis Kebersihan Resmi',
        style: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
          color: Colors.white60,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerSub.layout();
    footerSub.paint(canvas, Offset(40, startY + 62));

    // Panda Mascot on Right Footer
    if (pandaImage != null) {
      const double pWidth = 140.0;
      const double pHeight = 150.0;
      final Rect dst = Rect.fromLTWH(width - pWidth - 30, startY - 45, pWidth, pHeight);
      final Rect src = Rect.fromLTWH(0, 0, pandaImage.width.toDouble(), pandaImage.height.toDouble());
      canvas.drawImageRect(pandaImage, src, dst, Paint()..filterQuality = ui.FilterQuality.high);
    }
  }
}
