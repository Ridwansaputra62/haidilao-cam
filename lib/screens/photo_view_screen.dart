import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:video_player/video_player.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';
import 'package:haidilao_cam/core/services/locale_service.dart';
import 'package:haidilao_cam/core/services/theme_service.dart';
import 'package:haidilao_cam/core/services/video_watermark_service.dart';
import 'package:haidilao_cam/core/theme/app_theme.dart';

class PhotoViewScreen extends StatefulWidget {
  final WatermarkedPhoto photo;
  final VoidCallback onDelete;

  const PhotoViewScreen({
    super.key,
    required this.photo,
    required this.onDelete,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    if (widget.photo.isVideo) {
      _initVideoPlayer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_videoController != null && _videoController!.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted && _videoController != null && _videoController!.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      final controller = VideoPlayerController.file(File(widget.photo.path));
      await controller.initialize();
      controller.setLooping(true);
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() {
          _videoController = controller;
          _isVideoInitialized = true;
        });
        controller.play();
        _startHideControlsTimer();
      }
    } catch (e) {
      debugPrint('Error initializing in-app video player: $e');
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showInfoModal(BuildContext context) {
    final String filename = widget.photo.path.split(Platform.pathSeparator).last;
    final String dtLabel = '${LocaleService.dayName(widget.photo.dateTaken)}, '
        '${LocaleService.shortDate(widget.photo.dateTaken)} '
        '${LocaleService.time(widget.photo.dateTaken)}';

    final Color surfaceColor = AppTheme.getSurfaceColor(context);
    final Color textPrimary = AppTheme.getTextPrimary(context);
    final Color textSecondary = AppTheme.getTextSecondary(context);
    final Color goldColor = AppTheme.getGoldColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Title Header
              Row(
                children: [
                  Icon(Icons.info_rounded, color: goldColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'photo_view.info_title'.tr(),
                    style: GoogleFonts.outfit(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: AppTheme.getBorderColor(context), height: 20),

              _buildInfoRow(
                context: context,
                icon: widget.photo.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                label: 'photo_view.file_name'.tr(),
                value: filename,
              ),
              const SizedBox(height: 14),

              _buildInfoRow(
                context: context,
                icon: Icons.sd_storage_rounded,
                label: 'photo_view.file_size'.tr(),
                value: widget.photo.formattedSize,
              ),
              const SizedBox(height: 14),

              _buildInfoRow(
                context: context,
                icon: Icons.access_time_filled_rounded,
                label: 'photo_view.date_time'.tr(),
                value: dtLabel,
              ),
              const SizedBox(height: 14),

              _buildInfoRow(
                context: context,
                icon: Icons.location_on_rounded,
                label: 'photo_view.location'.tr(),
                value: widget.photo.locationText,
              ),
              const SizedBox(height: 14),

              _buildInfoRow(
                context: context,
                icon: Icons.folder_open_rounded,
                label: 'photo_view.file_path'.tr(),
                value: widget.photo.path,
                isPath: true,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool isPath = false,
  }) {
    final Color goldColor = AppTheme.getGoldColor(context);
    final Color textPrimary = AppTheme.getTextPrimary(context);
    final Color textSecondary = AppTheme.getTextSecondary(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: goldColor.withOpacity(0.9), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: GoogleFonts.inter(
                  color: isPath ? textSecondary : textPrimary,
                  fontSize: isPath ? 11 : 13,
                  fontWeight: isPath ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    LocaleService.update(context.locale);

    final String filename = widget.photo.path.split(Platform.pathSeparator).last;
    final bool isDark = ThemeService.isDarkMode;
    final Color goldColor = AppTheme.getGoldColor(context);
    final Color surfaceColor = AppTheme.getSurfaceColor(context);
    final Color textPrimary = AppTheme.getTextPrimary(context);
    final Color textSecondary = AppTheme.getTextSecondary(context);

    final bool isLongImage = widget.photo.path.toLowerCase().contains('kolase') ||
        widget.photo.path.toLowerCase().contains('collage') ||
        widget.photo.path.toLowerCase().contains('long');

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFF18181B),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.75) : const Color(0xFF18181B).withOpacity(0.85),
        title: Row(
          children: [
            Expanded(
              child: Text(
                filename,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.photo.isVideo)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'VIDEO',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else if (isLongImage)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.haidilaoGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.haidilaoGold, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_vert_rounded, color: AppTheme.haidilaoGold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'photo_view.long_image_badge'.tr(),
                      style: GoogleFonts.outfit(color: AppTheme.haidilaoGold, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // Information Icon Button
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: goldColor, size: 24),
            onPressed: () => _showInfoModal(context),
            tooltip: 'photo_view.tooltip_info'.tr(),
          ),

          // Delete Photo Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: surfaceColor,
                  title: Text(
                    'photo_view.delete_title'.tr(),
                    style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'photo_view.delete_confirm'.tr(),
                    style: GoogleFonts.inter(color: textSecondary),
                  ),
                  actions: [
                    TextButton(
                      child: Text('common.cancel'.tr(), style: TextStyle(color: textSecondary)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                      child: Text('common.delete'.tr()),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onDelete();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
            tooltip: 'photo_view.tooltip_delete'.tr(),
          ),
        ],
      ),
      body: widget.photo.isVideo
          ? _buildVideoPlayerView()
          : (isLongImage
              ? SingleChildScrollView(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.file(
                      File(widget.photo.path),
                      width: MediaQuery.of(context).size.width,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                )
              : Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      File(widget.photo.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                )),
    );
  }

  Widget _buildVideoPlayerView() {
    if (!_isVideoInitialized || _videoController == null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (widget.photo.hasThumbnail)
            Center(
              child: Image.file(
                widget.photo.thumbnailFile,
                fit: BoxFit.contain,
              ),
            ),
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed),
            ),
          ),
        ],
      );
    }

    final isPlaying = _videoController!.value.isPlaying;
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    return Stack(
      children: [
        // 1. Center Interactive Video Player with Tap-to-Toggle-Controls
        Center(
          child: GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_videoController!),
                  // Big Center Play Icon when paused
                  if (!isPlaying)
                    GestureDetector(
                      onTap: () {
                        _videoController!.play();
                        _startHideControlsTimer();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.haidilaoGold, width: 2),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 2. Sleek Bottom Control Bar (Progress, Time, Play/Pause, Open External with Auto-Hide)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Bar
                      VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppTheme.primaryRed,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),

                      // Bottom Action Row
                      Row(
                        children: [
                          // Play / Pause Button
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isPlaying) {
                                  _videoController!.pause();
                                  _hideControlsTimer?.cancel();
                                  _showControls = true;
                                } else {
                                  _videoController!.play();
                                  _startHideControlsTimer();
                                }
                              });
                            },
                          ),

                          // Time Indicator
                          Text(
                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const Spacer(),

                          // Open External Player Shortcut
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                            tooltip: 'Buka di Pemutar Eksternal',
                            onPressed: () => VideoWatermarkService.openVideo(widget.photo.path),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
