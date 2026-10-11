import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haidilao_cam/core/models/photo_crop_data.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';
import 'package:haidilao_cam/core/services/collage_service.dart';
import 'package:haidilao_cam/core/services/theme_service.dart';
import 'package:haidilao_cam/core/services/watermark_service.dart';
import 'package:haidilao_cam/screens/camera_screen.dart';
import 'package:haidilao_cam/screens/gallery_screen.dart';
import 'package:haidilao_cam/core/theme/app_theme.dart';
import 'package:image/image.dart' as img;
import 'package:easy_localization/easy_localization.dart';
import 'package:haidilao_cam/core/services/app_settings_service.dart';
import 'package:haidilao_cam/core/services/locale_service.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class ComparisonTemplateScreen extends StatefulWidget {
  final List<WatermarkedPhoto> photos;

  const ComparisonTemplateScreen({
    super.key,
    required this.photos,
  });

  @override
  State<ComparisonTemplateScreen> createState() => _ComparisonTemplateScreenState();
}

class _ComparisonTemplateScreenState extends State<ComparisonTemplateScreen> {
  late List<WatermarkedPhoto> _selectedPhotos;

  CollageTemplateType _selectedTemplate = CollageTemplateType.col2Vertical;
  PhotoSizeMode _photoSizeMode = PhotoSizeMode.fullSize;
  final Map<String, PhotoCropData> _photoCrops = {};
  final Map<String, ui.Image> _uiImageCache = {};
  final Map<int, String> _rowNotes = {};

  bool _isRightWrong = false;
  String _selectedTemplateLogo = AppSettingsService.templateLogo;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _getDisplayTitle() {
    final text = _titleController.text.trim();
    if (text.isEmpty || text == 'JUDUL' || text == 'TITLE' || text == '标题') {
      return 'template.show_title'.trSafe();
    }
    return _titleController.text;
  }

  String _getDisplaySubtitle() {
    final text = _subtitleController.text.trim();
    if (text.isEmpty || text == 'SUB JUDUL' || text == 'SUBTITLE' || text == '副标题') {
      return 'template.show_subtitle'.trSafe();
    }
    return _subtitleController.text;
  }

  String _getDisplayDescription() {
    final text = _descriptionController.text.trim();
    if (text.isEmpty || text == 'DESKRIPSI' || text == 'DESCRIPTION' || text == '描述') {
      return 'template.show_description'.trSafe();
    }
    return _descriptionController.text;
  }

  double _titleFontSize = 75.0;
  double _subtitleFontSize = 48.0;
  double _descriptionFontSize = 34.0;

  bool _showTitle = true;
  bool _showSubtitle = true;
  bool _showDescription = true;
  final bool _showHeader = true;
  final bool _showFooter = true;
  final double _spacing = 10.0;

