class SavedWord {
  final String id;
  final String word;
  final String normalizedWord;
  final String? sourceContext;
  final String? meaning;
  final String? pronunciation;
  final String? exampleSentence;
  final String? realLifeUsage;

  const SavedWord({
    required this.id,
    required this.word,
    required this.normalizedWord,
    this.sourceContext,
    this.meaning,
    this.pronunciation,
    this.exampleSentence,
    this.realLifeUsage,
  });

  factory SavedWord.fromMap(Map<String, dynamic> map) {
    return SavedWord(
      id: map['id'] as String,
      word: (map['word'] as String?) ?? '',
      normalizedWord: (map['normalized_word'] as String?) ?? '',
      sourceContext: map['source_context'] as String?,
      meaning: map['meaning'] as String?,
      pronunciation: map['pronunciation'] as String?,
      exampleSentence: map['example_sentence'] as String?,
      realLifeUsage: map['real_life_usage'] as String?,
    );
  }
}
