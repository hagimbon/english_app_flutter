import 'package:flutter/material.dart';
import 'dart:typed_data'; // ✅ để dùng Uint8List
import 'package:image/image.dart' as img; // ✅ để resize ảnh
import 'package:image_picker/image_picker.dart'; // ✅ để chọn ảnh từ thư viện
import 'package:cloud_firestore/cloud_firestore.dart';

class AddWordScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingWords;
  final Map<String, dynamic>?
  initialData; // 👉 dùng tên này luôn cho thống nhất

  const AddWordScreen({
    super.key,
    required this.existingWords,
    this.initialData,
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

      examples = List<Map<String, String>>.from(
        widget.initialData!['examples'] ?? [],
      );
      imageBytes = widget.initialData!['imageBytes'];
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

  void _submit() async {
    final word = _englishController.text.trim();
    final meaning = _meaningController.text.trim();
    final phonetic = _phoneticController.text.trim();
    final usage = _usageController.text.trim();

    if (word.isEmpty || meaning.isEmpty) return;

    if (!isEditMode &&
        widget.existingWords.any((element) => element['word'] == word)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Dữ liệu trùng'),
          content: const Text('Từ này đã tồn tại trong danh sách.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    List<Map<String, String>> examples = [];
    for (int i = 0; i < exampleEnControllers.length; i++) {
      final en = exampleEnControllers[i].text.trim();
      final vi = exampleViControllers[i].text.trim();
      if (en.isNotEmpty || vi.isNotEmpty) {
        examples.add({'en': en, 'vi': vi});
      }
    }

    await FirebaseFirestore.instance.collection('words').add({
      'word': word,
      'meaning': meaning,
      'phonetic': phonetic,
      'usage': usage,
      'examples': examples,
      'imageBytes': _previewImageBytes,
      'createdAt': Timestamp.now(), // để sắp xếp theo thời gian
      'isLearned': false, // từ mới mặc định là chưa học
    });

    Navigator.pop(context); // quay lại sau khi ghi xong
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _submit,
                child: Text(isEditMode ? 'Lưu' : 'Thêm'),
              ),
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
              _previewImageBytes != null
                  ? Image.memory(_previewImageBytes!, width: 100, height: 100)
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
            ],
          ),
        ),
      ),
    );
  }
}
