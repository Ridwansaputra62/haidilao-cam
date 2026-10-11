import re

path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\camera_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add _toggleWatermark method if not present
if "_toggleWatermark()" not in content:
    toggle_wm_code = """
  void _toggleWatermark() {
    setState(() {
      _isWatermarkVisible = !_isWatermarkVisible;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _isWatermarkVisible ? Icons.branding_watermark_rounded : Icons.watermark_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(_isWatermarkVisible ? 'Watermark Diaktifkan 🏷️' : 'Watermark Dimatikan 🚫'),
            ],
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
"""
    # Insert before _toggleTorch
    content = content.replace("Future<void> _toggleTorch() async {", toggle_wm_code + "\n  Future<void> _toggleTorch() async {")

# 2. Update Positioned live watermark overlay to check _isWatermarkVisible and use _toggleWatermark on tap
old_wm_pattern = r"// 4\. TimeMark Style Live Watermark Overlay \(Bottom Left Area\)\s*Positioned\("
new_wm_replacement = """// 4. TimeMark Style Live Watermark Overlay (Bottom Left Area)
                                if (_isWatermarkVisible)
                                  Positioned("""
content = re.sub(old_wm_pattern, new_wm_replacement, content)

# Update onTap in watermark gesture detector
content = content.replace(
    "onTap: () {}, // Absorb tap so focus ring does not trigger on watermark",
    "onTap: _toggleWatermark, // Tap watermark overlay to toggle visibility"
)

# 3. Update Mode Tabs Row
old_row = """                        _buildModeTab('WATERMARK', Icons.branding_watermark_rounded),
                        _buildModeTab('VIDEO', Icons.videocam_rounded),
                        _buildModeTab('KOLASE', Icons.dashboard_customize_rounded),
                        _buildModeTab('EDIT', Icons.auto_fix_high_rounded),
                        _buildModeTab('STAMP', Icons.verified_rounded),"""

new_row = """                        _buildModeTab(
                          label: _isWatermarkVisible ? 'WATERMARK' : 'WATERMARK (OFF)',
                          icon: _isWatermarkVisible ? Icons.branding_watermark_rounded : Icons.watermark_outlined,
                          isHighlighted: _isWatermarkVisible,
                          onTap: _toggleWatermark,
                        ),
                        if (_selectedMode == 'VIDEO')
                          _buildModeTab(
                            label: 'FOTO',
                            icon: Icons.camera_alt_rounded,
                            isSelected: false,
                            onTap: () {
                              setState(() {
                                _selectedMode = 'FOTO';
                              });
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Beralih ke Mode Foto 📸'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          )
                        else
                          _buildModeTab(
                            label: 'VIDEO',
                            icon: Icons.videocam_rounded,
                            isSelected: false,
                            onTap: () {
                              setState(() {
                                _selectedMode = 'VIDEO';
                              });
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Beralih ke Mode Video 🎥'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        _buildModeTab(
                          label: 'KOLASE',
                          icon: Icons.dashboard_customize_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CollageScreen(photos: [])),
                            ).then((_) => _loadLatestPhotoInfo());
                          },
                        ),
                        _buildModeTab(
                          label: 'TEMPLATE',
                          icon: Icons.style_rounded,
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.construction_rounded, color: AppTheme.haidilaoGold, size: 20),
                                    SizedBox(width: 10),
                                    Text('Fitur Template Masih Dalam Pengembangan 🚧'),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        ),"""

content = content.replace(old_row, new_row)

# 4. Update _buildModeTab implementation signature
old_build_tab = """  Widget _buildModeTab(String modeName, IconData icon) {
    final bool isSelected = _selectedMode == modeName;
    final Color unselectedBg = AppTheme.getCardColor(context);
    final Color unselectedText = AppTheme.getTextSecondary(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = modeName;
        });
        if (modeName != 'WATERMARK') {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mode $modeName terpilih'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRed : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryRed : AppTheme.getBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : unselectedText,
            ),
            const SizedBox(width: 6),
            Text(
              modeName,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : unselectedText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }"""

new_build_tab = """  Widget _buildModeTab({
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
  }"""

content = content.replace(old_build_tab, new_build_tab)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated camera_screen.dart successfully")
