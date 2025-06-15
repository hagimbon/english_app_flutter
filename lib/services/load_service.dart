import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';

class LoadService {
  static Future<List<Map<String, dynamic>>> loadUnlearnedWords() async {
    final box = await Hive.openBox('unlearned_words');
    final rawList = box.values.toList();

    final words = rawList.where((e) => e is Map).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      map.remove('imageBytes'); // Nếu cần giữ ảnh thì xoá dòng này
      return map;
    }).toList();

    return words;
  }

  static Future<List<Map<String, dynamic>>> loadLearnedWords() async {
    final box = await Hive.openBox('learned_words');
    final rawList = box.values.toList();

    return rawList
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
