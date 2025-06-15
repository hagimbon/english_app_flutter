// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordModelAdapter extends TypeAdapter<WordModel> {
  @override
  final int typeId = 0;

  @override
  WordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordModel(
      id: fields[0] as String,
      word: fields[1] as String,
      meaning: fields[2] as String,
      phonetic: fields[3] as String,
      usage: fields[4] as String,
      examples: (fields[5] as List)
          .map((dynamic e) => (e as Map).cast<String, String>())
          .toList(),
      imageBytes: (fields[6] as List?)?.cast<int>(),
      isLearned: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WordModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.word)
      ..writeByte(2)
      ..write(obj.meaning)
      ..writeByte(3)
      ..write(obj.phonetic)
      ..writeByte(4)
      ..write(obj.usage)
      ..writeByte(5)
      ..write(obj.examples)
      ..writeByte(6)
      ..write(obj.imageBytes)
      ..writeByte(7)
      ..write(obj.isLearned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
