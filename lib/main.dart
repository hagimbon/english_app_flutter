import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'add_word_screen.dart';
import 'firebase_options.dart';
import 'test_tab.dart';

// ✅ Thêm dòng này:

Future<List<Map<String, dynamic>>> fetchWords({bool isLearned = false}) async {
  final querySnapshot = await FirebaseFirestore.instance
      .collection('words')
      .where('isLearned', isEqualTo: isLearned)
      .get();

  return querySnapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'id': doc.id, // để sau này sửa hoặc xóa dễ
      'word': data['word'],
      'meaning': data['meaning'],
      'phonetic': data['phonetic'],
      'usage': data['usage'],
      'examples': List<Map<String, dynamic>>.from(data['examples'] ?? []),
      'imageBytes': data['imageBytes'],
      'isLearned': data['isLearned'] ?? false,
    };
  }).toList();
}

List<Map<String, dynamic>> learnedWords = [
  {'word': 'apple', 'meaning': 'quả táo', 'phonetic': '/ˈæp.əl/'},
  {'word': 'book', 'meaning': 'quyển sách', 'phonetic': '/bʊk/'},
  {'word': 'car', 'meaning': 'xe hơi', 'phonetic': '/kɑːr/'},
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Bắt buộc
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Chờ khởi tạo Firebase
  runApp(const EnglishApp());
}

class EnglishApp extends StatelessWidget {
  const EnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Từ vựng tiếng Anh',
      theme: ThemeData.light(),
      home: const MainTabNavigator(),
    );
  }
}

class MainTabNavigator extends StatefulWidget {
  const MainTabNavigator({super.key});

  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _currentIndex = 2; // 👉 Tab "Test"
  List<Map<String, dynamic>> unlearnedWords = [];
  List<Map<String, dynamic>> learnedOnly = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadWords();
  }

  Future<void> loadWords() async {
    final unlearned = await fetchWords(isLearned: false);
    final learned = await fetchWords(isLearned: true);

    setState(() {
      unlearnedWords = unlearned;
      learnedOnly = learned;
      isLoading = false;
    });
  }

  void _openAddWordScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWordScreen(
          existingWords: [...unlearnedWords, ...learnedOnly],
          initialData: null,
        ),
      ),
    );
    await loadWords(); // Sau khi thêm từ thì tải lại dữ liệu
  }

  List<Widget> get _tabs => [
    WordListTab(words: unlearnedWords, title: 'Từ chưa học'),
    WordListTab(words: learnedOnly, title: 'Từ đã học'),
    TestTab(words: learnedOnly),
  ];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: _tabs[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddWordScreen,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Từ chưa học'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Từ đã học'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Test'),
        ],
      ),
    );
  }
}

class TestTab extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  const TestTab({super.key, required this.words});

  @override
  State<TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<TestTab> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    FirebaseFirestore.instance
        .collection('test')
        .add({'check': 'connected'})
        .then((value) => print('✅ Đã kết nối Firestore!'))
        .catchError((error) => print('❌ Lỗi Firestore: $error'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        scrollDirection: Axis.vertical,
        children: [
          FlashcardScreen(words: widget.words),
          // const _BottomBoxes(), // Tạm thời bỏ vì chưa cần đến
          Container(),
        ],
      ),
    );
  }
}

class FlashcardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  const FlashcardScreen({super.key, required this.words});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int currentIndex = 0;
  Timer? _timer;
  bool isCorrect = false;
  bool isWrong = false;
  bool isTimeOut = false;
  int timeLeft = 15;
  late List<String> options;
  late String correctAnswer;

  @override
  void initState() {
    super.initState();
    if (widget.words.isNotEmpty) {
      startTimer();
      prepareOptions();
    }
  }

  void prepareOptions() {
    final current = widget.words[currentIndex];
    correctAnswer = current['meaning'];
    options = List<String>.from(widget.words.map((e) => e['meaning']));
    while (options.length < 10) {
      options.add('Nghĩa phụ');
    }
    options.shuffle();
    options = options.take(10).toList();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0 && !isCorrect) {
        setState(() {
          timeLeft--;
        });
      } else {
        timer.cancel();
        if (!isCorrect) {
          setState(() {
            isTimeOut = true;
          });
          Future.delayed(const Duration(seconds: 2), nextWord);
        }
      }
    });
  }

  void nextWord() {
    if (widget.words.isEmpty) return; // tránh lỗi chia cho 0

    setState(() {
      currentIndex = (currentIndex + 1) % widget.words.length;
      isCorrect = false;
      isWrong = false;
      isTimeOut = false;
      timeLeft = 15;
      prepareOptions();
      startTimer();
    });
  }

  void checkAnswer(String answer) {
    if (answer == correctAnswer) {
      setState(() {
        isCorrect = true;
        isWrong = false;
      });
      Future.delayed(const Duration(seconds: 2), nextWord);
    } else {
      setState(() {
        isWrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Không có từ để hiển thị',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    final word = widget.words[currentIndex];

    return Scaffold(
      // ✅ Bọc toàn bộ trong Scaffold
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    word['word'],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    word['phonetic'] ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '⏳ $timeLeft giây',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  if (isCorrect)
                    const Text(
                      '✅ Đúng rồi!',
                      style: TextStyle(color: Colors.green, fontSize: 20),
                    )
                  else if (isTimeOut)
                    const Icon(
                      Icons.sentiment_dissatisfied,
                      color: Colors.red,
                      size: 40,
                    )
                  else if (isWrong)
                    const Text(
                      '❌ Sai rồi!',
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: options.map((e) {
                      return ElevatedButton(
                        onPressed: isCorrect || isTimeOut
                            ? null
                            : () => checkAnswer(e),
                        child: Text(e),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: nextWord,
                    child: const Text('Tiếp >'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WordListTab extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final String title;

  const WordListTab({super.key, required this.words, required this.title});

  @override
  State<WordListTab> createState() => _WordListTabState();
}

class _WordListTabState extends State<WordListTab> {
  final Set<String> selectedIds = {}; // ✅ Đặt ở đây mới đúng chỗ
  // chứa id các từ được chọn

  void toggleSelect(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void deleteSelected() {
    for (var id in selectedIds) {
      FirebaseFirestore.instance.collection('words').doc(id).delete();
    }
    setState(() {
      selectedIds.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🗑 Đã xoá các từ đã chọn')));
  }

  void trainSelected() {
    final selectedWords = widget.words
        .where((w) => selectedIds.contains(w['id']))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TestTab(words: selectedWords)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} (${widget.words.length})'),
        actions: [
          if (selectedIds.isNotEmpty)
            Row(
              children: [
                Text(
                  '${selectedIds.length} từ',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: deleteSelected,
                  tooltip: 'Xoá lựa chọn',
                ),
                IconButton(
                  icon: const Icon(Icons.fitness_center),
                  onPressed: trainSelected,
                  tooltip: 'Luyện tập',
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.words.length,
              itemBuilder: (context, index) {
                final word = widget.words[index];
                final id = word['id'] ?? index.toString();
                final isSelected = selectedIds.contains(id);

                return GestureDetector(
                  onTap: () => toggleSelect(id),
                  child: Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: null, // Đã xoá chức năng phát âm
                              ),

                              Expanded(
                                child: Text(
                                  word['word'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddWordScreen(
                                        existingWords: widget.words,
                                        initialData: word,
                                      ),
                                    ),
                                  );
                                  setState(() {}); // Cập nhật sau khi sửa
                                },
                              ),
                            ],
                          ),
                          if (word['phonetic'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                '/${word['phonetic']}/',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text(
                              word['meaning'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          ButtonBar(
                            alignment: MainAxisAlignment.start,
                            children: [
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Cách dùng'),
                                      content: Text(
                                        word['usage'] ?? 'Không có dữ liệu',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Đóng'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Cách dùng'),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Ví dụ'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: (word['examples'] ?? [])
                                            .map<Widget>((e) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '🇬🇧 ${e['en'] ?? ''}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      '🇻🇳 ${e['vi'] ?? ''}',
                                                    ),
                                                  ],
                                                ),
                                              );
                                            })
                                            .toList(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Đóng'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Ví dụ'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fitness_center),
                label: Text('Luyện tập (${selectedIds.length})'),
                onPressed: trainSelected,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
