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
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart'; // đã có rồi
import 'word_model.dart'; // 👈 Bổ sung dòng này

Future<List<Map<String, dynamic>>> fetchWords({bool isLearned = false}) async {
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

// ✅ Thêm dòng này:

Future<List<Map<String, dynamic>>> fetchWordsFromHive({
  bool isLearned = false,
}) async {
  final box = Hive.box<WordModel>('wordsBox');

  return box.values
      .where((w) => w.isLearned == isLearned)
      .map(
        (w) => {
          'id': w.id,
          'word': w.word,
          'meaning': w.meaning,
          'phonetic': w.phonetic,
          'usage': w.usage,
          'examples': w.examples,
          'imageBytes': w.imageBytes,
          'isLearned': w.isLearned,
        },
      )
      .toList();
}

List<Map<String, dynamic>> learnedWords = [
  {'word': 'apple', 'meaning': 'quả táo', 'phonetic': '/ˈæp.əl/'},
  {'word': 'book', 'meaning': 'quyển sách', 'phonetic': '/bʊk/'},
  {'word': 'car', 'meaning': 'xe hơi', 'phonetic': '/kɑːr/'},
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Bắt buộc

  // ✅ Bắt đầu khởi tạo Hive
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);
  Hive.registerAdapter(WordModelAdapter());
  await Hive.openBox<WordModel>('wordsBox');

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
      home: const MainTabNavigator(), // ✅ đúng chỗ
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
  List<Map<String, dynamic>> pendingQueue = []; // ✅ Hàng đợi chờ sync
  bool isOnline = true; // ✅ Trạng thái mạng
  bool isLoading = true; // ✅ để hiện vòng tròn khi đang tải dữ liệu

  @override
  void initState() {
    super.initState();
    loadWords(); // tải từ Firestore lúc mở app
    _checkConnectivity(); // kiểm tra trạng thái mạng ban đầu

    Connectivity().onConnectivityChanged.listen((result) async {
      final nowOnline = result != ConnectivityResult.none;

      setState(() {
        isOnline = nowOnline;
      });

      if (!isOnline && nowOnline && pendingQueue.isNotEmpty) {
        final existingWords = await fetchWords(); // lấy toàn bộ từ đang có

        for (var word in pendingQueue) {
          // Kiểm tra xem từ đã tồn tại chưa (theo word + meaning)
          final alreadyExists = existingWords.any(
            (w) => w['word'] == word['word'] && w['meaning'] == word['meaning'],
          );

          if (!alreadyExists) {
            await FirebaseFirestore.instance.collection('words').add(word);
          }

          // Nếu id là offline_... thì xoá khỏi danh sách hiển thị
          unlearnedWords.removeWhere((w) => w['id'] == word['id']);
        }

        setState(() {
          pendingQueue.clear();
          isOnline = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Đã đồng bộ các từ khi có mạng')),
          );
        }

        await loadWords(); // nạp lại danh sách từ
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> loadWords() async {
    final stopwatch = Stopwatch()..start();

    // ⬇️ 1. LUÔN load từ Hive trước để hiển thị ngay
    unlearnedWords = await fetchWordsFromHive(isLearned: false);
    learnedOnly = await fetchWordsFromHive(isLearned: true);

    setState(() {
      isLoading = false; // ⬅️ Load xong cache rồi, cho hiển thị ngay
    });

    // ⬇️ 2. Nếu online thì tiếp tục tải từ Firestore để cập nhật
    if (isOnline) {
      final results = await Future.wait([
        fetchWords(isLearned: false),
        fetchWords(isLearned: true),
      ]);

      final unlearned = results[0];
      final learned = results[1];

      final box = Hive.box<WordModel>('wordsBox');
      await box.clear(); // xoá cache cũ

      final Map<String, WordModel> newWordsMap = {
        for (var word in [...unlearned, ...learned])
          word['id']: WordModel(
            id: word['id'],
            word: word['word'],
            meaning: word['meaning'],
            phonetic: word['phonetic'],
            usage: word['usage'],
            examples: List<Map<String, String>>.from(word['examples'] ?? []),
            imageBytes: word['imageBytes']?.cast<int>(),
            isLearned: word['isLearned'] ?? false,
          ),
      };

      await box.putAll(newWordsMap);

      // ⬇️ Cập nhật danh sách sau khi đồng bộ
      setState(() {
        unlearnedWords = unlearned;
        learnedOnly = learned;
      });
    }

    stopwatch.stop();
    print('⏱ loadWords() xong sau ${stopwatch.elapsedMilliseconds}ms');
  }

  void _openAddWordScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWordScreen(
          existingWords: [...unlearnedWords, ...learnedOnly],
          initialData: null,
          isOnline: isOnline,
        ),
      ),
    );

    if (result != null && result['success'] == true) {
      final Map<String, dynamic> newWord = Map<String, dynamic>.from(
        result['updatedWord'] ?? result['word'],
      );

      // Tạo id riêng nếu offline
      final id =
          result['wordId'] ??
          'offline_${DateTime.now().millisecondsSinceEpoch}';
      final wordWithId = {'id': id, ...newWord};

      setState(() {
        unlearnedWords.add(wordWithId);
      });

      // Nếu offline thì cho vào hàng đợi
      if (result['offline'] == true) {
        pendingQueue.add(newWord);
      }
    }
  }

  List<Widget> get _tabs => [
    WordListTab(
      words: unlearnedWords,
      title: 'Từ chưa học',
      isOnline: isOnline, // ✅ thêm dòng này
    ),
    WordListTab(
      words: learnedOnly,
      title: 'Từ đã học',
      isOnline: isOnline, // ✅ thêm dòng này
    ),
    TestTab(words: learnedOnly, unlearnedWords: unlearnedWords),
  ];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: isOnline ? Colors.green : Colors.red,
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                isOnline
                    ? '🔵 Đang kết nối mạng'
                    : '🔴 Không có kết nối mạng – dùng offline',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Expanded(child: _tabs[_currentIndex]), // Giữ nguyên tab
        ],
      ),

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

