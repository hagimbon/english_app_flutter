import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'add_word_screen.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:english_app/word_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'main_tab.dart';

List<Map<String, dynamic>> learnedWords = [
  {'word': 'apple', 'meaning': 'quả táo', 'phonetic': '/ˈæp.əl/'},
  {'word': 'book', 'meaning': 'quyển sách', 'phonetic': '/bʊk/'},
  {'word': 'car', 'meaning': 'xe hơi', 'phonetic': '/kɑːr/'},
];

class EnglishApp extends StatelessWidget {
  const EnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Từ vựng tiếng Anh', theme: ThemeData.light());
  }
}

class TestTab extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final List<Map<String, dynamic>> unlearnedWords;
  final List<Map<String, dynamic>> practiceWords; // ✅ thêm dòng này
  final bool isOnline;

  const TestTab({
    super.key,
    required this.words,
    required this.unlearnedWords,
    required this.practiceWords, // ✅ thêm dòng này
    required this.isOnline,
  });

  @override
  State<TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<TestTab> {
  late PageController _controller;
  late List<Map<String, dynamic>> practiceWords;
  Map<String, bool> showHintButton = {}; // ✅ Cờ để hiện nút gợi ý theo từ
  Map<String, int> wrongAttempts = {}; // ✅ Đếm số lần sai cho từng từ

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 1);

    // Gán tạm để tránh lỗi null
    practiceWords = [];

    // Load practiceWords từ file
    loadPracticeWords().then((_) {
      setState(() {});
    });
  }

  Future<void> savePracticeWords() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/practice_words.json');

    // Tạo danh sách mới có chứa trạng thái đầy đủ cho mỗi từ
    final dataToSave = practiceWords.map((word) {
      return {
        'id': word['id'],
        'word': word['word'],
        'meaning': word['meaning'],
        'phonetic': word['phonetic'],
        'selectedAnswer': word['selectedAnswer'],
        'isCorrect': word['isCorrect'],
        'wrongAttempts': word['wrongAttempts'],
        'showHint': word['showHint'],
        'wasHinted': word['wasHinted'],
        'isDone': word['isDone'] ?? false,
      };
    }).toList();

    await file.writeAsString(jsonEncode(dataToSave));
    print('✅ Đã lưu trạng thái luyện tập vào file practice_words.json');
  }

  Future<void> loadPracticeWords() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/practice_words.json');

    if (await file.exists()) {
      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);
      setState(() {
        practiceWords = data
            .map<Map<String, dynamic>>(
              (w) => {
                'id': w['id'],
                'word': w['word'],
                'meaning': w['meaning'],
                'phonetic': w['phonetic'],
                'selectedAnswer': w['selectedAnswer'],
                'isCorrect': w['isCorrect'],
                'wrongAttempts': w['wrongAttempts'] ?? 0,
                'showHint': w['showHint'] ?? false,
                'wasHinted': w['wasHinted'] ?? false,
                'isDone': w['isDone'] ?? false,
              },
            )
            .toList();
      });
      print('✅ Đã khôi phục trạng thái từ file practice_words.json');
    } else {
      practiceWords = [];
    }
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
          // ✅ Nếu danh sách từ đã học rỗng, hiển thị nút Thêm từ
          if (practiceWords.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Không có từ để luyện tập',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      showSelectWordsPopup(
                        context,
                        widget.unlearnedWords,
                        widget.words,
                        (selected) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              practiceWords.addAll(
                                selected.where(
                                  (w) => !practiceWords.any(
                                    (p) => p['id'] == w['id'],
                                  ),
                                ),
                              );
                            });
                            savePracticeWords();
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm từ để luyện'),
                  ),
                ],
              ),
            )
          else
            FlashcardScreen(words: widget.words),

          PracticeBoxes(
            words: widget.words,
            unlearnedWords: widget.unlearnedWords,
            practiceWords: practiceWords,
            isOnline: widget.isOnline, // ✅ phải có dòng này
            key: ValueKey(practiceWords.length),
          ),
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
  Timer? _timer; // ✅ thêm dòng này
  bool isCorrect = false;
  bool isWrong = false;
  bool isTimeOut = false;
  int timeLeft = 15;
  late List<String> options;
  late String correctAnswer;

  @override
  void initState() {
    super.initState();

    if (widget.words.isEmpty) return; // ✅ bảo vệ nếu rỗng

    startTimer();
    prepareOptions();
  }

  void prepareOptions() {
    final current = widget.words[currentIndex];
    correctAnswer = current['meaning'];
    options = List<String>.from(widget.words.map((e) => e['meaning']));
    while (options.length < 10) {
      options.add('Nghĩa phụ');
    }
    options = options.take(10).toList();
    options.shuffle(); // 👉 dòng mới thêm
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0 && !isCorrect) {
        if (mounted) {
          setState(() {
            timeLeft--;
          });
        }
      } else {
        timer.cancel();
        if (!isCorrect) {
          if (mounted) {
            setState(() {
              isTimeOut = true;
            });
          }
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) nextWord();
          });
        }
      }
    });
  }

  void nextWord() {
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
    final word = widget.words[currentIndex];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word['word'],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Text(
            word['phonetic'] ?? '',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text('⏳ $timeLeft giây', style: const TextStyle(fontSize: 18)),
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
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(options.length, (index) {
              return SizedBox(
                width:
                    MediaQuery.of(context).size.width /
                    2.5, // khoảng 4 nút mỗi dòng
                child: ElevatedButton(
                  onPressed: isCorrect || isTimeOut
                      ? null
                      : () => checkAnswer(options[index]),
                  child: Text(options[index], textAlign: TextAlign.center),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),
          ElevatedButton(onPressed: nextWord, child: const Text('Tiếp >')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel(); // ✅ Hủy Timer khi rời khỏi màn hình
    super.dispose();
  }
}

Widget buildBoxTuMoi() {
  return Card(
    margin: EdgeInsets.all(8),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Từ mới",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          // TODO: Hiển thị danh sách từ cần luyện tập
        ],
      ),
    ),
  );
}

Widget buildBoxTuDaHoc() {
  return Card(
    margin: EdgeInsets.all(8),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Từ đã học",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          // TODO: Hiển thị 10 từ ngẫu nhiên để luyện
        ],
      ),
    ),
  );
}

