import 'package:flutter/material.dart';
import 'add_word_screen.dart';

class LearnedWordsTab extends StatelessWidget {
  final List<Map<String, dynamic>> words;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const LearnedWordsTab({
    super.key,
    required this.words,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return ListTile(
          title: Text(word['word']),
          subtitle: Text(word['meaning']),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddWordScreen(
                        existingWords: words,
                        initialData: word,
                      ),
                    ),
                  );
                  if (updated != null) onEdit({...word, ...updated});
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onDelete(word),
              ),
            ],
          ),
        );
      },
    );
  }
}
