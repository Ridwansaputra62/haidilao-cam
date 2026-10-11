import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';
import 'package:haidilao_cam/core/services/locale_service.dart';
import 'package:haidilao_cam/core/services/photo_storage_service.dart';
import 'package:haidilao_cam/core/theme/app_theme.dart';
import 'package:haidilao_cam/screens/collage_screen.dart';
import 'package:haidilao_cam/screens/photo_view_screen.dart';

class GalleryScreen extends StatefulWidget {
  final List<WatermarkedPhoto>? initialSelectedPhotos;
  final bool isPickerMode;

  const GalleryScreen({
    super.key,
    this.initialSelectedPhotos,
    this.isPickerMode = false,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<WatermarkedPhoto> _allPhotos = [];
  List<WatermarkedPhoto> _filteredPhotos = [];
  PhotoFilter _selectedFilter = PhotoFilter.all;

  // Selection mode & checkmark set
  bool _isSelectionMode = false;
  final Set<String> _selectedPhotoIds = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isPickerMode) {
      _isSelectionMode = true;
    }
    if (widget.initialSelectedPhotos != null && widget.initialSelectedPhotos!.isNotEmpty) {
      _selectedPhotoIds.addAll(widget.initialSelectedPhotos!.map((p) => p.id));
      _isSelectionMode = true;
    }
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() => _isLoading = true);
    final photos = await PhotoStorageService.loadPhotos();
    if (mounted) {
      setState(() {
        _allPhotos = photos;
        _applyFilter(_selectedFilter);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(PhotoFilter filter) {
    setState(() {
      _selectedFilter = filter;
      _filteredPhotos = PhotoStorageService.filterPhotos(_allPhotos, filter);
      // Clean up selection when changing filter tab
      _selectedPhotoIds.removeWhere((id) => !_filteredPhotos.any((p) => p.id == id));
    });
  }

  void _toggleSelectPhoto(String id) {
    if (widget.isPickerMode) {
      final photo = _allPhotos.firstWhere((p) => p.id == id, orElse: () => _filteredPhotos.first);
      if (photo.isVideo) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kolase/Template hanya mendukung foto 📸'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    setState(() {
      if (_selectedPhotoIds.contains(id)) {
        _selectedPhotoIds.remove(id);
      } else {
        _selectedPhotoIds.add(id);
      }
      if (_selectedPhotoIds.isNotEmpty) {
        _isSelectionMode = true;
      }
    });
  }

  void _selectAllInFilter() {
    setState(() {
      _selectedPhotoIds.addAll(_filteredPhotos.map((p) => p.id));
      _isSelectionMode = true;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPhotoIds.clear();
      _isSelectionMode = widget.isPickerMode;
    });
  }

  /// Displays the deletion preview modal with checklist so user can review and uncheck items before deleting.
    void _shareSelectedPhotos() async {
    final selectedPhotos = _filteredPhotos
        .where((p) => _selectedPhotoIds.contains(p.id))
        .toList();
    if (selectedPhotos.isEmpty) return;

    final List<XFile> xFiles = selectedPhotos.map((p) => XFile(p.path)).toList();
    try {
      await Share.shareXFiles(
        xFiles,
        text: 'Foto dari HI CAM 📸',
      );
    } catch (e) {
      debugPrint('Error sharing photos: $e');
    }
  }

  ButtonStyle _build3DRedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFC62828),
      foregroundColor: Colors.white,
      elevation: 5,
      shadowColor: const Color(0xFF5D0000),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2),
      ),
    );
  }

  void _showDeletePreviewDialog() {
    final List<WatermarkedPhoto> targetPhotos =
        _filteredPhotos.where((p) => _selectedPhotoIds.contains(p.id)).toList();

    if (targetPhotos.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<WatermarkedPhoto> activeSelected =
                targetPhotos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
            final Color textPrim = AppTheme.getTextPrimary(context);
            final Color textSec = AppTheme.getTextSecondary(context);

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.delete_sweep, color: AppTheme.primaryRed, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'gallery.delete_preview_title'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrim,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: textSec),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'gallery.delete_preview_desc'.tr(),
                    style: GoogleFonts.inter(color: textSec, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Horizontal / Grid Checklist Preview
                  Expanded(
                    child: activeSelected.isEmpty
                        ? Center(
                            child: Text(
                              'gallery.all_deselected'.tr(),
                              style: GoogleFonts.inter(color: Colors.white54),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                            itemCount: targetPhotos.length,
                            itemBuilder: (context, index) {
                              final photo = targetPhotos[index];
                              final isChecked = _selectedPhotoIds.contains(photo.id);

                              return GestureDetector(
                                onTap: () {
                                  _toggleSelectPhoto(photo.id);
                                  setModalState(() {});
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isChecked ? AppTheme.primaryRed : Colors.grey.shade800,
                                          width: 2,
                                        ),
                                        image: DecorationImage(
                                          image: FileImage(photo.thumbnailFile),
                                          fit: BoxFit.cover,
                                          colorFilter: isChecked
                                              ? null
                                              : ColorFilter.mode(
                                                  Colors.black.withOpacity(0.6),
                                                  BlendMode.darken,
                                                ),
                                        ),
                                      ),
                                    ),

                                    // Checkbox Overlay Badge
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: isChecked ? AppTheme.primaryRed : Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isChecked ? Icons.check : Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),

                                    // Date Stamp Label
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          LocaleService.time(photo.dateTaken),
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Action Buttons (Cancel / Confirm Delete)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: activeSelected.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await _confirmDeletePhotos(activeSelected);
                                },
                          child: Text('gallery.delete_btn'.tr(namedArgs: {'count': '${activeSelected.length}'})),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePhotos(List<WatermarkedPhoto> photosToDelete) async {
    final messenger = ScaffoldMessenger.of(context);
    final count = await PhotoStorageService.deletePhotos(photosToDelete);
    if (mounted) {
      _selectedPhotoIds.clear();
      _isSelectionMode = false;
      await _loadGallery();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceDark,
          content: Row(
            children: [
              const Icon(Icons.delete_forever, color: AppTheme.haidilaoGold),
              const SizedBox(width: 12),
              Text(
                'gallery.delete_success'.tr(namedArgs: {'count': '$count'}),
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int selectedCount = _selectedPhotoIds.length;
    final Color bgColor = AppTheme.getBackgroundColor(context);
    final Color surfaceColor = AppTheme.getSurfaceColor(context);
    final Color cardColor = AppTheme.getCardColor(context);
    final Color textSecondary = AppTheme.getTextSecondary(context);
    final Color goldColor = AppTheme.getGoldColor(context);

    LocaleService.update(context.locale);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? 'gallery.n_selected'.tr(namedArgs: {'count': '$selectedCount'})
            : 'gallery.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_filteredPhotos.isNotEmpty) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) {
                    _selectedPhotoIds.clear();
                  }
                });
              },
              child: Text(
                _isSelectionMode ? 'common.done'.tr() : 'common.select'.tr(),
                style: TextStyle(color: goldColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 1. Filter Chips Header (Hari Ini, Minggu Ini, Bulan Ini, Semua Foto)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            color: surfaceColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PhotoFilter.values.map((filter) {
                  final bool isSelected = _selectedFilter == filter;
                  final List<WatermarkedPhoto> countInFilter =
                      PhotoStorageService.filterPhotos(_allPhotos, filter);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text('${filter.label} (${countInFilter.length})'),
                      selectedColor: AppTheme.primaryRed,
                      checkmarkColor: Colors.white,
                      backgroundColor: cardColor,
                      labelStyle: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (bool selected) {
                        if (selected) {
                          _applyFilter(filter);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 2. Selection Mode Controls Bar (Select All / Deselect All)
          if (_isSelectionMode && _filteredPhotos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'gallery.n_marked'.tr(namedArgs: {
                        'count': '$selectedCount',
                        'filter': _selectedFilter.label,
                      }),
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(
                      selectedCount == _filteredPhotos.length ? Icons.deselect : Icons.select_all,
                      size: 16,
                      color: goldColor,
                    ),
                    label: Text(
                      selectedCount == _filteredPhotos.length ? 'common.deselect_all'.tr() : 'common.select_all'.tr(),
                      style: GoogleFonts.outfit(color: goldColor, fontSize: 13),
                    ),
                    onPressed: () {
                      if (selectedCount == _filteredPhotos.length) {
                        _deselectAll();
                      } else {
                        _selectAllInFilter();
                      }
                    },
                  ),
                ],
              ),
            ),

          // 3. Photos Grid View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
                : _filteredPhotos.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _filteredPhotos.length,
                        itemBuilder: (context, index) {
                          final photo = _filteredPhotos[index];
                          final isSelected = _selectedPhotoIds.contains(photo.id);
                          final bool isLongImage = photo.path.toLowerCase().contains('kolase') ||
                              photo.path.toLowerCase().contains('collage') ||
                              photo.path.toLowerCase().contains('long');

                          return GestureDetector(
                            onTap: () {
                              if (_isSelectionMode && !widget.isPickerMode) {
                                _toggleSelectPhoto(photo.id);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PhotoViewScreen(
                                      photo: photo,
                                      onDelete: () async {
                                        await PhotoStorageService.deletePhotos([photo]);
                                        _loadGallery();
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              _toggleSelectPhoto(photo.id);
                            },
                            child: Stack(
                              children: [
                                // Photo Thumbnail
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.black26,
                                    border: isSelected
                                        ? Border.all(color: AppTheme.haidilaoGold, width: 3)
                                        : null,
                                    image: (photo.hasThumbnail || !photo.isVideo)
                                        ? DecorationImage(
                                            image: ResizeImage(FileImage(photo.thumbnailFile), width: 300),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: (photo.isVideo && !photo.hasThumbnail)
                                      ? const Center(
                                          child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 36),
                                        )
                                      : null,
                                ),

                                // Video Play Icon Overlay in center
                                if (photo.isVideo)
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white70,
                                      size: 34,
                                    ),
                                  ),

                                // Gradient Overlay for timestamp
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.8),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      LocaleService.galleryDateTime(photo.dateTaken),
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),

                                // Video Badge or Long Image Badge Indicator
                                if (photo.isVideo)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.redAccent, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 12),
                                          const SizedBox(width: 3),
                                          Text(
                                            'VIDEO',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (isLongImage)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.haidilaoGold, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.swap_vert_rounded, color: AppTheme.haidilaoGold, size: 12),
                                          const SizedBox(width: 3),
                                          Text(
                                            'common.long_image'.tr(),
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Checkbox Indicator
                                if (_isSelectionMode)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _toggleSelectPhoto(photo.id),
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected ? AppTheme.primaryRed : Colors.black45,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Icon(
                                              isSelected ? Icons.check : null,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // 4. Selection Mode Bottom Action Bar (Buat Kolase & Hapus)
      bottomNavigationBar: _selectedPhotoIds.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  border: Border(top: BorderSide(color: AppTheme.getBorderColor(context))),
                ),
                child: Row(
                  children: [
                    // Button 1: KOLASE
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5D0000).withOpacity(0.6),
                              offset: const Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: _build3DRedButtonStyle(),
                          onPressed: () {
                            final selectedPhotos = _filteredPhotos
                                .where((p) => _selectedPhotoIds.contains(p.id))
                                .toList();
                            if (selectedPhotos.isNotEmpty) {
                              if (widget.isPickerMode) {
                                Navigator.pop(context, selectedPhotos);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CollageScreen(photos: selectedPhotos),
                                  ),
                                ).then((updated) {
                                  if (updated == true) {
                                    _deselectAll();
                                    _loadGallery();
                                  }
                                });
                              }
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white, size: 18),
                              const SizedBox(height: 2),
                              FittedBox(
                                child: Text(
                                  widget.isPickerMode
                                      ? 'gallery.save_btn'.tr(namedArgs: {'count': '$selectedCount'})
                                      : 'gallery.collage_btn'.tr(namedArgs: {'count': '$selectedCount'}),
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Button 2: BAGIKAN (SHARE)
                    if (!widget.isPickerMode) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5D0000).withOpacity(0.6),
                                offset: const Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: _build3DRedButtonStyle(),
                            onPressed: _shareSelectedPhotos,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                                const SizedBox(height: 2),
                                FittedBox(
                                  child: Text(
                                    'gallery.share_btn'.tr(namedArgs: {'count': '$selectedCount'}),
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Button 3: HAPUS
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5D0000).withOpacity(0.6),
                                offset: const Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: _build3DRedButtonStyle(),
                            onPressed: _showDeletePreviewDialog,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                const SizedBox(height: 2),
                                FittedBox(
                                  child: Text(
                                    'gallery.delete_btn'.tr(namedArgs: {'count': '$selectedCount'}),
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final Color textPrimary = AppTheme.getTextPrimary(context);
    final Color textSecondary = AppTheme.getTextSecondary(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.photo_library_outlined, size: 54, color: textSecondary.withOpacity(0.5)),
          ),
          const SizedBox(height: 18),
          Text(
            'common.no_data'.tr(),
            style: GoogleFonts.outfit(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'gallery.no_photo_in_filter'.tr(namedArgs: {'filter': _selectedFilter.label}),
            style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
