path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\gallery_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add share_plus import
if "import 'package:share_plus/share_plus.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:share_plus/share_plus.dart';")

# 2. Add helper method _shareSelectedPhotos & _build3DRedButtonStyle
helpers_code = """  void _shareSelectedPhotos() async {
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
"""

if "_shareSelectedPhotos()" not in content:
    content = content.replace("void _showDeletePreviewDialog() {", helpers_code + "\n  void _showDeletePreviewDialog() {")

# 3. Update bottomNavigationBar Row with 3 harmonious 3D red buttons
old_bottom_bar = """                child: Row(
                  children: [
                    // Button 1: Buat Kolase Foto
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.haidilaoGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.black, size: 20),
                        label: Text(
                          widget.isPickerMode ? 'SIMPAN PILIHAN ($selectedCount)' : 'KOLASE ($selectedCount)',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
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
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Button 2: Preview & Hapus
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                        label: Text(
                          'HAPUS ($selectedCount)',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: _showDeletePreviewDialog,
                      ),
                    ),
                  ],
                ),"""

new_bottom_bar = """                child: Row(
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
                                  widget.isPickerMode ? 'SIMPAN ($selectedCount)' : 'KOLASE ($selectedCount)',
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
                                  'BAGIKAN ($selectedCount)',
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
                                  'HAPUS ($selectedCount)',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),"""

content = content.replace(old_bottom_bar, new_bottom_bar)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated gallery_screen.dart with Bagikan button & 3D red theme successfully!")
