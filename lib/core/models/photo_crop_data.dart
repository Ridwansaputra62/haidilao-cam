import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';

enum PhotoSizeMode {
  fullSize, // Ukuran Asli (Original aspect ratio)
  square,   // Ukuran Kotak (1:1 Square aspect ratio)
}

extension PhotoSizeModeExtension on PhotoSizeMode {
  String get label {
    switch (this) {
      case PhotoSizeMode.fullSize:
        return 'collage.full_size'.tr();
      case PhotoSizeMode.square:
        return 'collage.square'.tr();
    }
  }

  String get shortLabel {
    switch (this) {
      case PhotoSizeMode.fullSize:
        return 'collage.full_size'.tr();
      case PhotoSizeMode.square:
        return 'collage.square'.tr();
    }
  }
}

class PhotoCropData {
  final double left;   // 0.0 to 1.0 normalized
  final double top;    // 0.0 to 1.0 normalized
  final double right;  // 0.0 to 1.0 normalized
  final double bottom; // 0.0 to 1.0 normalized

  const PhotoCropData({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 1.0,
    this.bottom = 1.0,
  });

  bool get isDefault => left <= 0.0 && top <= 0.0 && right >= 1.0 && bottom >= 1.0;

  Rect toRect(double width, double height) {
    final double l = (left * width).clamp(0.0, width);
    final double t = (top * height).clamp(0.0, height);
    final double r = (right * width).clamp(l + 1.0, width);
    final double b = (bottom * height).clamp(t + 1.0, height);
    return Rect.fromLTRB(l, t, r, b);
  }
}
