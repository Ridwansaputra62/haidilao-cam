import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gal/gal.dart';
import 'package:haidilao_cam/core/services/location_service.dart';
import 'package:haidilao_cam/core/services/photo_storage_service.dart';
import 'package:haidilao_cam/core/services/theme_service.dart';
import 'package:haidilao_cam/core/services/video_watermark_service.dart';
import 'package:haidilao_cam/core/services/watermark_service.dart';
import 'package:haidilao_cam/core/theme/app_theme.dart';
import 'package:haidilao_cam/screens/collage_screen.dart';
import 'package:haidilao_cam/screens/gallery_screen.dart';
import 'package:haidilao_cam/screens/comparison_template_screen.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';
import 'package:haidilao_cam/core/services/app_settings_service.dart';
import 'package:haidilao_cam/core/services/locale_service.dart';

class CameraScreen extends StatefulWidget {
  final bool isPickerMode;
  
  const CameraScreen({super.key, this.isPickerMode = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  // Fly-to-Gallery capture animation state
  File? _flyingPhotoFile;
  bool _showShutterFlash = false;
  int _flyAnimKey = 0;


  // Watermark toggle state (Default: ON, Logo Standar per user request)
  bool _isWatermarkVisible = AppSettingsService.watermarkVisible;
  String _selectedLogoPath = AppSettingsService.watermarkLogo;

  // Video Recording & Torch Senter state
  bool _isRecordingVideo = false;
  Timer? _videoTimer;
  int _videoRecordSeconds = 0;

  String _formatDuration(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    final String minsStr = mins.toString().padLeft(2, '0');
    final String secsStr = secs.toString().padLeft(2, '0');
    return '$minsStr:$secsStr';
  }

  // Flash mode, Mode selection & Aspect ratio state
  FlashMode _flashMode = FlashMode.off;
  String _selectedMode = 'camera.mode_watermark_on'.tr();
  String _aspectRatioMode = '3:5';
  double _aspectRatioValue = 3 / 5;

  // Tap-to-Focus & Zoom level state
  Offset? _focusPoint;
  bool _showFocusCircle = false;
  Timer? _focusTimer;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;

  final FixedExtentScrollController _zoomScrollController = FixedExtentScrollController(initialItem: 0);
  final List<double> _zoomLevels = List.generate(31, (i) => double.parse((1.0 + i * 0.1).toStringAsFixed(1)));
  double _viewfinderWidth = 390.0;

  void _toggleAspectRatio() {
    setState(() {
      if (_aspectRatioMode == '3:5') {
        _aspectRatioMode = '4:3';
        _aspectRatioValue = 3 / 4;
      } else if (_aspectRatioMode == '4:3') {
        _aspectRatioMode = '1:1';
        _aspectRatioValue = 1.0;
      } else {
        _aspectRatioMode = '3:5';
        _aspectRatioValue = 3 / 5;
      }
    });
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final newZoom = zoom.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(newZoom);
      setState(() {
        _currentZoom = newZoom;
      });
    } catch (e) {
      debugPrint('Error setting zoom: $e');
    }
  }

  Future<void> _onTapToFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final Offset localPosition = details.localPosition;
    final double dx = (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final double dy = (localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);

    setState(() {
      _focusPoint = localPosition;
      _showFocusCircle = true;
    });

    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showFocusCircle = false;
        });
      }
    });

    try {
      await _controller!.setFocusPoint(Offset(dx, dy));
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposurePoint(Offset(dx, dy));
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('Focus error: $e');
    }
  }

  // Location state
  LocationInfo? _currentLocation;
  bool _isLoadingLocation = true;

  // Live Clock state
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // Storage & Gallery thumbnail state
  int _photoCount = 0;
  File? _lastPhotoFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _fetchLocation();
    _loadLatestPhotoInfo();

    // Start live clock update every 1 second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_controller == null || !_controller!.value.isInitialized) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer.cancel();
    _videoTimer?.cancel();
    _zoomScrollController.dispose();
    _isCameraInitialized = false;
    final oldController = _controller;
    _controller = null;
    oldController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      } else {
        _isCameraInitialized = false;
      }
      final oldController = _controller;
      _controller = null;
      oldController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null || !_controller!.value.isInitialized) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        if (_selectedCameraIndex >= _cameras.length) {
          _selectedCameraIndex = 0;
        }
        await _onNewCameraSelected(_cameras[_selectedCameraIndex]);
      } else {
        if (mounted) setState(() => _isCameraInitialized = false);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      final oldController = _controller;
      _controller = null;
      await oldController?.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await cameraController.initialize();
      try {
        await cameraController.setFlashMode(_flashMode);
      } catch (_) {}
      try {
        _minZoom = await cameraController.getMinZoomLevel();
        _maxZoom = await cameraController.getMaxZoomLevel();
        _currentZoom = _minZoom;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _controller = cameraController;
          _isCameraInitialized = true;
        });
      } else {
        await cameraController.dispose();
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      try {
        await cameraController.dispose();
      } catch (_) {}
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoadingLocation = true);
    final location = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = location;
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadLatestPhotoInfo() async {
    final photos = await PhotoStorageService.loadPhotos();
    if (mounted) {
      final DateTime now = DateTime.now();
      final todayPhotos = photos.where((p) =>
        p.dateTaken.year == now.year &&
        p.dateTaken.month == now.month &&
        p.dateTaken.day == now.day
      ).toList();

      setState(() {
        _photoCount = todayPhotos.length;
        if (photos.isNotEmpty) {
          _lastPhotoFile = File(photos.first.thumbnailPath);
        } else {
          _lastPhotoFile = null;
        }
      });
    }
  }

  void _triggerCaptureAnimation(File file) {
    if (!mounted) return;
    setState(() {
      _showShutterFlash = true;
      _flyingPhotoFile = file;
      _flyAnimKey++;
    });

    // Fade out white shutter flash after 120ms
    Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _showShutterFlash = false;
        });
      }
    });

    // Reset flying thumbnail after 550ms animation completes
    Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        setState(() {
          _flyingPhotoFile = null;
        });
        _loadLatestPhotoInfo();
      }
    });
  }

  
  void _toggleWatermark() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Text('camera.watermark_settings'.trSafe(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
              const SizedBox(height: 20),
              SwitchListTile(
                title: Text('camera.show_watermark'.trSafe(), style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context))),
                value: _isWatermarkVisible,
                activeColor: AppTheme.primaryRed,
                onChanged: (val) {
                  setState(() => _isWatermarkVisible = val);
                  AppSettingsService.setWatermarkVisible(val);
                  Navigator.pop(ctx);
                },
              ),
              if (_isWatermarkVisible) ...[
                const Divider(),
                ListTile(
                  leading: Image.asset('assets/images/haidilao_logo.png', width: 40),
                  title: Text('camera.logo_standard'.trSafe(), style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context))),
                  trailing: _selectedLogoPath == 'assets/images/haidilao_logo.png' ? const Icon(Icons.check_circle, color: AppTheme.primaryRed) : null,
                  onTap: () {
                    setState(() => _selectedLogoPath = 'assets/images/haidilao_logo.png');
                    AppSettingsService.setWatermarkLogo('assets/images/haidilao_logo.png');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Image.asset('assets/images/hi_logo.png', width: 40),
                  title: Text('camera.logo_hi'.trSafe(), style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context))),
                  trailing: _selectedLogoPath == 'assets/images/hi_logo.png' ? const Icon(Icons.check_circle, color: AppTheme.primaryRed) : null,
                  onTap: () {
                    setState(() => _selectedLogoPath = 'assets/images/hi_logo.png');
                    AppSettingsService.setWatermarkLogo('assets/images/hi_logo.png');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Image.asset('assets/images/haidilao_panda.png', width: 40),
                  title: Text('camera.logo_panda'.trSafe(), style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context))),
                  trailing: _selectedLogoPath == 'assets/images/haidilao_panda.png' ? const Icon(Icons.check_circle, color: AppTheme.primaryRed) : null,
                  onTap: () {
                    setState(() => _selectedLogoPath = 'assets/images/haidilao_panda.png');
                    AppSettingsService.setWatermarkLogo('assets/images/haidilao_panda.png');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Image.asset('assets/images/haidilao_panda2.png', width: 40),
                  title: Text('camera.logo_panda2'.trSafe(), style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context))),
                  trailing: _selectedLogoPath == 'assets/images/haidilao_panda2.png' ? const Icon(Icons.check_circle, color: AppTheme.primaryRed) : null,
                  onTap: () {
                    setState(() => _selectedLogoPath = 'assets/images/haidilao_panda2.png');
                    AppSettingsService.setWatermarkLogo('assets/images/haidilao_panda2.png');
                    Navigator.pop(ctx);
                  },
                ),
              ]
            ],
            ),
          ),
        );
      }
    );
  }  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecordingVideo) {
      await _stopVideoRecording();
    } else {
      await _startVideoRecording();
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_isCameraInitialized || !_controller!.value.isInitialized) {
      await _initializeCamera();
      if (_controller == null || !_isCameraInitialized || !_controller!.value.isInitialized) return;
    }
    if (_controller!.value.isRecordingVideo) return;

    try {
      await _controller!.prepareForVideoRecording();
      await _controller!.startVideoRecording();
      _videoRecordSeconds = 0;
      _videoTimer?.cancel();
      _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _videoRecordSeconds++;
          });
        }
      });
      setState(() {
        _isRecordingVideo = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text('camera.recording_started'.trSafe()),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on CameraException catch (e) {
      debugPrint('Error starting video recording: $e');
      // If native camera session/ImageReader was invalidated, cleanly re-initialize
      await _initializeCamera();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('${'camera.recording_failed'.trSafe()}: ${e.description ?? e.code}'),
          ),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    final double fallbackWidth = MediaQuery.of(context).size.width;
    final double vfWidth = _viewfinderWidth > 0 ? _viewfinderWidth : fallbackWidth;
    final String locStr = _currentLocation != null ? _currentLocation!.address : 'Haidilao Store Area';

    _videoTimer?.cancel();

    try {
      final XFile rawVideoXFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecordingVideo = false;
        _videoRecordSeconds = 0;
      });

      final File rawVideoFile = File(rawVideoXFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('camera.saving_video'.trSafe()),
              ],
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final File? savedVideo = await VideoWatermarkService.applyWatermarkAndSave(
        inputVideoFile: rawVideoFile,
        locationText: locStr,
        targetAspectRatio: _aspectRatioValue,
        viewfinderWidth: vfWidth,
        logoAssetPath: _selectedLogoPath,
        isWatermarkVisible: _isWatermarkVisible,
        saveToPublicGallery: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text('camera.recording_saved'.trSafe()),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (savedVideo != null && savedVideo.existsSync()) {
          final String dotIndex = savedVideo.path.lastIndexOf('.') != -1
              ? savedVideo.path.substring(0, savedVideo.path.lastIndexOf('.'))
              : savedVideo.path;
          final File thumbFile = File('${dotIndex}_thumb.jpg');
          if (thumbFile.existsSync()) {
            _triggerCaptureAnimation(thumbFile);
          } else {
            _triggerCaptureAnimation(savedVideo);
          }
          await _loadLatestPhotoInfo();
        }
      }
    } on CameraException catch (e) {
      debugPrint('Error stopping video recording: $e');
    } catch (e) {
      debugPrint('Error processing video watermark: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _onNewCameraSelected(_cameras[_selectedCameraIndex]);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    final double fallbackWidth = MediaQuery.of(context).size.width;
    final double vfWidth = _viewfinderWidth > 0 ? _viewfinderWidth : fallbackWidth;
    final double targetRatio = _aspectRatioValue;
    final LocationInfo? locInfo = _currentLocation;
    final bool applyWm = _isWatermarkVisible;

    setState(() => _isCapturing = true);

    try {
      final XFile rawPhoto = await _controller!.takePicture();
      final File rawFile = File(rawPhoto.path);

      // Instantly release shutter button state & trigger fly animation into gallery icon
      if (mounted) {
        if (!widget.isPickerMode) {
          setState(() => _isCapturing = false);
          _triggerCaptureAnimation(rawFile);
        } else {
          // If in picker mode, keep capturing state true to show loading
        }
      }

      // Process watermark encoding
      Future<void> processPhoto() async {
        try {
          final File rawFile = File(rawPhoto.path);
          final String locationStr = locInfo != null ? locInfo.address : 'Haidilao Store Area';

          File? savedPhoto;
          if (applyWm) {
            savedPhoto = await WatermarkService.applyWatermarkAndSave(
              imageFile: rawFile,
              locationText: locationStr,
              targetAspectRatio: targetRatio,
              viewfinderWidth: vfWidth,
              latitude: locInfo?.latitude,
              longitude: locInfo?.longitude,
              logoAssetPath: _selectedLogoPath,
            );
          } else {
            // Save clean photo without watermark to Gal album
            final Directory dir = await WatermarkService.getHaidilaoCameraDirectory();
            final String filename = 'HDL_PHOTO_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final String targetPath = '${dir.path}${Platform.pathSeparator}$filename';
            savedPhoto = await rawFile.copy(targetPath);
            try {
              await Gal.putImage(savedPhoto.path, album: 'HI CAM');
            } catch (_) {}
          }

          if (await rawFile.exists()) {
            await rawFile.delete();
          }

          if (savedPhoto != null && mounted) {
            _loadLatestPhotoInfo();
            if (widget.isPickerMode) {
              final photoMeta = WatermarkedPhoto(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                path: savedPhoto.path,
                dateTaken: DateTime.now(),
                branchName: locationStr,
                locationText: locationStr,
                fileSize: await savedPhoto.length(),
              );
              if (mounted) Navigator.pop(context, [photoMeta]);
            }
          }
        } catch (err) {
          debugPrint('Background photo save error: $err');
          if (mounted && widget.isPickerMode) setState(() => _isCapturing = false);
        }
      }

      if (widget.isPickerMode) {
        await processPhoto();
      } else {
        Future.microtask(processPhoto);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('${'camera.capture_failed'.trSafe()}: $e'),
          ),
        );
      }
    }
  }

  void _openGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GalleryScreen()),
    );
    _loadLatestPhotoInfo();
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (ctx) {
        final Color surfaceColor = AppTheme.getSurfaceColor(context);
        final Color textPrimary = AppTheme.getTextPrimary(context);
        final Color goldColor = AppTheme.getGoldColor(context);
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.language_rounded, color: goldColor, size: 26),
              const SizedBox(width: 10),
              Text(
                'language.title'.tr(),
                style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Bahasa Indonesia', style: GoogleFonts.outfit(color: textPrimary)),
                onTap: () { context.setLocale(const Locale('id')); Navigator.pop(ctx); },
              ),
              ListTile(
                title: Text('English', style: GoogleFonts.outfit(color: textPrimary)),
                onTap: () { context.setLocale(const Locale('en')); Navigator.pop(ctx); },
              ),
              ListTile(
                title: Text('简体中文', style: GoogleFonts.outfit(color: textPrimary)),
                onTap: () { context.setLocale(const Locale('zh')); Navigator.pop(ctx); },
              ),
            ],
          ),
        );
      },
    );
  }  @override
  Widget build(BuildContext context) {
    LocaleService.update(context.locale);
    final Color bgColor = AppTheme.getBackgroundColor(context);
    final Color surfaceColor = AppTheme.getSurfaceColor(context);
    final Color cardColor = AppTheme.getCardColor(context);
    final bool isDark = ThemeService.isDarkMode;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Ultra Elegant Top Title Bar OUTSIDE camera frame with Theme Switcher
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: surfaceColor,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left-aligned Language Selector Button (Bahasa Indonesia, English, Mandarin)
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: Icon(
                        Icons.language_rounded,
                        color: isDark ? AppTheme.haidilaoGold : AppTheme.primaryRed,
                        size: 24,
                      ),
                      onPressed: _showLanguageSelector,
                      tooltip: 'Pilih Bahasa (Indonesia, English, 中文)',
                    ),
                  ),

                  // HI CAM Center Title Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFD32F2F)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC62828).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.7), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppTheme.haidilaoGold, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'HI CAM',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.2,
                            shadows: const [
                              Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, color: AppTheme.haidilaoGold, size: 14),
                      ],
                    ),
                  ),

                  // Right-aligned Theme Switcher Button
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: isDark ? AppTheme.haidilaoGold : AppTheme.primaryRed,
                        size: 22,
                      ),
                      onPressed: () => ThemeService.toggleTheme(),
                      tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
                    ),
                  ),
                ],
              ),
            ),

            // 2. Full-Width Camera Viewfinder (Mentok 100% Kiri & Kanan Tanpa Margin/Putih di Samping)
            Expanded(
              child: Container(
                width: double.infinity,
                color: surfaceColor,
                child: Center(
                  child: SizedBox(
                    width: double.infinity, // Mentok 100% lebar layar kiri-kanan!
                    child: AspectRatio(
                      aspectRatio: _aspectRatioValue,
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _viewfinderWidth = constraints.maxWidth;
                            return Stack(
                              children: [
                                // 1. Camera Viewfinder Stream WITH Scoped Tap-To-Focus GestureDetector
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) => _onTapToFocus(details, constraints),
                                    child: (_isCameraInitialized && _controller != null && _controller!.value.isInitialized)
                                        ? FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: _controller!.value.previewSize?.height ?? 1,
                                              height: _controller!.value.previewSize?.width ?? 1,
                                              child: CameraPreview(_controller!),
                                            ),
                                          )
                                        : const Center(
                                            child: CircularProgressIndicator(color: AppTheme.primaryRed),
                                          ),
                                  ),
                                ),

                                // 2. Tap-to-Focus Circle Ring Indicator
                                if (_showFocusCircle && _focusPoint != null)
                                  Positioned(
                                    left: _focusPoint!.dx - 32,
                                    top: _focusPoint!.dy - 32,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 1.4, end: 1.0),
                                      duration: const Duration(milliseconds: 200),
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppTheme.haidilaoGold, width: 2),
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.center_focus_weak_rounded, color: AppTheme.haidilaoGold, size: 28),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                // 3. Top Control Bar INSIDE Camera Frame (Flash, Ratio Setting, Flip Camera)
                                Positioned(
                                  top: 12,
                                  left: 16,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: () {}, // Absorb tap so focus ring does not trigger
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Flash Button
                                          IconButton(
                                            icon: Icon(
                                              _flashMode == FlashMode.off
                                                  ? Icons.flash_off_rounded
                                                  : _flashMode == FlashMode.auto
                                                      ? Icons.flash_auto_rounded
                                                      : _flashMode == FlashMode.always
                                                          ? Icons.flash_on_rounded
                                                          : Icons.highlight_rounded,
                                              color: _flashMode != FlashMode.off ? AppTheme.haidilaoGold : Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: _toggleFlash,
                                            tooltip: 'Flash',
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                          ),

                                          const SizedBox(width: 12),

                                          // Camera Ratio Setting Button (3:5 / 4:3 / 1:1)
                                          InkWell(
                                            onTap: _toggleAspectRatio,
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.white30),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _aspectRatioMode,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 12),

                                          // Camera Switcher (Front / Rear)
                                          IconButton(
                                            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 20),
                                            onPressed: _switchCamera,
                                            tooltip: 'camera.btn_switch_camera'.trSafe(),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Recording Timer Indicator Badge (When Recording Video)
                                if (_isRecordingVideo)
                                  Positioned(
                                    top: 64,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.redAccent, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black45, blurRadius: 6),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              'REC ${_formatDuration(_videoRecordSeconds)}',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // 4. TimeMark Style Live Watermark Overlay (Bottom Left Area)
                                if (_isWatermarkVisible)
                                  Positioned(
                                  left: 16,
                                  right: 74,
                                  bottom: 24,
                                  child: GestureDetector(
                                    onTap: _toggleWatermark, // Tap watermark overlay to toggle visibility
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Dynamic Layout based on logo
                                        if (_selectedLogoPath == 'assets/images/haidilao_logo.png') ...[
                                          // Standard Layout
                                          Image.asset(
                                            _selectedLogoPath,
                                            height: 54,
                                            fit: BoxFit.contain,
                                          ),
                                          const SizedBox(height: 6),
                                        // Time, Vertical Line Divider, Date & Day Block
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              DateFormat('HH:mm').format(_now),
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 38,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -1,
                                                height: 1,
                                                shadows: const [
                                                  Shadow(offset: Offset(1, 1), blurRadius: 5, color: Colors.black54),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 1.5,
                                              height: 30,
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  DateFormat('dd/MM/yyyy').format(_now),
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.1,
                                                    shadows: const [
                                                      Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                 DateFormat('EEEE', LocaleService.currentLocaleCode).format(_now),
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.1,
                                                    shadows: const [
                                                      Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        ] else ...[
                                          // Custom Layout (Hi, Panda, App logo)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Transform.translate(
                                                offset: const Offset(-12, 0),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                  // White Glow / Shadow
                                                  ImageFiltered(
                                                    imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                                    child: ColorFiltered(
                                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcATop),
                                                      child: Image.asset(
                                                        _selectedLogoPath,
                                                        height: 120,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                  // Real Image
                                                  Image.asset(
                                                    _selectedLogoPath,
                                                    height: 120,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ],
                                              ),
                                              ),
                                              const SizedBox(height: 6),
                                                // Time, Vertical Line Divider, Date & Day Block
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      DateFormat('HH:mm').format(_now),
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white,
                                                        fontSize: 38,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: -1,
                                                        height: 1,
                                                        shadows: const [
                                                          Shadow(offset: Offset(1, 1), blurRadius: 5, color: Colors.black54),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      width: 1.5,
                                                      height: 30,
                                                      color: Colors.white.withOpacity(0.8),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          DateFormat('dd/MM/yyyy').format(_now),
                                                          style: GoogleFonts.outfit(
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            height: 1.1,
                                                            shadows: const [
                                                              Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          DateFormat('EEEE', LocaleService.currentLocaleCode).format(_now),
                                                          style: GoogleFonts.inter(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            height: 1.1,
                                                            shadows: const [
                                                              Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          )
                                        ],
                                        const SizedBox(height: 4),

                                        // Multi-line Geocoded Address
                                        Text(
                                          _isLoadingLocation
                                              ? 'Mendeteksi GPS akurat...'
                                              : (_currentLocation != null ? _currentLocation!.address : 'Jl. Kb. Kacang III No.10, RT.10, Kb. Kacang, Kecamatan Tanah Abang, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10240'),
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 12,
                                            height: 1.3,
                                            fontWeight: FontWeight.w400,
                                            shadows: const [
                                              Shadow(offset: Offset(1, 1), blurRadius: 5, color: Colors.black),
                                              Shadow(offset: Offset(-1, -1), blurRadius: 5, color: Colors.black),
                                            ],
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

            // Shutter Flash & Fly-to-Gallery Animation Overlays
            if (_showShutterFlash)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

            if (_flyingPhotoFile != null)
              Positioned.fill(
                child: KeyedSubtree(
                  key: ValueKey(_flyAnimKey),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    builder: (context, progress, child) {
                      final Alignment align = Alignment.lerp(
                        Alignment.center,
                        const Alignment(-0.72, 0.82),
                        progress,
                      )!;

                      final double size = ui.lerpDouble(240.0, 52.0, progress)!;
                      final double opacity = progress > 0.85 ? (1.0 - progress) / 0.15 : 1.0;

                      return Align(
                        alignment: align,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(ui.lerpDouble(16.0, 14.0, progress)!),
                              border: Border.all(color: AppTheme.haidilaoGold, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryRed.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                              image: DecorationImage(
                                image: FileImage(_flyingPhotoFile!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

                                                                // 5. Bottom Right Controls Overlay (Scrollable Continuous Zoom Wheel + Grey-White GPS Location Pin Button)
                                Positioned(
                                  right: 14,
                                  bottom: 16,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Scrollable Continuous Zoom Wheel (1.0x, 1.1x, 1.2x, ...)
                                      GestureDetector(
                                        onTap: () {}, // Absorb tap so focus ring does not trigger when scrolling zoom
                                        behavior: HitTestBehavior.opaque,
                                        child: _buildScrollableZoomSelector(),
                                      ),
                                      const SizedBox(height: 10),

                                      // GPS Location Pin Refresh Button (Subtle Grey-White Theme)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _fetchLocation,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.55),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.6), width: 1.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: _isLoadingLocation
                                              ? const Padding(
                                                  padding: EdgeInsets.all(10),
                                                  child: CircularProgressIndicator(color: Color(0xFFE0E0E0), strokeWidth: 2),
                                                )
                                              : const Icon(
                                                  Icons.my_location_rounded,
                                                  color: Color(0xFFE0E0E0),
                                                  size: 22,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ),
                  ),
                ),
              ),
            ),
          ),


            // 2. Bottom Space Area with Clean Dynamic Theme & Harmonious Controls
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 14, bottom: 20),
              decoration: BoxDecoration(
                color: surfaceColor,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrollable Mode Selector Tabs (TEMPLATE, KOLASE, EDIT, WATERMARK, STAMP)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildModeTab(
                          label: _isWatermarkVisible ? 'camera.mode_watermark_on'.trSafe() : 'camera.mode_watermark_off'.trSafe(),
                          icon: _isWatermarkVisible ? Icons.branding_watermark_rounded : Icons.branding_watermark_outlined,
                          isHighlighted: _isWatermarkVisible,
                          onTap: _toggleWatermark,
                        ),
                        _buildModeTab(
                          label: 'camera.mode_collage'.trSafe(),
                          icon: Icons.dashboard_customize_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CollageScreen(photos: [])),
                            ).then((_) => _loadLatestPhotoInfo());
                          },
                        ),
                        _buildModeTab(
                          label: 'camera.mode_template'.trSafe(),
                          icon: Icons.style_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ComparisonTemplateScreen(photos: [])),
                            ).then((_) => _loadLatestPhotoInfo());
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bottom Action Buttons (Gallery Thumbnail, Shutter Button, Manage Shortcut)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery Thumbnail & Count Badge
                        GestureDetector(
                          onTap: _openGallery,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.primaryRed.withOpacity(0.8), width: 2),
                                  image: _lastPhotoFile != null && !_lastPhotoFile!.path.toLowerCase().endsWith('.mp4')
                                      ? DecorationImage(
                                          image: FileImage(_lastPhotoFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _lastPhotoFile == null
                                    ? Icon(Icons.photo_library, color: AppTheme.getTextSecondary(context), size: 24)
                                    : (_lastPhotoFile!.path.toLowerCase().endsWith('.mp4')
                                        ? const Center(child: Icon(Icons.videocam_rounded, color: Colors.white, size: 26))
                                        : null),
                              ),
                              if (_photoCount > 0)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryRed,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$_photoCount',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Sleek Shutter Button (Handles Photo & Video Modes)
                        GestureDetector(
                          onTap: _isCapturing
                              ? null
                              : (_selectedMode == 'VIDEO' ? _toggleVideoRecording : _takePicture),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedMode == 'VIDEO'
                                    ? Colors.redAccent.withOpacity(0.3)
                                    : AppTheme.primaryRed.withOpacity(0.25),
                                width: 4,
                              ),
                              color: surfaceColor,
                              boxShadow: [
                                BoxShadow(
                                  color: (_selectedMode == 'VIDEO' ? Colors.redAccent : AppTheme.primaryRed).withOpacity(0.2),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedMode == 'VIDEO' ? Colors.redAccent : AppTheme.primaryRed,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: _selectedMode == 'VIDEO'
                                      ? AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: _isRecordingVideo ? 28 : 48,
                                          height: _isRecordingVideo ? 28 : 48,
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(_isRecordingVideo ? 6 : 24),
                                          ),
                                          child: Icon(
                                            _isRecordingVideo ? Icons.stop_rounded : Icons.videocam_rounded,
                                            color: Colors.white,
                                            size: _isRecordingVideo ? 20 : 26,
                                          ),
                                        )
                                      : AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          width: _isCapturing ? 32 : 48,
                                          height: _isCapturing ? 32 : 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _isCapturing ? AppTheme.haidilaoGold : AppTheme.primaryRed,
                                          ),
                                          child: _isCapturing
                                              ? const Padding(
                                                  padding: EdgeInsets.all(8),
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                                )
                                              : null,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Quick Video Mode Toggle Button (Disamping Tombol Kamera - Balanced 52x52 Box Container)
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'camera.video_under_development'.trSafe(),
                                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF1E1E1E),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _selectedMode == 'VIDEO' ? Colors.redAccent.withOpacity(0.15) : cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedMode == 'VIDEO' ? Colors.redAccent : AppTheme.primaryRed.withOpacity(0.8),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _selectedMode == 'VIDEO' ? Icons.camera_alt_rounded : Icons.videocam_rounded,
                                color: _selectedMode == 'VIDEO'
                                    ? Colors.redAccent
                                    : (isDark ? AppTheme.haidilaoGold : AppTheme.primaryRed),
                                size: 26,
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
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlighted = false,
    bool isSelected = false,
  }) {
    final Color unselectedBg = AppTheme.getCardColor(context);
    final Color unselectedText = AppTheme.getTextSecondary(context);
    final bool active = isSelected || isHighlighted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryRed : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : unselectedText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: active ? Colors.white : unselectedText,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableZoomSelector() {
    final String currentZoomFormatted = _currentZoom.toStringAsFixed(1);
    final int selectedIndex = _zoomLevels
        .indexWhere((val) => val.toStringAsFixed(1) == currentZoomFormatted)
        .clamp(0, _zoomLevels.length - 1);

    return Container(
      width: 48,
      height: 135,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: ListWheelScrollView.useDelegate(
        controller: _zoomScrollController,
        itemExtent: 26,
        perspective: 0.003,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          if (index >= 0 && index < _zoomLevels.length) {
            _setZoom(_zoomLevels[index]);
          }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: _zoomLevels.length,
          builder: (context, index) {
            final zoomVal = _zoomLevels[index];
            final isSelected = index == selectedIndex;
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: isSelected ? 13 : 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
                child: Text('${zoomVal.toStringAsFixed(1)}x'),
              ),
            );
          },
        ),
      ),
    );
  }
}
