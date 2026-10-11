path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\gallery_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

badge_code = """                                 // Gambar Panjang Badge Indicator
                                 if (isLongImage)
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
                                             'Panjang',
                                             style: GoogleFonts.outfit(
                                               color: Colors.white,
                                               fontSize: 9,
                                               fontWeight: FontWeight.bold,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),"""

if "Gambar Panjang Badge Indicator" not in content:
    target = "                                 // Checkbox Indicator"
    content = content.replace(target, badge_code + "\n\n" + target)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated gallery_screen.dart with badge successfully")
