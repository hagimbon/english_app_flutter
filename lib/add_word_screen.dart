import 'package:flutter/material.dart';
import 'dart:typed_data'; // ✅ để dùng Uint8List
import 'package:image/image.dart' as img; // ✅ để resize ảnh
import 'package:image_picker/image_picker.dart'; // ✅ để chọn ảnh từ thư viện
import 'package:cloud_firestore/cloud_firestore.dart';

class AddWordScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingWords;
  final Map<String, dynamic>? initialData;
  final String? wordId;
  final bool isOnline; // ✅ thêm dòng này

  const AddWordScreen({
    Key? key,
    required this.existingWords,
    this.initialData,
    this.wordId,
    required this.isOnline, // ✅ thêm dòng này
  }) : super(key: key);

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final TextEditingController _englishController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final TextEditingController _phoneticController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();

  bool isLearned = false; // ⬅️ Dùng để kiểm tra trạng thái đã học hay chưa

  List<TextEditingController> exampleEnControllers = [];
  List<TextEditingController> exampleViControllers = [];

  Uint8List? _previewImageBytes;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, String>> examples = []; // ✅ thêm dòng này
  Uint8List? imageBytes; // ✅ thêm dòng này

  bool get isEditMode => widget.initialData != null;

  Future<void> saveWord() async {
    examples = List.generate(
      exampleEnControllers.length,
      (index) => {
        'en': exampleEnControllers[index].text.trim(),
        'vi': exampleViControllers[index].text.trim(),
      },
    ).where((e) => e['en']!.isNotEmpty || e['vi']!.isNotEmpty).toList();

    final wordData = {
      'word': _englishController.text.trim(),
      'meaning': _meaningController.text.trim(),
      'phonetic': _phoneticController.text.trim(),
      'usage': _usageController.text.trim(),
      'examples': examples,
      'imageBytes': _previewImageBytes ?? imageBytes,
      'isLearned': isLearned,
    };

    if (widget.isOnline) {
      try {
        if (widget.wordId != null) {
          await FirebaseFirestore.instance
              .collection('words')
              .doc(widget.wordId)
              .update(wordData);
        } else {
          await FirebaseFirestore.instance.collection('words').add(wordData);
        }
        if (mounted) {
          Navigator.pop(context, {
            'success': true,
            'updatedWord': wordData, // ✅ gửi dữ liệu về để cập nhật giao diện
            'wordId': widget.wordId,
          });
        }
      } catch (e) {
        debugPrint('❌ Lỗi khi lưu Firebase: $e');
        if (mounted) {
          Navigator.pop(context, {
            'success': true,
            'offline': true,
            'word': wordData,
          });
        }
      }
    } else {
      // ❗ Lưu vào queue nếu offline
      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'offline': true,
          'word': wordData,
        });
      }
    }
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
          imageBytes = _previewImageBytes; // ✅ gán ảnh đã resize vào imageBytes
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _englishController.text = widget.initialData?['word'] ?? '';
    _meaningController.text = widget.initialData?['meaning'] ?? '';
    _phoneticController.text = widget.initialData?['phonetic'] ?? '';
    _usageController.text = widget.initialData?['usage'] ?? '';

    isLearned = widget.initialData?['isLearned'] ?? false;
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
                decoration: InputDecoration(labelText: 'Từ tiếng Anh *'),
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
