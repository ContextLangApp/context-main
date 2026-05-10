class VocabItem {
  final String word;
  final String translation;

  const VocabItem({required this.word, required this.translation});
}

class Article {
  final String id;
  final String topic;
  final String level;
  final String title;
  final int readingTimeMinutes;
  final String body;
  final List<VocabItem> vocabulary;

  const Article({
    required this.id,
    required this.topic,
    required this.level,
    required this.title,
    required this.readingTimeMinutes,
    required this.body,
    required this.vocabulary,
  });
}