Widget buildBoxFlashCardTuMoi() {
  return Card(
    margin: EdgeInsets.all(8),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Flash Card từ mới",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          // TODO: Hiển thị ảnh + chọn nghĩa đúng
        ],
      ),
    ),
  );
}

class _BottomBoxes extends StatelessWidget {
  const _BottomBoxes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBox(title: 'Từ mới', color: Colors.orange),
            const SizedBox(height: 20),
            _buildBox(title: 'Từ chưa học', color: Colors.blue),
            const SizedBox(height: 20),
            _buildBox(title: 'Từ đã học', color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildBox({required String title, required Color color}) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 22,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class PracticeBoxes extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final List<Map<String, dynamic>> unlearnedWords;
  final List<Map<String, dynamic>> practiceWords;
  final bool isOnline;

  const PracticeBoxes({
    super.key,
    required this.words,
    required this.unlearnedWords,
    required this.practiceWords,
    required this.isOnline,
  });

  @override
  State<PracticeBoxes> createState() => PracticeBoxesState();
}

class PracticeBoxesState extends State<PracticeBoxes> {
  late List<Map<String, dynamic>> practiceWords;
  late List<Map<String, dynamic>> unlearnedWords;
  late List<Map<String, dynamic>> words;
  bool hasShownCompletionDialog = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    practiceWords = List.from(widget.practiceWords);
    unlearnedWords = widget.unlearnedWords;
    words = widget.words;
  }