  bool _isExporting = false;
  int? _draggingIndex;
  int? _hoveredIndex;
  final GlobalKey _exportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedPhotos = List.from(widget.photos);
    _loadUiImages();
  }

  Future<void> _loadUiImages() async {
    for (var photo in _selectedPhotos) {
      if (_uiImageCache.containsKey(photo.path)) continue;
      final file = File(photo.path);
      if (!file.existsSync()) continue;
      try {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _uiImageCache[photo.path] = frame.image;
          });
        }
      } catch (e) {
        debugPrint('Error loading image for preview cache: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Generates compiled collage file via direct RepaintBoundary widget capture for 100% exact visual match
  Future<File?> _generateCollageFile() async {
    if (_selectedPhotos.isEmpty) return null;
    setState(() => _isExporting = true);

    final bool isDark = ThemeService.isDarkMode;

    try {
      // Ensure widget layout & paint is complete
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary? boundary =
          _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        final ui.Image capturedImage = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await capturedImage.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final Uint8List rawPng = byteData.buffer.asUint8List();
          final img.Image? decodedCanvas = img.decodePng(rawPng);
          final Uint8List finalJpgBytes = decodedCanvas != null
              ? Uint8List.fromList(img.encodeJpg(decodedCanvas, quality: 93))
              : rawPng;

          final Directory targetDir = await WatermarkService.getHaidilaoCameraDirectory();
          final DateTime now = DateTime.now();
          final String fileName = 'HDL_KOLASE_${DateFormat('yyyyMMdd_HHmm').format(now)}_${now.millisecond}.jpg';
          final String targetPath = p.join(targetDir.path, fileName);

          final File savedFile = File(targetPath);
          await savedFile.writeAsBytes(finalJpgBytes);

          try {
            final hasAccess = await Gal.hasAccess();
            if (!hasAccess) await Gal.requestAccess();
            await Gal.putImage(savedFile.path, album: 'Haidilao Camera');
          } catch (galError) {
            debugPrint('Gal save notification error: $galError');
          }

          if (mounted) setState(() => _isExporting = false);
          return savedFile;
        }
      }
    } catch (e) {
      debugPrint('Direct RepaintBoundary widget capture error: $e');
    }

    // Fallback to CollageService canvas
    final File? resultFile = await CollageService.generateCollage(
      photos: _selectedPhotos,
      templateType: _selectedTemplate,
      photoSizeMode: _photoSizeMode,
      photoCrops: _photoCrops,
      rowNotes: _rowNotes,
      titleText: _getDisplayTitle().toUpperCase(),
      subtitleText: _getDisplaySubtitle().toUpperCase(),
      descriptionText: _getDisplayDescription().toUpperCase(),
      titleFontSize: _titleFontSize,
      subtitleFontSize: _subtitleFontSize,
      descriptionFontSize: _descriptionFontSize,
      showSubtitle: _showSubtitle,
      showDescription: _showDescription,
      showHeader: _showHeader,
      showFooter: _showFooter,
      spacing: _spacing,
      isDarkMode: isDark,
    );

    if (mounted) {
      setState(() => _isExporting = false);
    }
    return resultFile;
  }

  /// Button 1: SIMPAN (Save to Gallery)
  Future<void> _exportAndSaveCollage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    final File? resultFile = await _generateCollageFile();
    
    if (mounted) Navigator.pop(context); // Close loading indicator

    if (!mounted) return;

    if (resultFile != null) {
      _showSuccessDialog(resultFile.path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryRed,
          content: Text(
            'template.export_failed'.tr(),
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }

  /// Button 2: LIHAT KOLASE (Instant Interactive Preview Popup - No File Saving / No Loading)
  void _previewCollageFullImage() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = ThemeService.isDarkMode;
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF101014) : const Color(0xFFE8E8EE),
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black87,
              elevation: 1,
              title: Text(
                'collage.preview_title'.tr(),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share_rounded, size: 20, color: Colors.white),
                    tooltip: 'common.share'.tr(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareCollage();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.save_alt_rounded, size: 20, color: Colors.white),
                    tooltip: 'common.save'.tr(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportAndSaveCollage();
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4.0,
                  clipBehavior: Clip.none,
                  child: _buildCollageLivePreview(isDark, isPreviewOnly: true),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Helper to safely share image file with mimeType and fallback handling
  Future<void> _shareFileAtPath(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;

    try {
      final xFile = XFile(filePath, mimeType: 'image/jpeg');
      await Share.shareXFiles(
        [xFile],
        text: 'Kolase Foto HI CAM 📸',
      );
    } catch (e) {
      debugPrint('Error with Share.shareXFiles: $e');
      try {
        final xFile = XFile(filePath);
        await Share.shareXFiles([xFile]);
      } catch (err) {
        debugPrint('Fallback share failed: $err');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryRed,
              content: Text(
                'collage.share_fallback_notice'.tr(),
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          );
        }
      }
    }
  }

  /// Button 3: BAGIKAN (Share Collage JPG)
  Future<void> _shareCollage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    final file = await _generateCollageFile();
    
    if (mounted) Navigator.pop(context); // Close loading indicator
    
    if (file == null) return;
    await _shareFileAtPath(file.path);
  }

  /// Button 4: RESET (Reset All Selected Photos & Collage Settings)
  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = ThemeService.isDarkMode;
        final goldColor = AppTheme.getGoldColor(ctx);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.restart_alt_rounded, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(
                'collage.reset_title'.tr(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'collage.reset_confirm'.tr(),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _photoCrops.clear();
                  _rowNotes.clear();
                  _selectedPhotos.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: goldColor,
                    content: Text(
                      'collage.reset_success'.tr(),
                      style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
              child: Text('common.yes_delete'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Displays saved collage high-res PNG file in a full-screen view with share & close buttons
  void _showSavedImageFullView(String filePath) {
    if (!File(filePath).existsSync()) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = ThemeService.isDarkMode;
        final goldColor = AppTheme.getGoldColor(context);

        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF101014) : Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                'collage.preview_title'.tr(),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16, color: Colors.black),
                  label: Text(
                    'common.share'.tr().toUpperCase(),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                  ),
                  onPressed: () => _shareFileAtPath(filePath),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      File(filePath),
                      width: MediaQuery.of(ctx).size.width - 24,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) {
        final goldColor = AppTheme.getGoldColor(context);

        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
              const SizedBox(width: 10),
              Text(
                'collage.saved_success_title'.tr(),
                style: GoogleFonts.outfit(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'collage.saved_success_desc'.tr(namedArgs: {'count': '${_selectedPhotos.length}'}),
                style: GoogleFonts.inter(color: AppTheme.getTextSecondary(context), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.getBorderColor(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: goldColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filePath,
                        style: GoogleFonts.inter(color: AppTheme.getTextSecondary(context), fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          actions: [
            Row(
              children: [
                // Button 1: LIHAT GAMBAR
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(color: goldColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.image_rounded, size: 16),
                    label: Text(
                      'collage.view_image'.tr(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSavedImageFullView(filePath);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Button 2: KEMBALI KE GALERI
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      'collage.to_gallery'.tr(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Interactive popup edit dialog triggered when tapping direct text
  void _showEditSingleTextDialog({
    required String title,
    required TextEditingController controller,
    required double fontSize,
    required double minFontSize,
    required double maxFontSize,
    bool isMultiline = false,
    required ValueChanged<double> onFontSizeChanged,
    bool? isVisible,
    ValueChanged<bool>? onVisibilityChanged,
  }) {
    double localFontSize = fontSize;
    bool? localIsVisible = isVisible;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final Color textPrim = AppTheme.getTextPrimary(context);
            final Color textSec = AppTheme.getTextSecondary(context);
            final Color cardBg = AppTheme.getCardColor(context);
            final Color goldColor = AppTheme.getGoldColor(context);

            return AlertDialog(
              backgroundColor: AppTheme.getSurfaceColor(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.edit_rounded, color: goldColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'collage.edit_title_dialog'.tr(namedArgs: {'title': title}),
                      style: GoogleFonts.outfit(
                        color: textPrim,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Text Field
                    Text(
                      'collage.header_content_label'.tr(),
                      style: GoogleFonts.outfit(color: textSec, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      maxLines: isMultiline ? 3 : 1,
                      style: GoogleFonts.outfit(color: textPrim, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'collage.enter_title_hint'.tr(namedArgs: {'title': title}),
                        hintStyle: TextStyle(color: textSec.withOpacity(0.5)),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. Font Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('collage.font_size_label'.tr(), style: GoogleFonts.inter(color: textSec, fontSize: 13)),
                        Text(
                          '${localFontSize.toInt()} px',
                          style: GoogleFonts.outfit(color: goldColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: localFontSize,
                      min: minFontSize,
                      max: maxFontSize,
                      divisions: (maxFontSize - minFontSize).toInt(),
                      activeColor: goldColor,
                      inactiveColor: AppTheme.getBorderColor(context),
                      onChanged: (val) {
                        setModalState(() {
                          localFontSize = val;
                        });
                        onFontSizeChanged(val);
                      },
                    ),
                    if (localIsVisible != null && onVisibilityChanged != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('collage.show_label'.tr(namedArgs: {'title': title}), style: GoogleFonts.inter(color: textSec, fontSize: 13)),
                          Switch(
                            value: localIsVisible!,
                            activeColor: AppTheme.primaryRed,
                            onChanged: (val) {
                              setModalState(() {
                                localIsVisible = val;
                              });
                              onVisibilityChanged(val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: Text('common.save'.tr().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
Widget build(BuildContext context) {
    LocaleService.update(context.locale);
    final Color bgColor = AppTheme.getBackgroundColor(context);
    final Color surfaceColor = AppTheme.getSurfaceColor(context);
    final Color cardColor = AppTheme.getCardColor(context);
    final Color textSecondary = AppTheme.getTextSecondary(context);
    final Color goldColor = AppTheme.getGoldColor(context);
    final bool isDark = ThemeService.isDarkMode;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'template.title'.tr().toUpperCase(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        // actions removed per user request
      ),
      body: Stack(
        children: [
          // Offscreen RepaintBoundary widget captured at 3.0 pixelRatio (1080px resolution) for 100% exact visual match
          Positioned(
            left: -9999,
            top: -9999,
            child: Material(
              color: Colors.transparent,
              child: RepaintBoundary(
                key: _exportKey,
                child: _buildCollageLivePreview(isDark, isPreviewOnly: true),
              ),
            ),
          ),

          // Main Editor View
          Column(
            children: [
              // 1. Column Selector moved inside ExpansionTile

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              backgroundColor: surfaceColor,
              collapsedBackgroundColor: surfaceColor,
              iconColor: goldColor,
              collapsedIconColor: textSecondary,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              childrenPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: goldColor),
                  const SizedBox(width: 8),
                  Text('template.settings'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: goldColor)),
                ],
              ),
              children: [
                _buildColumnSelectorRow(surfaceColor, cardColor, textSecondary, goldColor),
                                // Comparison Type (Only for 2 Columns)
                if (_selectedTemplate == CollageTemplateType.col2Vertical)
                Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: surfaceColor,
                child: Row(
                children: [
                SizedBox(
                  width: 118,
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_customize_rounded, size: 16, color: goldColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'template.type_label'.trSafe(),
                          style: GoogleFonts.outfit(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                child: Row(
                children: [
                Expanded(
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                onTap: () => setState(() => _isRightWrong = false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                color: !_isRightWrong ? AppTheme.primaryRed : cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                color: !_isRightWrong ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
                ),
                ),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(
                Icons.compare_rounded,
                size: 14,
                color: !_isRightWrong ? Colors.white : goldColor,
                ),
                const SizedBox(width: 6),
                Text(
                'template.type_ba'.tr(),
                style: GoogleFonts.outfit(
                color: !_isRightWrong ? Colors.white : textSecondary,
                fontWeight: !_isRightWrong ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
                ),
                ),
                ],
                ),
                ),
                ),
                ),
                ),
                Expanded(
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                onTap: () => setState(() => _isRightWrong = true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                color: _isRightWrong ? AppTheme.primaryRed : cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                color: _isRightWrong ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
                ),
                ),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(
                Icons.fact_check_rounded,
                size: 14,
                color: _isRightWrong ? Colors.white : goldColor,
                ),
                const SizedBox(width: 6),
                Text(
                'template.type_rw'.tr(),
                style: GoogleFonts.outfit(
                color: _isRightWrong ? Colors.white : textSecondary,
                fontWeight: _isRightWrong ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
                ),
                ),
                ],
                ),
                ),
                ),
                ),
                ),
                ],
                ),
                ),
                ],
                ),
                ),
                                // (Logo Selector removed from here)
                // 2. Photo Size Mode Selector Row (Full Size vs Kotak 1:1)
                _buildSizeModeSelectorRow(surfaceColor, cardColor, textSecondary, goldColor),
                                                // Logo Style Selector Row
                Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                color: surfaceColor,
                child: Row(
                children: [
                SizedBox(
                  width: 118,
                  child: Row(
                    children: [
                      Icon(Icons.emoji_emotions_rounded, size: 16, color: goldColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'template.logo_label'.trSafe(),
                          style: GoogleFonts.outfit(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                child: Row(
                children: [
                {'path': '', 'name': '', 'icon': Icons.block_rounded},
                {'path': 'assets/images/hi_logo.png', 'name': 'Hi', 'icon': Icons.sentiment_satisfied_alt_rounded},
                {'path': 'assets/images/haidilao_panda.png', 'name': 'collage.panda_1'.trSafe(), 'icon': Icons.pets_rounded},
                {'path': 'assets/images/haidilao_panda2.png', 'name': 'collage.panda_2'.trSafe(), 'icon': Icons.camera_alt_rounded},
                ].map((logo) {
                final isSelected = _selectedTemplateLogo == logo['path'];
                return Expanded(
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                onTap: () {
                  final String newLogo = logo['path'] as String;
                  setState(() => _selectedTemplateLogo = newLogo);
                  AppSettingsService.setTemplateLogo(newLogo);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryRed : cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                color: isSelected ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
                ),
                ),
                child: Center(
                  child: (logo['name'] as String).isEmpty
                      ? Icon(
                          logo['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : textSecondary,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            logo['name'] as String,
                            style: GoogleFonts.outfit(
                              color: isSelected ? Colors.white : textSecondary,
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
                ),
                ),
                ),
                );
                }).toList(),
                ),
                ),
                ],
                ),
                ),
                              ],
            ),
          ),
          // 3. Template Description Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cardColor,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: goldColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedTemplate.description,
                    style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

              // 3. Live Canvas Interactive Preview (Adapts to Light / Dark Mode, Pinch-to-Zoom Enabled)
              Expanded(
                child: Container(
                  color: isDark ? Colors.black38 : const Color(0xFFE8E8EE),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
                      child: InteractiveViewer(
                        minScale: 0.7,
                        maxScale: 4.0,
                        clipBehavior: Clip.none,
                        child: SingleChildScrollView(
                          child: _buildCollageLivePreview(isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // 4. Bottom Action Bar (4 Action Buttons: Simpan, Lihat Kolase, Bagikan, Reset)
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.getBorderColor(context))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Simpan (3D Elevated Red Button)
              Expanded(
                child: _buildBottomActionButton(
                  icon: Icons.save_alt_rounded,
                  label: 'collage.save_action'.tr(),
                  isLoading: _isExporting,
                  onPressed: _isExporting ? null : _exportAndSaveCollage,
                ),
              ),
              const SizedBox(width: 8),

              // 2. Lihat Kolase (3D Elevated Red Button)
              Expanded(
                child: _buildBottomActionButton(
                  icon: Icons.visibility_rounded,
                  label: 'collage.view_action'.tr(),
                  onPressed: _isExporting ? null : _previewCollageFullImage,
                ),
              ),
              const SizedBox(width: 8),

              // 3. Bagikan (3D Elevated Red Button)
              Expanded(
                child: _buildBottomActionButton(
                  icon: Icons.share_rounded,
                  label: 'collage.share_action'.tr(),
                  onPressed: _isExporting ? null : _shareCollage,
                ),
              ),
              const SizedBox(width: 8),

              // 4. Reset (3D Elevated Red Button)
              Expanded(
                child: _buildBottomActionButton(
                  icon: Icons.restart_alt_rounded,
                  label: 'collage.reset_action'.tr(),
                  onPressed: _isExporting ? null : _showResetConfirmationDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget for bottom bar action buttons (3D Elevated Red Button)
  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    final bool isDisabled = onPressed == null;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDisabled ? const Color(0xFF500000) : const Color(0xFF6B0000), // Dark maroon 3D bottom bevel base
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFB71C1C).withOpacity(0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3.5), // Exposes the dark maroon 3D bottom bevel
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDisabled
                ? [const Color(0xFFD32F2F).withOpacity(0.5), const Color(0xFF9A0000).withOpacity(0.5)]
                : [
                    const Color(0xFFEF5350), // Vibrant top highlight
                    const Color(0xFFD32F2F), // Haidilao Red body
                    const Color(0xFFB71C1C), // Deep crimson bottom
                  ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(isDisabled ? 0.2 : 0.4),
            width: 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                    )
                  else
                    Icon(
                      icon,
                      size: 17,
                      color: Colors.white.withOpacity(isDisabled ? 0.6 : 1.0),
                    ),
                  const SizedBox(height: 1),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(isDisabled ? 0.6 : 1.0),
                          shadows: isDisabled
                              ? null
                              : const [
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1 to 4 Columns selector displayed in 1 single row (No horizontal scrolling)
  Widget _buildColumnSelectorRow(
      Color surfaceColor, Color cardColor, Color textSecondary, Color goldColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      color: surfaceColor,
      child: Row(
        children: [CollageTemplateType.col2Vertical, CollageTemplateType.col3Vertical].map((template) {
          final isSelected = _selectedTemplate == template;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedTemplate = template;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryRed : cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        template.icon,
                        size: 18,
                        color: isSelected ? Colors.white : goldColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.shortTitle,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Photo Size Mode selector row (Ukuran Asli Full vs Ukuran Kotak 1:1)
  Widget _buildSizeModeSelectorRow(
      Color surfaceColor, Color cardColor, Color textSecondary, Color goldColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: surfaceColor,
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Row(
              children: [
                Icon(Icons.photo_size_select_large_rounded, size: 16, color: goldColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'template.size_label'.trSafe(),
                    style: GoogleFonts.outfit(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: PhotoSizeMode.values.map((mode) {
                final isSelected = _photoSizeMode == mode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _photoSizeMode = mode;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryRed : cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode == PhotoSizeMode.fullSize
                                  ? Icons.aspect_ratio_rounded
                                  : Icons.crop_square_rounded,
                              size: 14,
                              color: isSelected ? Colors.white : goldColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mode.shortLabel,
                              style: GoogleFonts.outfit(
                                color: isSelected ? Colors.white : textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Live preview widget matching active Dark or Light Theme

  Widget _buildSubheaderRow(bool isDark) {
    if (_selectedTemplate == CollageTemplateType.col1Vertical || _selectedTemplate == CollageTemplateType.col4Vertical) { return const SizedBox(); }
    final bool isThreeCols = _selectedTemplate == CollageTemplateType.col3Vertical;
    final List<String> labels = isThreeCols
        ? ['template.label_before'.tr(), 'template.label_process'.tr(), 'template.label_after'.tr()]
        : (_isRightWrong
            ? ['template.label_wrong'.tr(), 'template.label_correct'.tr()]
            : ['template.label_before'.tr(), 'template.label_after'.tr()]);
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEBEBEF),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: labels.map((label) {
          Widget textWidget = Container(
            padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed,
                  width: 3.0,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 2.0,
              ),
            ),
          );
          
          Widget content = textWidget;
          if (_isRightWrong && labels.isNotEmpty && label == labels.first) {
            content = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.close, color: Colors.red, size: 20),
                const SizedBox(width: 4),
                textWidget,
              ],
            );
          } else if (_isRightWrong && labels.length > 1 && label == labels[1]) {
            content = Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                textWidget,
              ],
            );
          }
          
          return Expanded(
            child: content,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCollageLivePreview(bool isDark, {bool isPreviewOnly = false}) {
    final Color canvasBg = isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F7);
    final Color borderColor = isDark ? AppTheme.primaryRed : const Color(0xFFD1D1D6);

    final double screenW = MediaQuery.of(context).size.width;
    final double containerW = isPreviewOnly
        ? 360.0
        : (screenW > 20 ? (screenW - 4.0).clamp(340.0, 500.0) : 360.0);

    return Container(
      width: containerW,
      decoration: BoxDecoration(
        color: canvasBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Preview Banner (Theme Adaptive)
          if (_showHeader) _buildInteractiveHeaderBanner(isDark, previewWidth: containerW),

          // Subheader row (Sebelum, Proses, Sesudah)
          _buildSubheaderRow(isDark),

          // Content Body Preview (Drag & Drop Photos)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: _spacing),
            child: _buildTemplateBodyPreview(borderColor, isDark, isPreviewOnly: isPreviewOnly),
          ),

          // Footer Preview Banner (Theme Adaptive)
          if (_showFooter)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEBEBEF),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFFFFD700) : AppTheme.primaryRed,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'HAIDILAO HOTPOT OFFICIAL CAMERA DOCUMENTATION SYSTEM',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white60 : const Color(0xFF555555),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _showRestoreTextDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = ThemeService.isDarkMode;
            final textPrim = isDark ? Colors.white : Colors.black87;
            final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('template.visibility_title'.tr(), style: GoogleFonts.outfit(color: textPrim, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text('template.show_title'.tr(), style: TextStyle(color: textPrim)),
                    value: _showTitle,
                    activeColor: AppTheme.primaryRed,
                    onChanged: (val) {
                      setModalState(() => _showTitle = val);
                      setState(() => _showTitle = val);
                    },
                  ),
                  SwitchListTile(
                    title: Text('template.show_subtitle'.tr(), style: TextStyle(color: textPrim)),
                    value: _showSubtitle,
                    activeColor: AppTheme.primaryRed,
                    onChanged: (val) {
                      setModalState(() => _showSubtitle = val);
                      setState(() => _showSubtitle = val);
                    },
                  ),
                  SwitchListTile(
                    title: Text('template.show_description'.tr(), style: TextStyle(color: textPrim)),
                    value: _showDescription,
                    activeColor: AppTheme.primaryRed,
                    onChanged: (val) {
                      setModalState(() => _showDescription = val);
                      setState(() => _showDescription = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('common.close'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Plain text clickable header banner (Proportionally scaled to match 1080px export canvas exactly)
  Widget _buildInteractiveHeaderBanner(bool isDark, {double previewWidth = 360.0, bool isPreviewOnly = false}) {
    final List<Color> bgColors = isDark
        ? [const Color(0xFF7A141E), const Color(0xFF38070D)]
        : [const Color(0xFFFFFFFF), const Color(0xFFF8F8FA)];

    final Color titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color subtitleColor = isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed;
    final Color descriptionColor = isDark ? const Color(0xFFE0E0E6) : const Color(0xFF4A4A4A);
    final Color accentLineColor = isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed;

    final double scale = previewWidth / 1080.0;

    return Container(
      padding: EdgeInsets.only(
        left: 40.0 * scale,
        right: 20.0 * scale,
        top: 32.0 * scale,
        bottom: 12.0 * scale,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: accentLineColor, width: 4.0 * scale)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_showTitle || !_showSubtitle || !_showDescription) {
            if (!isPreviewOnly) _showRestoreTextDialog();
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: _selectedTemplateLogo.isEmpty ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (_showTitle)
                  GestureDetector(
                    onTap: () => _showEditSingleTextDialog(
                      title: 'template.show_title'.tr(),
                      controller: _titleController,
                      fontSize: _titleFontSize,
                      minFontSize: 30.0,
                      maxFontSize: 140.0,
                      onFontSizeChanged: (val) => setState(() => _titleFontSize = val),
                      isVisible: _showTitle,
                      onVisibilityChanged: (val) => setState(() => _showTitle = val),
                    ),
                    child: Text(
                      _getDisplayTitle().toUpperCase(),
                      textAlign: TextAlign.left,
                      style: GoogleFonts.outfit(
                        color: titleColor,
                        fontSize: _titleFontSize * scale,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2 * scale,
                      ),
                    ),
                  ),
                if (_showSubtitle) ...[
                  if (_showTitle) const SizedBox(height: 4.0),
                  GestureDetector(
                    onTap: () => _showEditSingleTextDialog(
                      title: 'template.show_subtitle'.tr(),
                      controller: _subtitleController,
                      fontSize: _subtitleFontSize,
                      minFontSize: 20.0,
                      maxFontSize: 90.0,
                      onFontSizeChanged: (val) => setState(() => _subtitleFontSize = val),
                      isVisible: _showSubtitle,
                      onVisibilityChanged: (val) => setState(() => _showSubtitle = val),
                    ),
                    child: Text(
                      _getDisplaySubtitle().toUpperCase(),
                      textAlign: _selectedTemplateLogo.isEmpty ? TextAlign.center : TextAlign.left,
                      style: GoogleFonts.outfit(
                        color: subtitleColor,
                        fontSize: _subtitleFontSize * scale,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0 * scale,
                      ),
                    ),
                  ),
                ],
                if (_showDescription) ...[
                  if (_showTitle || _showSubtitle) const SizedBox(height: 4.0),
                  GestureDetector(
                    onTap: () => _showEditSingleTextDialog(
                      title: 'template.show_description'.tr(),
                      controller: _descriptionController,
                      fontSize: _descriptionFontSize,
                      minFontSize: 16.0,
                      maxFontSize: 60.0,
                      isMultiline: true,
                      onFontSizeChanged: (val) => setState(() => _descriptionFontSize = val),
                      isVisible: _showDescription,
                      onVisibilityChanged: (val) => setState(() => _showDescription = val),
                    ),
                    child: Text(
                      _getDisplayDescription().toUpperCase(),
                      textAlign: _selectedTemplateLogo.isEmpty ? TextAlign.center : TextAlign.left,
                      style: GoogleFonts.inter(
                        color: descriptionColor,
                        fontSize: _descriptionFontSize * scale,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: 0.8 * scale,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8.0),
                Text(
                  '📅 ${LocaleService.fullDate(DateTime.now())}',
                  style: GoogleFonts.inter(
                    color: subtitleColor,
                    fontSize: 28.0 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: _selectedTemplateLogo.isEmpty ? TextAlign.center : TextAlign.left,
                ),
                Text(
                  '📷 ${'collage.total_photos'.tr(namedArgs: {'count': '${_selectedPhotos.length}'})}',
                  style: GoogleFonts.inter(
                    color: subtitleColor,
                    fontSize: 28.0 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: _selectedTemplateLogo.isEmpty ? TextAlign.center : TextAlign.left,
                ),
              ],
            ),
          ),
          
          if (_selectedTemplateLogo.isNotEmpty) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: 380.0 * scale,
              height: 410.0 * scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcATop),
                      child: Image.asset(
                        _selectedTemplateLogo,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Image.asset(
                    _selectedTemplateLogo,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildTemplateBodyPreview(Color borderColor, bool isDark, {bool isPreviewOnly = false}) {
    final int crossAxisCount = _selectedTemplate == CollageTemplateType.col1Vertical
        ? 1
        : (_selectedTemplate == CollageTemplateType.col2Vertical
            ? 2
            : (_selectedTemplate == CollageTemplateType.col3Vertical ? 3 : 4));

    final int totalItems = _selectedPhotos.length;
    final int minSlots = crossAxisCount * (crossAxisCount == 1 ? 2 : 2); // At least 2 rows
    final int totalSlots = isPreviewOnly 
        ? totalItems 
        : ((totalItems + 1) < minSlots ? minSlots : totalItems + 1);
    final int numRows = (totalSlots / crossAxisCount).ceil();

    return Column(
      children: List.generate(numRows, (rowIndex) {
        final int startIdx = rowIndex * crossAxisCount;

        final bool hasNote = _rowNotes[rowIndex]?.trim().isNotEmpty == true;

        return Column(
          children: [
            // Photos Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(crossAxisCount, (colInRow) {
                final int globalIndex = startIdx + colInRow;
                if (globalIndex < totalItems) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: _buildDraggablePhotoTile(globalIndex, borderColor, isDark, isPreviewOnly: isPreviewOnly),
                    ),
                  );
                } else if (globalIndex == totalItems && !isPreviewOnly) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: _buildAddPhotoTile(borderColor, isDark),
                    ),
                  );
                } else {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: AspectRatio(
                        aspectRatio: _photoSizeMode == PhotoSizeMode.square ? 1.0 : (3.0 / 5.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12, 
                              width: 1, 
                              style: BorderStyle.solid
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }),
            ),

            if (hasNote || !isPreviewOnly) SizedBox(height: _spacing / 2),

            // Row Note UI (Small button if empty, styled card if filled)
            _buildRowNoteUI(rowIndex, isDark, isPreviewOnly: isPreviewOnly),

            SizedBox(height: (hasNote || !isPreviewOnly) ? _spacing : 3.0),
          ],
        );
      }),
    );
  }

  /// Row Note UI widget under each photo row
  Widget _buildRowNoteUI(int rowIndex, bool isDark, {bool isPreviewOnly = false}) {
    final String? note = _rowNotes[rowIndex];
    final bool hasNote = note != null && note.trim().isNotEmpty;
    final Color goldColor = AppTheme.getGoldColor(context);
    final Color cardBg = isDark ? const Color(0xFF26262A) : const Color(0xFFF0F0F5);
    final Color textColor = isDark ? const Color(0xFFE0E0E6) : const Color(0xFF333333);

    if (!hasNote) {
      if (isPreviewOnly) return const SizedBox();
      return Center(
        child: InkWell(
          onTap: () => _showEditRowNoteDialog(rowIndex),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_comment_rounded,
                  size: 14,
                  color: isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed,
                ),
                const SizedBox(width: 6),
                Text(
                  'template.add_note'.tr(namedArgs: {'n': '${rowIndex + 1}'}),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE0E0E6) : const Color(0xFF555555),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: _spacing / 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isPreviewOnly ? null : () => _showEditRowNoteDialog(rowIndex),
              child: Text(
                note.trim(),
                style: GoogleFonts.inter(
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (!isPreviewOnly) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: goldColor,
              onPressed: () => _showEditRowNoteDialog(rowIndex),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.redAccent,
              onPressed: () => setState(() => _rowNotes.remove(rowIndex)),
            ),
          ],
        ],
      ),
    );
  }

  /// Dialog to edit or delete row note
  void _showEditRowNoteDialog(int rowIndex) {
    final String currentNote = _rowNotes[rowIndex] ?? '';
    final controller = TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = ThemeService.isDarkMode;
        final goldColor = AppTheme.getGoldColor(ctx);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.mode_comment_outlined,
                color: isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed,
              ),
              const SizedBox(width: 10),
              Text(
                'template.note_title'.tr(namedArgs: {'n': '${rowIndex + 1}'}),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'template.note_desc'.tr(namedArgs: {'n': '${rowIndex + 1}'}),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF4F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: goldColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (currentNote.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() => _rowNotes.remove(rowIndex));
                  Navigator.pop(ctx);
                },
                child: Text('template.delete_note'.tr(), style: const TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFE2C474) : AppTheme.primaryRed,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final txt = controller.text.trim();
                setState(() {
                  if (txt.isEmpty) {
                    _rowNotes.remove(rowIndex);
                  } else {
                    _rowNotes[rowIndex] = txt;
                  }
                });
                Navigator.pop(ctx);
              },
              child: Text('template.save_note'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Reorderable Draggable Tile for each photo slot (Sized exactly to photo, 0% crop)
  Widget _buildDraggablePhotoTile(int index, Color borderColor, bool isDark, {bool isPreviewOnly = false}) {
    final photo = _selectedPhotos[index];
    final bool isHovered = _hoveredIndex == index && _draggingIndex != null && _draggingIndex != index;
    final Color goldColor = AppTheme.getGoldColor(context);

    if (isPreviewOnly) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 2.0,
          ),
        ),
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return _buildCroppedPhotoWidget(photo, constraints.maxWidth);
              },
            ),
            if (_isRightWrong && _selectedTemplate == CollageTemplateType.col2Vertical)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: index % 2 == 0 ? Colors.red : Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    index % 2 == 0 ? Icons.close : Icons.check,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.outfit(
                    color: goldColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DragTarget<int>(
      onWillAccept: (fromIndex) {
        if (fromIndex != null && fromIndex != index) {
          setState(() {
            _hoveredIndex = index;
          });
          return true;
        }
        return false;
      },
      onLeave: (fromIndex) {
        if (_hoveredIndex == index) {
          setState(() {
            _hoveredIndex = null;
          });
        }
      },
      onAccept: (fromIndex) {
        setState(() {
          final item = _selectedPhotos.removeAt(fromIndex);
          _selectedPhotos.insert(index, item);
          _draggingIndex = null;
          _hoveredIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: goldColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
          onDragStarted: () {
            setState(() {
              _draggingIndex = index;
            });
          },
          onDragEnd: (details) {
            setState(() {
              _draggingIndex = null;
              _hoveredIndex = null;
            });
          },
          onDraggableCanceled: (velocity, offset) {
            setState(() {
              _draggingIndex = null;
              _hoveredIndex = null;
            });
          },
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 2),
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
          child: GestureDetector(
            onDoubleTap: () => _showZoomAndCropDialog(photo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovered ? goldColor : borderColor,
                  width: isHovered ? 3.5 : 2.0,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: goldColor.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildCroppedPhotoWidget(photo, constraints.maxWidth);
                    },
                  ),

                  // Check/Cross Right-Wrong Badge in Top-Right Corner
                  if (_isRightWrong && _selectedTemplate == CollageTemplateType.col2Vertical)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: index % 2 == 0 ? Colors.red : Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          index % 2 == 0 ? Icons.close : Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  
                  // Number Index Badge in Top-Left Corner
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.outfit(
                          color: goldColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Action Badges in Top-Right Corner (Preview Icon + Crop/Zoom Icon)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Full Screen Preview Icon Button
                        InkWell(
                          onTap: () => _showFullScreenImagePreview(photo),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              shape: BoxShape.circle,
                              border: Border.all(color: goldColor, width: 1),
                            ),
                            child: Icon(Icons.fullscreen_rounded, size: 13, color: goldColor),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Crop & Zoom Editor Button
                        InkWell(
                          onTap: () => _showZoomAndCropDialog(photo),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              shape: BoxShape.circle,
                              border: Border.all(color: goldColor, width: 1),
                            ),
                            child: Icon(Icons.crop_rotate_rounded, size: 13, color: goldColor),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Remove Photo Button
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPhotos.removeAt(index);
                              _photoCrops.remove(photo.id);
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCroppedPhotoWidget(WatermarkedPhoto photo, double columnW) {
    final ui.Image? uiImg = _uiImageCache[photo.path];
    final crop = _photoCrops[photo.id] ?? const PhotoCropData();

    if (uiImg != null) {
      final double imgW = uiImg.width.toDouble();
      final double imgH = uiImg.height.toDouble();

      Rect srcRect;
      if (_photoSizeMode == PhotoSizeMode.square && crop.isDefault) {
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

      final double aspect = srcRect.width / srcRect.height;
      final double boxH = _photoSizeMode == PhotoSizeMode.square ? columnW : columnW / aspect;

      return SizedBox(
        width: columnW,
        height: boxH,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CustomPaint(
            painter: PhotoCanvasPainter(image: uiImg, srcRect: srcRect),
          ),
        ),
      );
    }

    final double aspect = _photoSizeMode == PhotoSizeMode.square ? 1.0 : (3.0 / 5.0);
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(photo.path),
          fit: _photoSizeMode == PhotoSizeMode.square ? BoxFit.cover : BoxFit.fitWidth,
        ),
      ),
    );
  }

  void _showZoomAndCropDialog(WatermarkedPhoto photo) {
    final ui.Image? uiImg = _uiImageCache[photo.path];
    if (uiImg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.loading_image'.trSafe())),
      );
      return;
    }

    final double imgW = uiImg.width.toDouble();
    final double imgH = uiImg.height.toDouble();

    final TransformationController transformController = TransformationController();

    const double viewportSize = 270.0;
    const double containerW = viewportSize;
    final double containerH = _photoSizeMode == PhotoSizeMode.square
        ? viewportSize
        : (viewportSize * (imgH / imgW)).clamp(160.0, 340.0);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final Color textPrim = AppTheme.getTextPrimary(context);
            final Color textSec = AppTheme.getTextSecondary(context);
            final Color goldColor = AppTheme.getGoldColor(context);

            return AlertDialog(
              backgroundColor: AppTheme.getSurfaceColor(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.crop_rotate_rounded, color: goldColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zoom & Crop Foto',
                      style: GoogleFonts.outfit(
                        color: textPrim,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cubit dengan 2 jari untuk zoom (perbesar/perkecil) dan geser posisi foto sesuai batas bingkai kolase.',
                    style: GoogleFonts.inter(color: textSec, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  // Interactive Viewport Frame
                  Container(
                    width: containerW,
                    height: containerH,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: goldColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: InteractiveViewer(
                        transformationController: transformController,
                        minScale: 1.0,
                        maxScale: 5.0,
                        clipBehavior: Clip.hardEdge,
                        child: Image.file(
                          File(photo.path),
                          width: containerW,
                          height: containerH,
                          fit: _photoSizeMode == PhotoSizeMode.square ? BoxFit.cover : BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.orangeAccent),
                        label: Text('common.reset_zoom'.tr(), style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12)),
                        onPressed: () {
                          transformController.value = Matrix4.identity();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('template.crop_cancel'.tr(), style: GoogleFonts.outfit(color: textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final cropData = _calculateCropFromMatrix(
                      matrix: transformController.value,
                      containerW: containerW,
                      containerH: containerH,
                      imgW: imgW,
                      imgH: imgH,
                    );
                    setState(() {
                      _photoCrops[photo.id] = cropData;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('template.save_crop'.tr(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  PhotoCropData _calculateCropFromMatrix({
    required Matrix4 matrix,
    required double containerW,
    required double containerH,
    required double imgW,
    required double imgH,
  }) {
    final double scale = matrix.getMaxScaleOnAxis();
    final double tx = matrix.getTranslation().x;
    final double ty = matrix.getTranslation().y;

    final double s0 = _photoSizeMode == PhotoSizeMode.square
        ? (containerW / imgW > containerH / imgH ? containerW / imgW : containerH / imgH)
        : (containerW / imgW < containerH / imgH ? containerW / imgW : containerH / imgH);

    final double rw = imgW * s0;
    final double rh = imgH * s0;

    final double ox = (containerW - rw) / 2.0;
    final double oy = (containerH - rh) / 2.0;

    final double ix = ox * scale + tx;
    final double iy = oy * scale + ty;

    final double iw = rw * scale;
    final double ih = rh * scale;

    final double leftPx = ((0.0 - ix) / iw) * imgW;
    final double topPx = ((0.0 - iy) / ih) * imgH;
    final double rightPx = ((containerW - ix) / iw) * imgW;
    final double bottomPx = ((containerH - iy) / ih) * imgH;

    final double leftNorm = (leftPx / imgW).clamp(0.0, 0.95);
    final double topNorm = (topPx / imgH).clamp(0.0, 0.95);
    final double rightNorm = (rightPx / imgW).clamp(leftNorm + 0.05, 1.0);
    final double bottomNorm = (bottomPx / imgH).clamp(topNorm + 0.05, 1.0);

    return PhotoCropData(
      left: leftNorm,
      top: topNorm,
      right: rightNorm,
      bottom: bottomNorm,
    );
  }

  Widget _buildAddPhotoTile(Color borderColor, bool isDark) {
    final Color goldColor = AppTheme.getGoldColor(context);

    return AspectRatio(
      aspectRatio: _photoSizeMode == PhotoSizeMode.square ? 1.0 : (3.0 / 5.0),
      child: InkWell(
        onTap: () async {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppTheme.getSurfaceColor(context),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (ctx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('common.source_photo'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.getTextPrimary(context))),
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryRed),
                      title: Text('common.camera'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final List<WatermarkedPhoto>? result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CameraScreen(isPickerMode: true)),
                        );
                        if (result != null && result.isNotEmpty && mounted) {
                          setState(() {
                            _selectedPhotos.addAll(result);
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryRed),
                      title: Text('common.gallery'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final List<WatermarkedPhoto>? result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GalleryScreen(isPickerMode: true)),
                        );
                        if (result != null && result.isNotEmpty && mounted) {
                          setState(() {
                            _selectedPhotos.addAll(result);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12, 
              width: 1, 
              style: BorderStyle.solid
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_a_photo_rounded,
                  color: AppTheme.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '+ ${'common.add_photo'.tr()}',
                style: GoogleFonts.inter(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImagePreview(WatermarkedPhoto photo) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.getGoldColor(context), width: 1.5),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PhotoCanvasPainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;

  PhotoCanvasPainter({required this.image, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant PhotoCanvasPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.srcRect != srcRect;
  }
}
