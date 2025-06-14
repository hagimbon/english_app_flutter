import 'package:flutter/material.dart';
import 'dart:typed_data'; // ✅ để dùng Uint8List
import 'package:image/image.dart' as img; // ✅ để resize ảnh
import 'package:image_picker/image_picker.dart'; // ✅ để chọn ảnh từ thư viện
import 'package:cloud_firestore/cloud_firestore.dart';

class AddWordScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingWords;
  final Map<String, dynamic>? initialData;

  final String? wordId; // ✅ THÊM DÒNG NÀY

  const AddWordScreen({
    super.key,
    required this.existingWords,
    this.initialData,
    this.wordId, // ✅ THÊM DÒNG NÀY
  });

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _englishController = TextEditingController();
  final _meaningController = TextEditingController();
  final _phoneticController = TextEditingController();
  final _usageController = TextEditingController();

  List<TextEditingController> exampleEnControllers = [];
  List<TextEditingController> exampleViControllers = [];

  Uint8List? _previewImageBytes;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, String>> examples = []; // ✅ thêm dòng này
  Uint8List? imageBytes; // ✅ thêm dòng này

  bool get isEditMode => widget.initialData != null;

  Future<void> saveWord() async {
    final wordData = {
      'word': _englishController.text.trim(),
      'meaning': _meaningController.text.trim(),
      'phonetic': _phoneticController.text.trim(),
      'usage': _usageController.text.trim(),
      'examples': List<Map<String, String>>.generate(
        exampleEnControllers.length,
        (i) => {
          'en': exampleEnControllers[i].text.trim(),
          'vi': exampleViControllers[i].text.trim(),
        },
      ),
      'imageBytes': _previewImageBytes,
      'isLearned':
          widget.initialData != null &&
          widget.initialData!['isLearned'] == true,
    };

    if (isEditMode) {
      final docId = widget.wordId ?? widget.initialData?['id'];
      final collectionName = widget.initialData!['isLearned'] == true
          ? 'learnedWords'
          : 'unlearnedWords';

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .update(wordData);
    } else {
      await FirebaseFirestore.instance
          .collection('unlearnedWords')
          .add(wordData);
    }

    Navigator.pop(context, true); // gửi true để biết có thay đổi
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final size = image.width < image.height ? image.width : image.height;
        final square = img.copyCrop(
          image,
          x: 0,
          y: 0,
          width: size,
          height: size,
        );
        final resized = img.copyResize(square, width: 300, height: 300);
        setState(() {
          _previewImageBytes = Uint8List.fromList(img.encodeJpg(resized));
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _englishController.text = widget.initialData!['word'] ?? '';
      _meaningController.text = widget.initialData!['meaning'] ?? '';
      _phoneticController.text = widget.initialData!['phonetic'] ?? '';
      _usageController.text = widget.initialData!['usage'] ?? '';

      examples =
          (widget.initialData!['examples'] as List<dynamic>?)
              ?.map(
                (e) => {
                  'en': e['en']?.toString() ?? '',
                  'vi': e['vi']?.toString() ?? '',
                },
              )
              .toList() ??
          [];
      final rawBytes = widget.initialData!['imageBytes'];
      if (rawBytes != null && rawBytes is List) {
        imageBytes = Uint8List.fromList(List<int>.from(rawBytes));
        // ✅ Gán lại ví dụ cũ vào các TextEditingController
        for (var ex in examples) {
          exampleEnControllers.add(TextEditingController(text: ex['en']));
          exampleViControllers.add(TextEditingController(text: ex['vi']));
        }
      }
    }
  }

  void _addExampleGroup() {
    setState(() {
      exampleEnControllers.add(TextEditingController());
      exampleViControllers.add(TextEditingController());
    });
  }

  @override
  void dispose() {
    _englishController.dispose();
    _meaningController.dispose();
    _phoneticController.dispose();
    _usageController.dispose();
    for (final c in exampleEnControllers) {
      c.dispose();
    }
    for (final c in exampleViControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Sửa từ' : 'Nhập từ mới')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _englishController,
                decoration: const InputDecoration(labelText: 'Từ tiếng Anh *'),
              ),
              TextField(
                controller: _meaningController,
                decoration: const InputDecoration(labelText: 'Dịch nghĩa *'),
              ),
              TextField(
                controller: _phoneticController,
                decoration: const InputDecoration(labelText: 'Phiên âm'),
              ),
              TextField(
                controller: _usageController,
                decoration: const InputDecoration(labelText: 'Cách dùng'),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 16),
              const Text(
                'Ví dụ:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (int i = 0; i < exampleEnControllers.length; i++) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: exampleEnControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Câu ví dụ tiếng Anh ${i + 1}',
                  ),
                ),
                TextField(
                  controller: exampleViControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Dịch tiếng Việt ${i + 1}',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Ảnh Flash Card',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              (_previewImageBytes ?? imageBytes) != null
                  ? Image.memory(
                      _previewImageBytes ?? imageBytes!,
                      width: 100,
                      height: 100,
                    )
                  : const Text('Chưa có ảnh'),

              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Chọn ảnh'),
                onPressed: _pickImage,
              ),
              TextButton.icon(
                onPressed: _addExampleGroup,
                icon: const Icon(Icons.add),
                label: const Text('Thêm ví dụ'),
              ),

              const SizedBox(height: 24), // khoảng cách trước nút
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: saveWord,
                  child: Text(isEditMode ? 'Lưu' : 'Thêm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