  Future<void> savePracticeWords() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/practice_words.json');
    await file.writeAsString(jsonEncode(practiceWords));
  }

  void moveWordsToLearned() async {
    final box = Hive.box<WordModel>('wordsBox');
    final learnedWords = practiceWords
        .where((w) => w['isDone'] == true)
        .toList();

    for (var word in learnedWords) {
      // 👉 Xoá các flag tạm thời trước khi lưu
      word.remove('isCorrect');
      word.remove('selectedAnswer');
      word.remove('wasHinted');
      word.remove('wrongAttempts');
      word.remove('showHint');
      word['isDone'] = false;

      // 👉 Tạo đối tượng model chuẩn để lưu
      final model = WordModel(
        id: word['id'],
        word: word['word'],
        meaning: word['meaning'],
        phonetic: word['phonetic'] ?? '',
        usage: word['usage'] ?? '',
        examples: List<Map<String, String>>.from(word['examples'] ?? []),
        imageBytes: word['imageBytes']?.cast<int>(),
        isLearned: true,
      );

      await box.put(model.id, model); // ✅ Lưu vào Hive

      // ✅ Nếu online và không phải từ offline thì đồng bộ lên Firebase
      if (mainTabStateMounted &&
          mainTabStateGlobalKey.currentState?.isOnline == true &&
          !word['id'].toString().startsWith('offline_')) {
        FirebaseFirestore.instance.collection('words').doc(word['id']).update({
          'isLearned': true,
        });
      }
    }

    // 👉 Cập nhật lại danh sách trong app
    setState(() {
      // Xoá khỏi danh sách từ chưa học
      for (var word in learnedWords) {
        unlearnedWords.removeWhere((w) => w['id'] == word['id']);
      }

      // Xoá khỏi danh sách đang luyện tập
      practiceWords.removeWhere(
        (w) => learnedWords.any((lw) => lw['id'] == w['id']),
      );
    });

    savePracticeWords(); // ✅ Lưu lại file JSON tạm

    if (mainTabStateMounted) {
      mainTabStateGlobalKey.currentState?.loadWords();
    }

    setState(() {
      for (var word in learnedWords) {
        // Xoá flag tạm
        word.remove('isCorrect');
        word.remove('selectedAnswer');
        word.remove('wasHinted');
        word.remove('wrongAttempts');
        word.remove('showHint');
        word['isDone'] = false;

        // ✅ Cập nhật trạng thái học
        final model = WordModel(
          id: word['id'],
          word: word['word'],
          meaning: word['meaning'],
          phonetic: word['phonetic'] ?? '',
          usage: word['usage'] ?? '',
          examples: List<Map<String, String>>.from(word['examples'] ?? []),
          imageBytes: word['imageBytes']?.cast<int>(),
          isLearned: true,
        );
        box.put(word['id'], model); // ✅ Lưu vào Hive

        // ✅ Gỡ khỏi danh sách từ chưa học
        unlearnedWords.removeWhere((w) => w['id'] == word['id']);
      }

      // ✅ Gỡ khỏi practiceWords
      practiceWords.removeWhere(
        (w) => learnedWords.any((lw) => lw['id'] == w['id']),
      );
    });

    savePracticeWords(); // lưu lại file cache
  }

  void checkPracticeCompletion() {
    if (hasShownCompletionDialog ||
        !practiceWords.every(
          (w) => w['isDone'] == true || w['wasHinted'] == true,
        )) {
      return;
    }
    final allDone = practiceWords.every(
      (w) => w['isDone'] == true && (w['wasHinted'] != true),
    );
    final hasHinted = practiceWords.any((w) => w['wasHinted'] == true);

    if (practiceWords.isEmpty) return;
    hasShownCompletionDialog = true;

    if (hasHinted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('⚠️ Bạn cần cố gắng hơn nữa'),
          content: const Text('Một số câu bạn đã dùng gợi ý.'),
          actions: [
            TextButton(
              onPressed: () async {
                setState(() {
                  isLoading = true;
                });

                await Future.delayed(const Duration(milliseconds: 500));

                setState(() {
                  practiceWords.shuffle();
                  for (int i = 0; i < practiceWords.length; i++) {
                    final word = practiceWords[i];
                    final reset = {
                      'id': word['id'],
                      'word': word['word'],
                      'meaning': word['meaning'],
                      'phonetic': word['phonetic'],
                    };
                    practiceWords[i] = reset;

                    final exists = unlearnedWords.any(
                      (w) => w['id'] == reset['id'],
                    );
                    if (!exists) {
                      unlearnedWords.add(reset);
                    }
                  }

                  hasShownCompletionDialog = false;
                  isLoading = false;
                });

                savePracticeWords();
                if (context.mounted) Navigator.pop(context);
              },

              child: const Text('Luyện tập lại'),
            ),
          ],
        ),
      );
    } else if (allDone) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('🎉 Bạn đã trả lời đúng hết!'),
          content: const Text(
            'Bạn có muốn di chuyển những từ này vào danh sách "Từ đã học" không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                moveWordsToLearned();
                Navigator.pop(context);
              },
              child: const Text('Có'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  isLoading = true;
                });

                await Future.delayed(const Duration(milliseconds: 500));

                setState(() {
                  practiceWords.shuffle();
                  for (int i = 0; i < practiceWords.length; i++) {
                    final word = practiceWords[i];
                    final reset = {
                      'id': word['id'],
                      'word': word['word'],
                      'meaning': word['meaning'],
                      'phonetic': word['phonetic'],
                    };
                    practiceWords[i] = reset;

                    final exists = unlearnedWords.any(
                      (w) => w['id'] == reset['id'],
                    );
                    if (!exists) {
                      unlearnedWords.add(reset);
                    }
                  }

                  hasShownCompletionDialog = false;
                  isLoading = false;
                });

                savePracticeWords();
                if (context.mounted) Navigator.pop(context);
              },

              child: const Text('Học lại'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildPracticeBoxes(context);
  }

  Widget buildPracticeBoxes(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ✅ PHẦN HIỂN THỊ BOX BÊN DƯỚI
                Expanded(
                  child: unlearnedWords.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Không có từ để luyện tập',
                              style: TextStyle(fontSize: 18, color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddWordScreen(
                                      existingWords: const [],
                                      isOnline: false,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm từ'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            _buildBox(context, 'Từ mới', practiceWords),
                            const SizedBox(width: 8),
                            _buildBox(context, 'Từ đã học', const []),
                            const SizedBox(width: 8),
                            _buildFlashCardBox(context),
                          ],
                        ),
                ),
              ],
            ),
          );
  }

  Widget _buildFlashCardBox(BuildContext ctx) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FlashCardQuizBox(unlearnedWords: unlearnedWords),
        ),
      ),
    );
  }

  Widget _buildBox(
    BuildContext ctx,
    String title,
    List<Map<String, dynamic>> data,
  ) {
    return Expanded(
      child: Card(
        color: Colors.green.shade50,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),

                  // 👉 Chỉ hiển thị nút thêm nếu là "Từ mới"
                  if (title == 'Từ mới') ...[
                    IconButton(
                      onPressed: () {
                        showSelectWordsPopup(
                          ctx,
                          unlearnedWords,
                          practiceWords,
                          (selected) {
                            setState(() {
                              practiceWords.addAll(
                                selected.where(
                                  (w) => !practiceWords.any(
                                    (p) => p['id'] == w['id'],
                                  ),
                                ),
                              );
                            });
                            savePracticeWords();
                          },
                        );
                      },
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () {
                        showEditPracticeWordsPopup(ctx, practiceWords, (
                          removed,
                        ) {
                          setState(() {
                            // 👉 Xóa từ khỏi danh sách luyện tập
                            practiceWords.removeWhere(
                              (w) => removed.any((r) => r['id'] == w['id']),
                            );

                            // 👉 Đặt lại trạng thái cũ (reset flag như mới)
                            final resetWords = removed.map((word) {
                              return {
                                ...word,
                                'isCorrect': null,
                                'selectedAnswer': null,
                                'wasHinted': null,
                                'showHint': null,
                                'wrongAttempts': null,
                                'isDone': null,
                              };
                            }).toList();

                            // 👉 Thêm về danh sách "unlearned" (từ chưa học)
                            for (var word in resetWords) {
                              final exists = unlearnedWords.any(
                                (w) => w['id'] == word['id'],
                              );
                              if (!exists) {
                                unlearnedWords.add(
                                  word,
                                ); // chỉ thêm nếu chưa có
                              }
                            }
                          });

                          savePracticeWords();
                        });
                      },

                      icon: const Icon(Icons.edit),
                      style: IconButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    ),
                  ],
                  Text('${data.where((w) => w['isDone'] != true).length}'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: data.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hiện chưa có từ để luyện tập, hãy thêm vào!',
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              showSelectWordsPopup(
                                ctx,
                                unlearnedWords,
                                practiceWords,
                                (selected) {
                                  setState(() {
                                    practiceWords.addAll(
                                      selected.where(
                                        (w) => !practiceWords.any(
                                          (p) => p['id'] == w['id'],
                                        ),
                                      ),
                                    );
                                  });
                                  savePracticeWords();
                                },
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Chọn từ để luyện tập'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final word = data[index];
                          return WordChoiceTile(
                            key: ValueKey(
                              '${word['id']}_${word['selectedAnswer'] ?? 'none'}_${word['isDone'] ?? '0'}',
                            ),
                            word: word,
                            allWords: unlearnedWords,
                            onSave: () {
                              savePracticeWords();
                              setState(() {}); // ✅ buộc cập nhật lại số từ
                            },
                            onCheckDone: checkPracticeCompletion,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WordChoiceTile extends StatefulWidget {
  final Map<String, dynamic> word;
  final List<Map<String, dynamic>> allWords;
  final VoidCallback onSave; // ✅ thêm dòng này
  final VoidCallback? onCheckDone;

  const WordChoiceTile({
    Key? key, // ✅ thêm dòng này
    required this.word,
    required this.allWords,
    required this.onSave, // ✅ thêm dòng này
    this.onCheckDone,
  });

  @override
  State<WordChoiceTile> createState() => _WordChoiceTileState(); // ✅ THÊM DÒNG NÀY
}

class _WordChoiceTileState extends State<WordChoiceTile> {
  String? selected;
  bool? isCorrect;
  bool wasHinted = false; // ✅ THÊM biến này vào đầu class
  bool wasWrongedRecently = false;
  List<String> options = [];
  Map<String, bool> showHintButton = {};
  Map<String, int> wrongAttempts = {};

  int wrongCount = 0;
  bool showHint = false;

  @override
  void initState() {
    super.initState();
    generateOptions();

    selected = widget.word['selectedAnswer'];
    isCorrect = widget.word['isCorrect'];
  }

  @override
  void didUpdateWidget(covariant WordChoiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Cập nhật lại state nếu widget.word thay đổi
    if (oldWidget.word['id'] != widget.word['id'] ||
        oldWidget.word['selectedAnswer'] != widget.word['selectedAnswer'] ||
        oldWidget.word['isCorrect'] != widget.word['isCorrect']) {
      setState(() {
        selected = widget.word['selectedAnswer'];
        isCorrect = widget.word['isCorrect'];
      });
    }
  }

  void generateOptions() {
    options = [];

    final correctMeaning = widget.word['meaning'] as String; // ép kiểu tại đây
    final otherWords = widget.allWords
        .where((w) => w['id'] != widget.word['id'])
        .toList();

    options = [correctMeaning]; // luôn có nghĩa đúng ở đầu

    final Set<String> seen = {correctMeaning}; // ✅ chỉ khai báo 1 lần

    // Lấy 5 nghĩa sai
    for (var word in otherWords) {
      final meaning = word['meaning'];
      if (meaning != null && !seen.contains(meaning)) {
        options.add(meaning);
        seen.add(meaning);
      }
      if (options.length >= 6) break; // 1 đúng + 5 sai
    }

    options.shuffle(); // đảo vị trí ngẫu nhiên
  }

  void onSelect(String? value) {
    setState(() {
      selected = value;
      isCorrect = (value == widget.word['meaning']);

      widget.word['selectedAnswer'] = value;
      widget.word['isCorrect'] = isCorrect;
      widget.word['wrongAttempts'] = (widget.word['wrongAttempts'] ?? 0) + 1;

      // ✅ Nếu sai và đã sai đủ 3 lần → hiển thị gợi ý
      if (!isCorrect!) {
        if (widget.word['wrongAttempts']! >= 3) {
          widget.word['showHint'] = true;
        }

        wasWrongedRecently = true;
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              wasWrongedRecently = false;
              selected = null;
            });
          }
        });
      } else {
        widget.word['showHint'] = false;
        widget.word['wrongAttempts'] = 0;
        widget.word['isDone'] = true;
      }
    });

    widget.onSave();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PracticeBoxesState? parentState = context
          .findAncestorStateOfType<PracticeBoxesState>();
      parentState?.checkPracticeCompletion();
    });

    if (widget.word['isDone'] == true) {
      widget.onCheckDone?.call(); // Gọi kiểm tra khi làm xong từ
    }
  }

  void resetState() {
    setState(() {
      wrongCount = 0;
      showHint = false;
      selected = null;
      isCorrect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Lấy cờ trạng thái từ word
    final wrongCount = widget.word['wrongAttempts'] ?? 0;
    final showHint = widget.word['showHint'] ?? false;
    final wasHinted = widget.word['wasHinted'] ?? false;
    final isCorrectNow = widget.word['isCorrect'] == true;

    // ✅ Xác định màu nền
    // ✅ Xác định màu nền
    Color? bgColor;
    if (wasWrongedRecently) {
      bgColor = Colors.red.shade200; // 🔴 Sai tạm thời
    } else if (wasHinted) {
      bgColor = const Color(0xFFb9b9b9); // màu xám
    } else if (showHint) {
      bgColor = Colors.red.shade200;
    } else if (isCorrectNow) {
      bgColor = Colors.green.shade200;
    }

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.word['word'], style: const TextStyle(fontSize: 20)),

            // Dropdown chọn nghĩa
            if (!isCorrectNow)
              DropdownButton<String>(
                value: options.contains(selected) ? selected : null,
                hint: const Text("Chọn nghĩa"),
                items: options
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: onSelect,
              ),

            // Nếu đúng → hiện nghĩa
            if (selected != null && isCorrect == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('🇻🇳 ${widget.word['meaning']}'),
              ),

            // ✅ Nút Gợi ý
            if (showHint &&
                (selected == null || selected != widget.word['meaning']))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selected = widget.word['meaning'];
                      isCorrect = true;
                      widget.word['selectedAnswer'] = widget.word['meaning'];
                      widget.word['isCorrect'] = true;
                      widget.word['wasHinted'] = true;
                      widget.word['showHint'] = false;
                      widget.word['wrongAttempts'] = 0;
                      widget.word['isDone'] = true;
                    });
                    widget.onSave();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87b470),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Gợi ý'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FlashCardQuizBox extends StatefulWidget {
  const FlashCardQuizBox({
    super.key,
    required this.unlearnedWords,
  }); // ✅ tên trùng
  final List<Map<String, dynamic>> unlearnedWords;

  @override
  State<FlashCardQuizBox> createState() => _FlashCardQuizBoxState();
}

