import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'word_model.dart'; // 👈 thêm dòng này để biết WordModel là gì

class LoadService {
  static final Future<Box> _unlearnedBox = Hive.openBox('unlearned_words');
  static final Future<Box> _learnedBox = Hive.openBox('learned_words');

  /// Tải từ Firebase
  static Future<List<Map<String, dynamic>>> fetchWords({
    bool isLearned = false,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('words')
        .where('isLearned', isEqualTo: isLearned)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data()!,
          toFirestore: (data, _) => data,
        )
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final rawExamples = data['examples'];

      final examples = (rawExamples is List)
          ? rawExamples
                .whereType<Map>()
                .map(
                  (e) => {
                    'en': e['en']?.toString() ?? '',
                    'vi': e['vi']?.toString() ?? '',
                  },
                )
                .toList()
          : [];

      return {
        'id': doc.id,
        'word': data['word'] ?? '',
        'meaning': data['meaning'] ?? '',
        'phonetic': data['phonetic'] ?? '',
        'usage': data['usage'] ?? '',
        'examples': examples,
        'imageBytes': data['imageBytes'],
        'isLearned': data['isLearned'] ?? false,
      };
    }).toList();
  }

  /// Tải từ chưa học từ Hive
  static Future<List<Map<String, dynamic>>> loadUnlearnedWords() async {
    final box = await _unlearnedBox;
    final rawList = box.values.toList();

    return rawList.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);
      map.remove('imageBytes'); // ❗ Nếu muốn giữ ảnh thì bỏ dòng này
      return map;
    }).toList();
  }

  /// Tải từ đã học từ Hive
  static Future<List<Map<String, dynamic>>> loadLearnedWords() async {
    final box = await _learnedBox;
    final raw = box.values.toList();

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// ✅ Preload các box khi mở app
  static Future<void> preloadBoxes() async {
    await Hive.openBox('unlearned_words');
    await Hive.openBox('learned_words');
    await Hive.openBox<WordModel>('wordsBox');
  }
}
