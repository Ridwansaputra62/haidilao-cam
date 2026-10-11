import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' as easy;

/// Central service for locale-aware date/number formatting.
/// Call [LocaleService.currentLocaleCode] anywhere (without BuildContext)
/// using the globally-tracked locale, or use the BuildContext-aware helpers.
class LocaleService {
  LocaleService._();

  /// Reactive notifier so non-widget code can read the current locale string
  /// (e.g. 'id_ID', 'en_US', 'zh_CN').
  static final ValueNotifier<String> localeNotifier =
      ValueNotifier<String>('id_ID');

  /// Map from EasyLocalization Locale languageCode → intl locale code.
  static const Map<String, String> _intlLocaleMap = {
    'id': 'id_ID',
    'en': 'en_US',
    'zh': 'zh_CN',
  };

  /// Map from EasyLocalization Locale languageCode → display name.
  static const Map<String, String> displayNames = {
    'id': 'Bahasa Indonesia',
    'en': 'English',
    'zh': '简体中文',
  };

  /// Update the tracked locale from [context.locale] – call this in
  /// each screen's build() when a BuildContext is available.
  static void update(Locale locale) {
    final code = _intlLocaleMap[locale.languageCode] ?? 'id_ID';
    if (localeNotifier.value != code) {
      localeNotifier.value = code;
    }
  }

  /// Returns the intl locale code (e.g. 'id_ID') for the current locale.
  static String get currentLocaleCode => localeNotifier.value;

  /// Returns only the languageCode part ('id', 'en', 'zh').
  static String get languageCode => localeNotifier.value.split('_').first;

  // ─── Convenience formatters ────────────────────────────────────────────────

  /// Full day name in the current locale, e.g. 'Senin', 'Monday', '星期一'.
  static String dayName(DateTime dt) =>
      DateFormat('EEEE', currentLocaleCode).format(dt);

  /// Short day name, e.g. 'Sen', 'Mon'.
  static String dayNameShort(DateTime dt) =>
      DateFormat('EEE', currentLocaleCode).format(dt);

  /// Full date, e.g. 'Senin, 11 Oktober 2026'.
  static String fullDate(DateTime dt) =>
      DateFormat('EEEE, dd MMMM yyyy', currentLocaleCode).format(dt);

  /// Medium date, e.g. '11 Oktober 2026'.
  static String mediumDate(DateTime dt) =>
      DateFormat('dd MMMM yyyy', currentLocaleCode).format(dt);

  /// Short date, e.g. '11/10/2026'.
  static String shortDate(DateTime dt) =>
      DateFormat('dd/MM/yyyy').format(dt);

  /// Time, e.g. '07:14'.
  static String time(DateTime dt) =>
      DateFormat('HH:mm').format(dt);

  /// Date + time for gallery, e.g. '11/10 07:14'.
  static String galleryDateTime(DateTime dt) =>
      DateFormat('dd/MM HH:mm').format(dt);

  /// Timestamp for file names, e.g. '20261011_0714'.
  static String fileTimestamp(DateTime dt) =>
      DateFormat('yyyyMMdd_HHmm').format(dt);

  /// Full timestamp for file names, e.g. '20261011_071439'.
  static String fileTimestampFull(DateTime dt) =>
      DateFormat('yyyyMMdd_HHmmss').format(dt);

  /// Formatted total photos label depending on current language
  static String totalPhotos(int count) {
    switch (languageCode) {
      case 'zh':
        return '共 $count 张照片';
      case 'en':
        return count == 1 ? 'Total: 1 Photo' : 'Total: $count Photos';
      case 'id':
      default:
        return 'Total: $count Foto';
    }
  }

