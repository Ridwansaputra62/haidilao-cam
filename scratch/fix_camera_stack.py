path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\camera_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add import 'dart:ui' as ui; if not present
if "import 'dart:ui' as ui;" not in text:
    text = text.replace("import 'dart:async';", "import 'dart:async';\nimport 'dart:ui' as ui;")

# 2. Extract overlays block from invalid Column location
overlay_block = """            // Shutter Flash & Fly-to-Gallery Animation Overlays
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

text = text.replace(overlay_block, "")

# 3. Insert overlay_block inside the viewfinder Stack right before Positioned(right: 14, bottom: 16, child: Column(...
stack_insert_point = "                                // 5. Bottom Right Controls Overlay"
if stack_insert_point in text:
    text = text.replace(stack_insert_point, overlay_block + "\n                                " + stack_insert_point)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Fixed camera_screen.dart stack structure!")
