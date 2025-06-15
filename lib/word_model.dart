// word_model.dart
import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'word_model.g.dart'; // 🛠 Tự động sinh mã adapter từ lệnh build_runner

@HiveType(typeId: 0)
class WordModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String word;

  @HiveField(2)
  final String meaning;

  @HiveField(3)
  final String phonetic;

  @HiveField(4)
  final String usage;

  @HiveField(5)
  final List<Map<String, String>> examples;

  @HiveField(6)
  final List<int>? imageBytes;

  @HiveField(7)
  final bool isLearned;

  WordModel({
    required this.id,
    required this.word,
    required this.meaning,
    required this.phonetic,
    required this.usage,
    required this.examples,
    required this.imageBytes,
    required this.isLearned,
  });

  // ✅ Dùng khi lấy dữ liệu từ Firestore để đưa vào Hive
  factory WordModel.fromMap(Map<String, dynamic> map) {
    return WordModel(
      id: map['id'],
      word: map['word'] ?? '',
      meaning: map['meaning'] ?? '',
      phonetic: map['phonetic'] ?? '',
      usage: map['usage'] ?? '',
      examples:
          (map['examples'] as List?)?.map<Map<String, String>>((e) {
            return {
              'en': e['en']?.toString() ?? '',
              'vi': e['vi']?.toString() ?? '',
            };
          }).toList() ??
          [],
      imageBytes: map['imageBytes']?.cast<int>(),
      isLearned: map['isLearned'] ?? false,
    );
  }

  // ✅ Dùng khi lấy dữ liệu từ Hive để hiển thị lên giao diện
  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'phonetic': phonetic,
      'usage': usage,
      'examples': examples,
      'imageBytes': imageBytes,
      'isLearned': isLearned,
    };
  }
}
