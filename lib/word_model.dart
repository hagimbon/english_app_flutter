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
  final List<int>? imageBytes; // lưu Uint8List dưới dạng List<int>

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
}
