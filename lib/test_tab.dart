import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'add_word_screen.dart';

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

  const TestTab({super.key, required this.words, required this.unlearnedWords});

  @override
  State<TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<TestTab> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 1); // 👉 hiển thị màn 2
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
          FlashcardScreen(words: widget.words), // Box 1: Flash Card
          PracticeBoxes(
            words: widget.words,
            unlearnedWords: widget.unlearnedWords,
          ), // Box 2: 3 Boxes
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
  const PracticeBoxes({required this.words, required this.unlearnedWords});

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
                _buildBox(context, 'Từ chưa học'),
                const SizedBox(width: 8),
                _buildBox(context, 'Từ đã học'),
              ],
            ),
          ),
        ],
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