class _FlashCardQuizBoxState extends State<FlashCardQuizBox> {
  int currentIndex = 0;
  String? selected;
  bool? isCorrect;
  int wrongCount = 0;
  bool showHint = false;
  bool showExamples = false;
  bool isFinished = false;
  bool wasWrongedRecently = false;
  MemoryImage? firstImage; // ✅ khai báo biến ảnh đầu tiên
  List<Map<String, dynamic>> flashWords = [];
  List<String> choices = [];

  @override
  void initState() {
    super.initState();

    flashWords = widget.unlearnedWords
        .where(
          (w) =>
              w['imageBytes'] != null && (w['imageBytes'] as List).isNotEmpty,
        )
        .toList();

    flashWords.shuffle(); // trộn ngẫu nhiên

    if (flashWords.isNotEmpty) {
      // 👉 hiện ảnh đầu tiên ngay
      firstImage = MemoryImage(
        Uint8List.fromList(List<int>.from(flashWords[0]['imageBytes'])),
      );

      // 🧠 tải ảnh còn lại ngầm
      WidgetsBinding.instance.addPostFrameCallback((_) {
        preloadRemainingImages();
      });
    }

    prepareChoices();
  }

  void preloadRemainingImages() async {
    for (int i = 1; i < flashWords.length; i++) {
      if (!mounted) return; // 🛡 kiểm tra widget chưa bị dispose

      final bytes = flashWords[i]['imageBytes'];
      if (bytes != null) {
        final image = MemoryImage(Uint8List.fromList(List<int>.from(bytes)));
        await precacheImage(image, context);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (flashWords.isEmpty) {
      return const Center(child: Text('Không có từ có ảnh để luyện'));
    }

    final word = flashWords[currentIndex];

    return Container(
      decoration: BoxDecoration(
        color: isCorrect == true
            ? Colors.green.shade100
            : isCorrect == false
            ? Colors.red.shade100
            : Colors.pink.shade100, // Màu nền mặc định
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Flash Card từ mới",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('${flashWords.length}'),
            ],
          ),
          const SizedBox(height: 12),

          // ẢNH
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: currentIndex == 0 && firstImage != null
                ? Image(
                    image: firstImage!,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Image.memory(
                    Uint8List.fromList(List<int>.from(word['imageBytes'])),
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
          ),

          const SizedBox(height: 16),
          Text(
            word['word'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          Text(
            word['phonetic'] ?? '',
            style: const TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 8),
          DropdownButton<String>(
            value: selected,
            hint: const Text('Choose'),
            items: choices
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: isCorrect == null
                ? (value) => selectAnswer(value!)
                : null,
          ),

          const SizedBox(height: 12),

          // Nút xem ví dụ hoặc 2 nút gợi ý + bỏ qua
          if (!showHint)
            TextButton(
              onPressed: () {
                setState(() {
                  showExamples = !showExamples;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xem ví dụ'),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selected = word['meaning'];
                      isCorrect = true;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF87b470),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Gợi ý'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: nextCard,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFbdbdbd),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Bỏ qua'),
                ),
              ],
            ),

          // Ví dụ
          if (showExamples && word['examples'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(word['examples'].length, (i) {
                final e = word['examples'][i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🇬🇧 ${e['en'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('🇻🇳 ${e['vi'] ?? ''}'),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ),

          const SizedBox(height: 16),

          // Mũi tên điều hướng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentIndex > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      currentIndex--;
                      selected = null;
                      isCorrect = null;
                      wrongCount = 0;
                      showHint = false;
                      showExamples = false;
                      prepareChoices();
                    });
                  },
                ),
              if (currentIndex < flashWords.length - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: nextCard,
                ),
            ],
          ),

          // Nếu làm hết
          if (isFinished)
            Column(
              children: [
                const Text(
                  'Bạn cần luyện tập thêm!',
                  style: TextStyle(color: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentIndex = 0;
                      selected = null;
                      isCorrect = null;
                      wrongCount = 0;
                      showHint = false;
                      isFinished = false;
                      flashWords.shuffle();
                      prepareChoices();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text('Luyện lại'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void prepareChoices() {
    final current = flashWords[currentIndex];
    final correct = current['meaning'];
    final allWrong =
        widget.unlearnedWords
            .map((e) => e['meaning'])
            .where((m) => m != correct)
            .toList()
          ..shuffle();
    choices = [correct, ...allWrong.take(7)];
    choices.shuffle();
  }

  void selectAnswer(String value) {
    setState(() {
      selected = value;
      isCorrect = value == flashWords[currentIndex]['meaning'];
      if (!isCorrect!) {
        wasWrongedRecently = true;

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              wasWrongedRecently = false;
              selected = null; // ✅ Cho phép chọn lại
            });
          }
        });
      }
    });
  }

  void nextCard() {
    if (currentIndex < flashWords.length - 1) {
      setState(() {
        currentIndex++;
        selected = null;
        isCorrect = null;
        wrongCount = 0;
        showHint = false;
        showExamples = false;
        prepareChoices();
      });
    } else {
      setState(() {
        isFinished = true;
      });
    }
  }
}

void showSelectWordsPopup(
  BuildContext context,
  List<Map<String, dynamic>> availableWords,
  List<Map<String, dynamic>> currentPracticeWords,
  void Function(List<Map<String, dynamic>>)
  onWordsSelected, // ⚠️ Bắt buộc phải có callback này
) {
  TextEditingController searchController = TextEditingController();
  List<String> selectedIds = [];
  List<String> idsMarkedToDelete = [];

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        List<Map<String, dynamic>> filtered = availableWords.where((word) {
          final text = searchController.text.toLowerCase();
          final isInPractice = currentPracticeWords.any(
            (w) => w['id'] == word['id'],
          );
          return word['word'].toString().toLowerCase().contains(text) &&
              !isInPractice;
        }).toList();

        return AlertDialog(
          titlePadding: const EdgeInsets.only(top: 12, right: 8),
          contentPadding: const EdgeInsets.all(12),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Chọn từ để luyện tập"),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 460,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Tìm từ...",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // 👉 Wrap hiển thị các từ đã chọn
                if (selectedIds.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedIds.map((id) {
                            final word = availableWords.firstWhere(
                              (w) => w['id'] == id,
                            );
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedIds.remove(id);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    255,
                                    220,
                                    234,
                                    210,
                                  ),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: const Color.fromARGB(
                                      255,
                                      124,
                                      193,
                                      124,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  word['word'],
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 124, 193, 124),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedIds.clear();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text('Bỏ chọn'),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final word = filtered[index];
                      final id = word['id'];
                      return CheckboxListTile(
                        title: Text(word['word']),
                        subtitle: Text(word['meaning']),
                        value: selectedIds.contains(id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedIds.add(id);
                            } else {
                              selectedIds.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 50), () {
                      final selectedWords = availableWords
                          .where((w) => selectedIds.contains(w['id']))
                          .map((word) {
                            final newWord = Map<String, dynamic>.from(word);
                            newWord.remove('isCorrect');
                            newWord.remove('selectedAnswer');
                            newWord.remove('wasHinted');
                            newWord.remove('wrongAttempts');
                            newWord.remove('showHint');
                            newWord.remove('isDone');
                            return newWord;
                          })
                          .toList();

                      onWordsSelected(selectedWords);
                    });
                  },
                  child: const Text('Luyện tập'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void showEditPracticeWordsPopup(
  BuildContext context,
  List<Map<String, dynamic>> practiceWords,
  void Function(List<Map<String, dynamic>>) onWordsRemoved,
) {
  List<String> selectedIds = [];

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          titlePadding: const EdgeInsets.only(top: 12, right: 8, left: 16),
          contentPadding: const EdgeInsets.all(12),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sửa danh sách luyện tập"),
              Row(
                children: [
                  if (selectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedIds.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.grey.shade300,
                      ),
                      child: const Icon(Icons.remove_done, color: Colors.black),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: practiceWords.length,
              itemBuilder: (context, index) {
                final word = practiceWords[index];
                final id = word['id'];
                return CheckboxListTile(
                  value: selectedIds.contains(id),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedIds.add(id);
                      } else {
                        selectedIds.remove(id);
                      }
                    });
                  },
                  title: Text(word['word']),
                  subtitle: Text(word['meaning']),
                );
              },
            ),
          ),
          actions: [
            if (selectedIds.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  final removedWords = practiceWords
                      .where((w) => selectedIds.contains(w['id']))
                      .toList();

                  // 👉 Reset trạng thái giống từ mới
                  final resetWords = removedWords.map((word) {
                    return {
                      ...word,
                      'isCorrect': null,
                      'selectedAnswer': null,
                      'wasHinted': null,
                      'wrongAttempts': null,
                      'showHint': null,
                      'isDone': null,
                    };
                  }).toList();

                  onWordsRemoved(resetWords); // Gửi lại bản reset

                  Navigator.pop(context);
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text("Xóa"),
              ),
          ],
        );
      },
    ),
  );
}
