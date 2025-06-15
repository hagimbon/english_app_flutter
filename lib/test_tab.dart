import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'add_word_screen.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'services/load_service.dart';
import 'package:english_app/services/load_service.dart';

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
  final ValueNotifier<List<Map<String, dynamic>>> wordsNotifier;
  final ValueNotifier<List<Map<String, dynamic>>> unlearnedNotifier;

  const TestTab({
    super.key,
    required this.wordsNotifier,
    required this.unlearnedNotifier,
  });

  @override
  State<TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<TestTab> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 1);

    Future.delayed(Duration.zero, () async {
      final unlearned = await LoadService.loadUnlearnedWords();
      final learned = await LoadService.loadLearnedWords();

      if (!mounted) return;

      widget.unlearnedNotifier.value = unlearned;
      widget.wordsNotifier.value = learned;
    });
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
          // 🟡 Dùng ValueListenableBuilder để theo dõi thay đổi danh sách
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: widget.wordsNotifier,
            builder: (context, words, _) {
              if (words.isEmpty) {
                return const Center(
                  child: Text(
                    'Không có từ để luyện tập',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                );
              } else {
                return FlashcardScreen(words: words);
              }
            },
          ),

          // 🟡 Box luyện tập
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: widget.unlearnedNotifier,
            builder: (context, unlearnedWords, _) {
              return PracticeBoxes(
                words: widget.wordsNotifier.value,
                unlearnedWords: unlearnedWords,
              );
            },
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

class PracticeBoxes extends StatelessWidget {
  final List<Map<String, dynamic>> words;
  final List<Map<String, dynamic>> unlearnedWords;
  const PracticeBoxes({
    super.key,
    required this.words,
    required this.unlearnedWords,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildBox(context, 'Từ mới'),
                const SizedBox(width: 8),
                _buildBox(context, 'Từ đã học'), // 👈 đổi vị trí vào giữa
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

  Widget _buildBox(BuildContext ctx, String title) {
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
                    title, // ✅ dùng title truyền vào thay vì fix cứng 'Từ mới'
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text('${unlearnedWords.length}'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: unlearnedWords.length,
                  itemBuilder: (context, index) {
                    final word = unlearnedWords[index];
                    return _WordChoiceTile(
                      word: word,
                      allWords: unlearnedWords,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ); // ✅ phải là dấu chấm phẩy
  }
}

class _WordChoiceTile extends StatefulWidget {
  final Map<String, dynamic> word;
  final List<Map<String, dynamic>> allWords;

  const _WordChoiceTile({required this.word, required this.allWords});

  @override
  State<_WordChoiceTile> createState() => _WordChoiceTileState();
}

class _WordChoiceTileState extends State<_WordChoiceTile> {
  String? selected;
  bool? isCorrect;
  List<String> options = [];

  @override
  void initState() {
    super.initState();
    generateOptions();
  }

  void generateOptions() {
    options = [widget.word['meaning']];
    final otherWords = widget.allWords.where((w) => w != widget.word).toList();
    otherWords.shuffle();
    for (var i = 0; i < 5 && i < otherWords.length; i++) {
      options.add(otherWords[i]['meaning']);
    }
    options.shuffle();
  }

  void onSelect(String? value) {
    setState(() {
      selected = value;
      isCorrect = (value == widget.word['meaning']);

      if (!isCorrect!) {
        Future.delayed(const Duration(seconds: 1), () {
          setState(() {
            selected = null;
            isCorrect = null;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isCorrect == true
          ? Colors.green.shade200
          : isCorrect == false
          ? Colors.red.shade200
          : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.word['word'], style: const TextStyle(fontSize: 20)),
            if (selected == null)
              DropdownButton<String>(
                hint: const Text("Chọn nghĩa"),
                items: options
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: onSelect,
              ),
            if (selected != null && isCorrect == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('🇻🇳 ${widget.word['meaning']}'),
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

class FlashcardScreenState extends State<FlashcardScreen> {
  bool isLoading = true;
  int currentIndex = 0;
  Timer? _timer;
  bool isCorrect = false;
  bool isWrong = false;
  bool isTimeOut = false;
  int timeLeft = 15;
  late List<String> options;
  late String correctAnswer;
  ImageProvider? firstImage;

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

class _FlashCardQuizBoxState extends State<FlashCardQuizBox> {
  bool isLoading = true; // ✅ Khai báo biến isLoading
  int currentIndex = 0;
  String? selected;
  bool? isCorrect;
  int wrongCount = 0;
  bool showHint = false;
  bool showExamples = false;
  bool isFinished = false;
  MemoryImage? firstImage; // ✅ khai báo biến ảnh đầu tiên
  List<Map<String, dynamic>> flashWords = [];
  List<String> choices = [];

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      flashWords = widget.unlearnedWords
          .where(
            (w) =>
                w['imageBytes'] != null && (w['imageBytes'] as List).isNotEmpty,
          )
          .toList();

      flashWords.shuffle();

      if (flashWords.isNotEmpty) {
        firstImage = MemoryImage(
          Uint8List.fromList(List<int>.from(flashWords[0]['imageBytes'])),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          preloadRemainingImages();
        });

        prepareChoices();
      }

      // ✅ Bỏ trạng thái loading sau khi xử lý xong
      setState(() {
        isLoading = false;
      });
    });
  }

  void preloadRemainingImages() async {
    for (int i = 1; i < flashWords.length; i++) {
      final bytes = flashWords[i]['imageBytes'];
      if (bytes != null) {
        final image = MemoryImage(Uint8List.fromList(List<int>.from(bytes)));

        if (!mounted) return; // ✅ Thêm dòng này trước khi dùng context
        await precacheImage(image, context);

        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
        wrongCount++;
        if (wrongCount >= 3) showHint = true;
      } else {
        Future.delayed(const Duration(seconds: 1), nextCard);
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