  // ─── Fallback in-memory translations ───────────────────────────────────────
  static final Map<String, Map<String, String>> _fallbackTranslations = {
    'id': {
      'camera.watermark_settings': 'Pengaturan Watermark',
      'camera.show_watermark': 'Tampilkan Watermark',
      'camera.watermark_on': 'Watermark Diaktifkan 🏷️',
      'camera.watermark_off': 'Watermark Dimatikan 🚫',
      'camera.switch_video': 'Beralih ke Mode Video 🎥',
      'camera.switch_photo': 'Beralih ke Mode Foto 📸',
      'camera.recording_started': 'Perekaman Video Dimulai 🎥',
      'camera.recording_saved': 'Video berhasil disimpan ke Galeri 🎥',
      'camera.recording_failed': 'Gagal merekam video',
      'camera.capture_failed': 'Gagal mengambil foto',
      'camera.logo_standard': 'Logo Standar',
      'camera.logo_hi': 'Logo Hi',
      'camera.logo_panda': 'Panda 1',
      'camera.logo_panda2': 'Panda 2',
      'camera.detecting_gps': 'Mendeteksi GPS akurat...',
      'camera.mode_watermark_on': 'WATERMARK',
      'camera.mode_watermark_off': 'WATERMARK (OFF)',
      'camera.mode_collage': 'KOLASE',
      'camera.mode_template': 'TEMPLATE',
      'camera.btn_switch_camera': 'Ganti Kamera',
      'collage.panda_1': 'Panda 1',
      'collage.panda_2': 'Panda 2',
      'collage.col_1_short': '1 Kolom',
      'collage.col_2_short': '2 Kolom',
      'collage.col_3_short': '3 Kolom',
      'collage.col_4_short': '4 Kolom',
      'collage.col_1_title': '1 Kolom Memanjang',
      'collage.col_2_title': '2 Kolom Memanjang',
      'collage.col_3_title': '3 Kolom Memanjang',
      'collage.col_4_title': '4 Kolom Memanjang',
      'collage.col_1_desc': 'Menyusun foto 1 per 1 secara vertikal memanjang kebawah.',
      'collage.col_2_desc': 'Menyusun foto 2 kolom simetris memanjang kebawah.',
      'collage.col_3_desc': 'Menyusun foto 3 kolom padat memanjang kebawah.',
      'collage.col_4_desc': 'Menyusun foto 4 kolom ekstra padat memanjang kebawah.',
      'collage.total_photos': 'Total: {count} Foto',
      'collage.show_title': 'Judul',
      'collage.show_subtitle': 'Sub Judul',
      'collage.show_description': 'Deskripsi',
      'collage.logo_label': 'Gaya Logo:',
      'template.title': 'Template Kolase Foto',
      'template.settings': 'Pengaturan Template',
      'template.type_label': 'Tipe Template:',
      'template.type_ba': 'Before After',
      'template.type_rw': 'Salah - Benar',
      'template.logo_label': 'Gaya Logo:',
      'template.size_label': 'Ukuran Foto:',
      'template.show_title': 'Judul',
      'template.show_subtitle': 'Sub Judul',
      'template.show_description': 'Deskripsi',
      'template.label_before': 'SEBELUM',
      'template.label_process': 'PROSES',
      'template.label_after': 'SESUDAH',
      'template.label_wrong': 'SALAH',
      'template.label_correct': 'BENAR',
      'template.add_note': 'Tambah Catatan Baris {n}',
      'template.note_title': 'Catatan Baris {n}',
      'template.note_desc': 'Tambahkan catatan untuk foto pada baris ke-{n} (dapat dikosongkan jika tidak diperlukan):',
      'template.delete_note': 'Hapus Catatan',
      'template.save_note': 'Simpan',
      'template.save_crop': 'SIMPAN CROP',
      'template.crop_cancel': 'BATAL',
      'template.export_failed': 'Gagal membuat template foto. Silakan coba lagi.',
      'template.visibility_title': 'Pengaturan Visibilitas Teks',
      'common.total': 'Total',
      'common.save': 'Simpan',
      'common.cancel': 'Batal',
      'common.close': 'Tutup',
      'common.camera': 'Kamera',
      'common.gallery': 'Galeri',
      'common.add_photo': 'Tambah Foto',
      'common.source_photo': 'Pilih Sumber Foto',
      'common.loading_image': 'Gambar sedang dimuat, silakan coba sebentar lagi.',
    },
    'en': {
      'camera.watermark_settings': 'Watermark Settings',
      'camera.show_watermark': 'Show Watermark',
      'camera.watermark_on': 'Watermark Enabled 🏷️',
      'camera.watermark_off': 'Watermark Disabled 🚫',
      'camera.switch_video': 'Switch to Video Mode 🎥',
      'camera.switch_photo': 'Switch to Photo Mode 📸',
      'camera.recording_started': 'Video Recording Started 🎥',
      'camera.recording_saved': 'Video successfully saved to Gallery 🎥',
      'camera.recording_failed': 'Failed to record video',
      'camera.capture_failed': 'Failed to take photo',
      'camera.logo_standard': 'Standard Logo',
      'camera.logo_hi': 'Hi Logo',
      'camera.logo_panda': 'Panda 1',
      'camera.logo_panda2': 'Panda 2',
      'camera.detecting_gps': 'Detecting accurate GPS...',
      'camera.mode_watermark_on': 'WATERMARK',
      'camera.mode_watermark_off': 'WATERMARK (OFF)',
      'camera.mode_collage': 'COLLAGE',
      'camera.mode_template': 'TEMPLATE',
      'camera.btn_switch_camera': 'Switch Camera',
      'collage.panda_1': 'Panda 1',
      'collage.panda_2': 'Panda 2',
      'collage.col_1_short': '1 Column',
      'collage.col_2_short': '2 Columns',
      'collage.col_3_short': '3 Columns',
      'collage.col_4_short': '4 Columns',
      'collage.col_1_title': '1 Column Vertical',
      'collage.col_2_title': '2 Columns Vertical',
      'collage.col_3_title': '3 Columns Vertical',
      'collage.col_4_title': '4 Columns Vertical',
      'collage.col_1_desc': 'Arranges photos 1 by 1 vertically downwards.',
      'collage.col_2_desc': 'Arranges photos in 2 symmetrical columns vertically downwards.',
      'collage.col_3_desc': 'Arranges photos in 3 compact columns vertically downwards.',
      'collage.col_4_desc': 'Arranges photos in 4 extra compact columns vertically downwards.',
      'collage.total_photos': 'Total: {count} Photos',
      'collage.show_title': 'Title',
      'collage.show_subtitle': 'Subtitle',
      'collage.show_description': 'Description',
      'collage.logo_label': 'Logo Style:',
      'template.title': 'Photo Template',
      'template.settings': 'Template Settings',
      'template.type_label': 'Template Type:',
      'template.type_ba': 'Before After',
      'template.type_rw': 'Wrong - Right',
      'template.logo_label': 'Logo Style:',
      'template.size_label': 'Photo Size:',
      'template.show_title': 'Title',
      'template.show_subtitle': 'Subtitle',
      'template.show_description': 'Description',
      'template.label_before': 'BEFORE',
      'template.label_process': 'PROCESS',
      'template.label_after': 'AFTER',
      'template.label_wrong': 'WRONG',
      'template.label_correct': 'CORRECT',
      'template.add_note': 'Add Note Row {n}',
      'template.note_title': 'Row {n} Note',
      'template.note_desc': 'Add a note for photos in row {n} (can be left empty):',
      'template.delete_note': 'Remove Note',
      'template.save_note': 'Save',
      'template.save_crop': 'SAVE CROP',
      'template.crop_cancel': 'CANCEL',
      'template.export_failed': 'Failed to create template photo. Please try again.',
      'template.visibility_title': 'Text Visibility Settings',
      'common.total': 'Total',
      'common.save': 'Save',
      'common.cancel': 'Cancel',
      'common.close': 'Close',
      'common.camera': 'Camera',
      'common.gallery': 'Gallery',
      'common.add_photo': 'Add Photo',
      'common.source_photo': 'Select Photo Source',
      'common.loading_image': 'Image is loading, please wait a moment.',
    },
    'zh': {
      'camera.watermark_settings': '水印设置',
      'camera.show_watermark': '显示水印',
      'camera.watermark_on': '水印已开启 🏷️',
      'camera.watermark_off': '水印已关闭 🚫',
      'camera.switch_video': '切换到录像模式 🎥',
      'camera.switch_photo': '切换到拍照模式 📸',
      'camera.recording_started': '开始录制视频 🎥',
      'camera.recording_saved': '视频已成功保存到相册 🎥',
      'camera.recording_failed': '录制视频失败',
      'camera.capture_failed': '拍照失败',
      'camera.logo_standard': '标准徽标',
      'camera.logo_hi': 'Hi 徽标',
      'camera.logo_panda': '熊猫 1',
      'camera.logo_panda2': '熊猫 2',
      'camera.detecting_gps': '正在获取精确的GPS定位...',
      'camera.mode_watermark_on': '水印',
      'camera.mode_watermark_off': '水印 (关)',
      'camera.mode_collage': '拼图',
      'camera.mode_template': '模板',
      'camera.btn_switch_camera': '切换摄像头',
      'collage.panda_1': '熊猫 1',
      'collage.panda_2': '熊猫 2',
      'collage.col_1_short': '1 列',
      'collage.col_2_short': '2 列',
      'collage.col_3_short': '3 列',
      'collage.col_4_short': '4 列',
      'collage.col_1_title': '单列纵向',
      'collage.col_2_title': '双列纵向',
      'collage.col_3_title': '三列纵向',
      'collage.col_4_title': '四列纵向',
      'collage.col_1_desc': '逐张向下纵向排列照片。',
      'collage.col_2_desc': '以双列对称形式向下纵向排列照片。',
      'collage.col_3_desc': '以三列紧凑形式向下纵向排列照片。',
      'collage.col_4_desc': '以四列超紧凑形式向下纵向排列照片。',
      'collage.total_photos': '总计: {count} 张照片',
      'collage.show_title': '标题',
      'collage.show_subtitle': '副标题',
      'collage.show_description': '描述',
      'collage.logo_label': '徽标样式：',
      'template.title': '照片模板',
      'template.settings': '模板设置',
      'template.type_label': '模板类型：',
      'template.type_ba': '前后对比',
      'template.type_rw': '错误 - 正确',
      'template.logo_label': '徽标样式：',
      'template.size_label': '照片尺寸：',
      'template.show_title': '标题',
      'template.show_subtitle': '副标题',
      'template.show_description': '描述',
      'template.label_before': '之前',
      'template.label_process': '过程',
      'template.label_after': '之后',
      'template.label_wrong': '错误',
      'template.label_correct': '正确',
      'template.add_note': '添加第 {n} 行备注',
      'template.note_title': '第 {n} 行备注',
      'template.note_desc': '为第 {n} 行照片添加备注（可留空）：',
      'template.delete_note': '删除备注',
      'template.save_note': '保存',
      'template.save_crop': '保存裁剪',
      'template.crop_cancel': '取消',
      'template.export_failed': '创建模板照片失败，请重试。',
      'template.visibility_title': '文字可见性设置',
      'common.total': '总计',
      'common.save': '保存',
      'common.cancel': '取消',
      'common.close': '关闭',
      'common.camera': '相机',
      'common.gallery': '相册',
      'common.add_photo': '添加照片',
      'common.source_photo': '选择照片来源',
      'common.loading_image': '图片正在加载中，请稍候。',
    },
  };

  /// Translate key with bulletproof fallback so code keys never leak into the UI
  static String tr(String key, {Map<String, String>? namedArgs, String? fallback}) {
    final lang = languageCode;
    String? text = _fallbackTranslations[lang]?[key] ??
        _fallbackTranslations['id']?[key] ??
        fallback;
    
    if (text != null) {
      if (namedArgs != null) {
        namedArgs.forEach((k, v) {
          text = text!.replaceAll('{$k}', v);
        });
      }
      return text!;
    }
    return key;
  }
}

extension SafeTranslation on String {
  /// Always safe translation: if easy_localization has the translation, use it.
  /// If it returns raw key or has not yet reloaded the asset bundle,
  /// fallback to in-memory dictionary so raw code keys like 'collage.panda_1' never appear.
  String trSafe({Map<String, String>? namedArgs, String? fallback}) {
    try {
      final easyVal = easy.tr(this, namedArgs: namedArgs);
      if (easyVal != this && !easyVal.contains(this)) {
        return easyVal;
      }
    } catch (_) {}
    return LocaleService.tr(this, namedArgs: namedArgs, fallback: fallback);
  }
}
