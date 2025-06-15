import 'package:hive/hive.dart';

part 'word_model.g.dart';

@HiveType(typeId: 0)
class WordModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String word;

  @HiveField(2)
  String meaning;

  @HiveField(3)
  String? phonetic;

  @HiveField(4)
  String? usage;

  @HiveField(5)
  List<Map<String, String>> examples;

  @HiveField(6)
  List<int>? imageBytes; // lưu Uint8List

  @HiveField(7)
  bool isLearned;

  WordModel({
    required this.id,
    required this.word,
    required this.meaning,
    this.phonetic,
    this.usage,
    this.examples = const [],
    this.imageBytes,
    this.isLearned = false,
  });
}
