import re

path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\camera_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update state variables in _CameraScreenState
state_vars_code = """  // Fly-to-Gallery capture animation state
  File? _flyingPhotoFile;
  bool _showShutterFlash = false;
  int _flyAnimKey = 0;
"""

if "_flyingPhotoFile" not in content:
    content = content.replace("bool _isCapturing = false;", "bool _isCapturing = false;\n" + state_vars_code)

# 2. Add _triggerCaptureAnimation & update _loadLatestPhotoInfo
load_photo_old = """  Future<void> _loadLatestPhotoInfo() async {
    final photos = await PhotoStorageService.loadPhotos();
    if (mounted) {
      setState(() {
        _photoCount = photos.length;
        if (photos.isNotEmpty) {
          _lastPhotoFile = File(photos.first.path);
        } else {
          _lastPhotoFile = null;
        }
      });
    }
  }"""

load_photo_new = """  Future<void> _loadLatestPhotoInfo() async {
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
          _lastPhotoFile = File(photos.first.path);
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
  }"""

content = content.replace(load_photo_old, load_photo_new)

# 3. Update _stopVideoRecording to remove SnackBar and trigger fly animation
stop_video_old = """      if (file.existsSync()) {
        _loadLatestPhotoInfo();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surfaceDark,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Video Watermark Tersimpan ke Galeri HP! 🎥',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    _openGallery();
                  },
                  child: const Text('GALERI', style: TextStyle(color: AppTheme.haidilaoGold)),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }"""

stop_video_new = """      if (file.existsSync() && mounted) {
        _triggerCaptureAnimation(file);
      }"""

content = content.replace(stop_video_old, stop_video_new)

# 4. Update _takePicture to remove SnackBar and trigger fly animation
take_pic_old = """      final XFile rawPhoto = await _controller!.takePicture();
      // Instantly release shutter button state (< 100ms UI response)
      if (mounted) {
        setState(() => _isCapturing = false);
      }"""

take_pic_new = """      final XFile rawPhoto = await _controller!.takePicture();
      final File rawFile = File(rawPhoto.path);

      // Instantly release shutter button state & trigger fly animation into gallery icon
      if (mounted) {
        setState(() => _isCapturing = false);
        _triggerCaptureAnimation(rawFile);
      }"""

content = content.replace(take_pic_old, take_pic_new)

# Remove SnackBar block inside background task in _takePicture
snack_bg_pattern = r"if \(savedPhoto != null && mounted\) \{\s*_loadLatestPhotoInfo\(\);\s*ScaffoldMessenger\.of\(context\)\.hideCurrentSnackBar\(\);\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\([\s\S]*?\);\s*\}"
snack_bg_replacement = """if (savedPhoto != null && mounted) {
            _loadLatestPhotoInfo();
          }"""

content = re.sub(snack_bg_pattern, snack_bg_replacement, content)

# 5. Add Shutter Flash & Fly Animation overlay into Scaffold body Stack
stack_end_target = "            // 2. Bottom Space Area with Clean Dynamic Theme & Harmonious Controls"

overlay_widgets = """            // Shutter Flash & Fly-to-Gallery Animation Overlays
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

"""

content = content.replace(stack_end_target, overlay_widgets + stack_end_target)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated camera_screen.dart with fly animation & today count successfully!")
