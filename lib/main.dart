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
import 'load_service.dart';
import 'dart:typed_data';

final GlobalKey<_MainTabNavigatorState> mainTabStateGlobalKey =
    GlobalKey<_MainTabNavigatorState>();
bool mainTabStateMounted = false;

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
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    // ⬅️ dòng này KHÔNG được thiếu
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  Hive.registerAdapter(WordModelAdapter());

  await LoadService.preloadBoxes();

  runApp(const MyApp());
}

class EnglishApp extends StatelessWidget {
  const EnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Từ vựng tiếng Anh',
      theme: ThemeData.light(),
      home: MainTabNavigator(key: mainTabStateGlobalKey), // ✅ đúng chỗ
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
    mainTabStateMounted = true;

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

  @override
  void dispose() {
    mainTabStateMounted = false;
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> loadWords() async {
    final stopwatch = Stopwatch()..start();

    // 1. ⏱ LUÔN load từ Hive trước (nhanh)
    final hiveUnlearned = await fetchWordsFromHive(isLearned: false);
    final hiveLearned = await fetchWordsFromHive(isLearned: true);

    setState(() {
      unlearnedWords = hiveUnlearned
        ..sort(
          (a, b) => (a['word'] ?? '').toString().toLowerCase().compareTo(
            (b['word'] ?? '').toString().toLowerCase(),
          ),
        );
      learnedOnly = hiveLearned;
      isLoading = false;
    });

    // 2. 🕸 Nếu online → đồng bộ từ Firebase → cập nhật lại Hive
    if (isOnline) {
      syncFromFirebase(); // ✅ gọi hàm riêng để đồng bộ
    }

    stopwatch.stop();
    print('⏱ loadWords() xong sau ${stopwatch.elapsedMilliseconds}ms');
  }

  Future<void> syncFromFirebase() async {
    final results = await Future.wait([
      fetchWords(isLearned: false),
      fetchWords(isLearned: true),
    ]);

    final unlearned = results[0];
    final learned = results[1];

    final box = Hive.box<WordModel>('wordsBox');

    // ✅ Xoá toàn bộ dữ liệu cũ trong Hive (nếu cần)
    await box.clear();

    // ✅ Lưu toàn bộ dữ liệu mới từ Firebase vào Hive
    for (var word in [...unlearned, ...learned]) {
      final model = WordModel(
        id: word['id'],
        word: word['word'],
        meaning: word['meaning'],
        phonetic: word['phonetic'],
        usage: word['usage'],
        examples: List<Map<String, String>>.from(word['examples'] ?? []),
        imageBytes: word['imageBytes']?.cast<int>(),
        isLearned: word['isLearned'] ?? false,
      );

      await box.put(model.id, model);
    }

    // ✅ Sau khi đã ghi Hive, load lại Hive và hiển thị
    final hiveUnlearned = await fetchWordsFromHive(isLearned: false);
    final hiveLearned = await fetchWordsFromHive(isLearned: true);

    if (mounted) {
      setState(() {
        unlearnedWords = hiveUnlearned;
        learnedOnly = hiveLearned;
      });
    }

    print('✅ Đồng bộ dữ liệu từ Firebase về Hive thành công');
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

      // ✅ Ghi vào Hive trước
      final box = Hive.box<WordModel>('wordsBox');
      final model = WordModel(
        id: wordWithId['id'],
        word: wordWithId['word'],
        meaning: wordWithId['meaning'],
        phonetic: wordWithId['phonetic'],
        usage: wordWithId['usage'],
        examples: List<Map<String, String>>.from(wordWithId['examples'] ?? []),
        imageBytes: wordWithId['imageBytes']?.cast<int>(),
        isLearned: false,
      );
      await box.put(model.id, model);

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
  String searchText = '';
  String sortType = 'A-Z'; // hoặc 'Mới thêm'

  void toggleSelect(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bạn có muốn xóa từ đã chọn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final box = Hive.box<WordModel>('wordsBox');

      for (var id in selectedIds) {
        // Xóa trong Hive
        await box.delete(id);

        // Xóa trên Firestore nếu online và không phải từ offline
        if (widget.isOnline && !id.toString().startsWith('offline_')) {
          await FirebaseFirestore.instance.collection('words').doc(id).delete();
        }
      }

      setState(() {
        widget.words.removeWhere((word) => selectedIds.contains(word['id']));
        selectedIds.clear();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('🗑 Đã xóa các từ đã chọn')));
    } else {
      // Nếu chọn "Không", cũng clear lựa chọn
      setState(() {
        selectedIds.clear();
      });
    }
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
    // ✅ Đặt lọc + sắp xếp ở đây
    List<Map<String, dynamic>> filteredWords = widget.words.where((word) {
      final text = searchText.toLowerCase();
      final wordText = (word['word'] ?? '').toString().toLowerCase();
      return wordText.contains(text);
    }).toList();

    if (sortType == 'A-Z') {
      filteredWords.sort(
        (a, b) => (a['word'] ?? '').toString().toLowerCase().compareTo(
          (b['word'] ?? '').toString().toLowerCase(),
        ),
      );
    } else if (sortType == 'Mới thêm') {
      filteredWords = filteredWords.reversed.toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.title} (${widget.words.length})'),
            if (widget.title == 'Từ đã học' || widget.title == 'Từ chưa học')
              TextField(
                onChanged: (value) => setState(() => searchText = value),
                decoration: const InputDecoration(
                  hintText: '🔍 Tìm theo từ tiếng Anh',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
          ],
        ),
        actions: [
          if (widget.title == 'Từ đã học' || widget.title == 'Từ chưa học') ...[
            IconButton(
              icon: Icon(
                sortType == 'A-Z' ? Icons.sort_by_alpha : Icons.access_time,
              ),
              tooltip: sortType == 'A-Z'
                  ? 'Sắp xếp theo Mới thêm'
                  : 'Sắp xếp A-Z',
              onPressed: () {
                setState(() {
                  sortType = sortType == 'A-Z' ? 'Mới thêm' : 'A-Z';
                });
              },
            ),
          ],
          if (selectedIds.isNotEmpty)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${selectedIds.length} từ'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Bỏ chọn',
                  onPressed: () {
                    setState(() {
                      selectedIds.clear();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Xoá từ đã chọn',
                  onPressed: deleteSelected,
                ),
              ],
            ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: filteredWords.length,
              itemBuilder: (context, index) {
                final word = filteredWords[index];
                final id = word['id'] ?? index.toString();
                final isSelected = selectedIds.contains(id);

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      word['word'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (word['phonetic'] != null &&
                                        word['phonetic'].toString().isNotEmpty)
                                      Text(
                                        '/${word['phonetic']}/',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '🇻🇳 ${word['meaning'] ?? ''}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    if (word['usage'] != null &&
                                        word['usage'].toString().isNotEmpty)
                                      Text('📌 Cách dùng: ${word['usage']}'),
                                    const SizedBox(height: 8),
                                    if ((word['examples'] ?? []).isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '📚 Ví dụ:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          ...List<Widget>.from(
                                            (word['examples'] ?? []).map<
                                              Widget
                                            >(
                                              (e) => Padding(
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
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (word['imageBytes'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Image.memory(
                                          Uint8List.fromList(
                                            List<int>.from(word['imageBytes']),
                                          ),
                                          width: 200,
                                          height: 200,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },

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
                                    icon: Icon(
                                      selectedIds.contains(id)
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: selectedIds.contains(id)
                                          ? Colors.green
                                          : null,
                                    ),
                                    tooltip: selectedIds.contains(id)
                                        ? 'Bỏ chọn'
                                        : 'Chọn',
                                    onPressed: () {
                                      toggleSelect(
                                        id,
                                      ); // Gọi lại hàm chọn có sẵn
                                    },
                                  ),

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

                                        // ✅ Cập nhật Hive
                                        final box = Hive.box<WordModel>(
                                          'wordsBox',
                                        );
                                        final updatedModel = WordModel(
                                          id: id,
                                          word: updated['word'],
                                          meaning: updated['meaning'],
                                          phonetic: updated['phonetic'],
                                          usage: updated['usage'],
                                          examples:
                                              List<Map<String, String>>.from(
                                                updated['examples'] ?? [],
                                              ),
                                          imageBytes: updated['imageBytes']
                                              ?.cast<int>(),
                                          isLearned:
                                              widget.title ==
                                              'Từ đã học', // Dựa theo tab
                                        );
                                        await box.put(id, updatedModel);
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

                                        // ✅ Xoá khỏi Hive
                                        final box = Hive.box<WordModel>(
                                          'wordsBox',
                                        );
                                        await box.delete(id);

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainTabNavigator(), // 👈 Đây là màn hình chính của app
    );
  }
}
