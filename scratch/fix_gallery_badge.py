path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\gallery_screen.dart"

with open(path, "rb") as f:
    raw = f.read()

text = raw.decode("utf-8")

badge_code = """
                                 // Gambar Panjang Badge Indicator
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

target = "                                 // Checkbox Indicator"
if target in text:
    text = text.replace(target, badge_code + "\n" + target)

with open(path, "wb") as f:
    f.write(text.encode("utf-8"))

print("Fixed gallery badge successfully")