class WordListTab extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final String title;
  final bool isOnline; // ✅ thêm dòng này

  const WordListTab({
    super.key,
    required this.words,
    required this.title,
    required this.isOnline, // ✅ thêm dòng này
  });

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
      MaterialPageRoute(
        builder: (context) => TestTab(
          words: selectedWords,
          unlearnedWords: [], // 👈 tạm thời truyền danh sách rỗng nếu không cần
        ),
      ),
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
                                onPressed: null, // Tạm thời chưa dùng
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

                              // 👇 Hai nút nằm cạnh nhau
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Sửa từ',
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddWordScreen(
                                            existingWords: widget.words,
                                            initialData: word,
                                            wordId: word['id'],
                                            isOnline: widget.isOnline,
                                          ),
                                        ),
                                      );

                                      if (result != null &&
                                          result['success'] == true) {
                                        final updated =
                                            result['updatedWord']
                                                as Map<String, dynamic>;
                                        final id = result['wordId'];

                                        setState(() {
                                          final index = widget.words.indexWhere(
                                            (w) => w['id'] == id,
                                          );
                                          if (index != -1) {
                                            widget.words[index] = {
                                              'id': id,
                                              ...updated,
                                            };
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Xoá từ',
                                    onPressed: () async {
                                      final id = word['id'];
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Xoá từ này?'),
                                          content: const Text(
                                            'Bạn có chắc muốn xoá từ này không?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Huỷ'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Xoá'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        setState(() {
                                          widget.words.removeWhere(
                                            (w) => w['id'] == id,
                                          );
                                        });

                                        if (widget.isOnline &&
                                            id != null &&
                                            !id.toString().startsWith(
                                              'offline_',
                                            )) {
                                          await FirebaseFirestore.instance
                                              .collection('words')
                                              .doc(id)
                                              .delete();
                                        }
                                      }
                                    },
                                  ),
                                ],
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
                          OverflowBar(
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
