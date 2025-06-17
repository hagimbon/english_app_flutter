// File: hive_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:english_app/word_model.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

class HiveService {
  static final _box = Hive.box<WordModel>('wordsBox');

  static Future<void> saveOrUpdateWord(WordModel word) async {
    final existing = _box.get(word.id);
    if (existing == null || !_isSameWord(existing, word)) {
      await _box.put(word.id, word);
    }
  }

  static Future<void> deleteWord(String id) async {
    await _box.delete(id);
  }

  static List<WordModel> getWords({bool isLearned = false}) {
    return _box.values.where((w) => w.isLearned == isLearned).toList();
  }

  static Future<void> syncWithFirebase(
    List<Map<String, dynamic>> unlearned,
    List<Map<String, dynamic>> learned,
  ) async {
    final current = {for (var w in _box.values) w.id: w};
    final all = [...unlearned, ...learned];

    for (final word in all) {
      final id = word['id'];
      final model = WordModel.fromMap(word);
      final old = current[id];
      if (old == null || !_isSameWord(old, model)) {
        await _box.put(id, model);
      }
      current.remove(id);
    }

    for (final id in current.keys) {
      await _box.delete(id);
    }
  }

  static bool _isSameWord(WordModel a, WordModel b) {
    return a.word == b.word &&
        a.meaning == b.meaning &&
        a.phonetic == b.phonetic &&
        a.usage == b.usage &&
        a.isLearned == b.isLearned &&
        const DeepCollectionEquality().equals(a.examples, b.examples) &&
        listEquals(a.imageBytes, b.imageBytes);
  }
}
