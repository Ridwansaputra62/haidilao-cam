import 'dart:convert';
import 'package:haidilao_cam/core/models/photo_crop_data.dart';
import 'package:haidilao_cam/core/models/watermarked_photo.dart';

class ChecklistItem {
  final String id;
  String text;
  String workerName; // Nama yang mengerjakan item
  bool isChecked;

  ChecklistItem({
    required this.id,
    required this.text,
    this.workerName = '',
    this.isChecked = true,
  });

  ChecklistItem copyWith({
    String? id,
    String? text,
    String? workerName,
    bool? isChecked,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      workerName: workerName ?? this.workerName,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'workerName': workerName,
      'isChecked': isChecked,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text'] as String? ?? '',
      workerName: json['workerName'] as String? ?? '',
      isChecked: json['isChecked'] as bool? ?? true,
    );
  }

  static String encodeList(List<ChecklistItem> items) {
    return jsonEncode(items.map((i) => i.toJson()).toList());
  }

  static List<ChecklistItem> decodeList(String jsonStr) {
    if (jsonStr.trim().isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

class BlueCardSlot {
  final String label; // e.g. 'BEFORE', 'PROSES', 'AFTER'
  final WatermarkedPhoto? photo;
  final PhotoCropData? cropData;

  BlueCardSlot({
    required this.label,
    this.photo,
    this.cropData,
  });

  BlueCardSlot copyWith({
    String? label,
    WatermarkedPhoto? photo,
    PhotoCropData? cropData,
    bool clearPhoto = false,
  }) {
    return BlueCardSlot(
      label: label ?? this.label,
      photo: clearPhoto ? null : (photo ?? this.photo),
      cropData: clearPhoto ? null : (cropData ?? this.cropData),
    );
  }
}

class BlueCardData {
  String title;
  String storeName;
  String picName;
  String dateText;
  String noteText;
  bool isThreeBox; // false = 2-box (Before/After), true = 3-box (Before/Proses/After)
  List<BlueCardSlot> slots;

  BlueCardData({
    this.title = 'LAPORAN GENERAL CLEANING',
    this.storeName = 'Haidilao Night Shift',
    this.picName = '',
    this.dateText = '',
    this.noteText = '',
    this.isThreeBox = false,
    required this.slots,
  });
}

class ShiftChecklistData {
  String headerTitle; // Default: 'Closingan Night Shift'
  String picName; // Sub header: Nama Penanggung Jawab
  String noteText; // Catatan (replaces deskripsi)
  String dateText;
  List<ChecklistItem> items;
  List<WatermarkedPhoto> photos;
  Map<String, PhotoCropData> photoCrops;

  ShiftChecklistData({
    this.headerTitle = 'Closingan Night Shift',
    this.picName = '',
    this.noteText = '',
    this.dateText = '',
    required this.items,
    required this.photos,
    Map<String, PhotoCropData>? photoCrops,
  }) : photoCrops = photoCrops ?? {};
}
