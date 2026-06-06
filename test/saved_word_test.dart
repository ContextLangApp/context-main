import 'package:context/models/saved_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedWord.fromMap', () {
    test('maps all columns', () {
      final word = SavedWord.fromMap({
        'id': 'abc',
        'word': 'der Tisch',
        'normalized_word': 'tisch',
        'source_context': 'Der Tisch ist groß.',
        'meaning': 'the table',
        'pronunciation': 'der TISH',
        'example_sentence': 'Der Tisch ist neu.',
        'real_life_usage': 'Used when talking about furniture.',
      });

      expect(word.id, 'abc');
      expect(word.word, 'der Tisch');
      expect(word.normalizedWord, 'tisch');
      expect(word.sourceContext, 'Der Tisch ist groß.');
      expect(word.meaning, 'the table');
      expect(word.pronunciation, 'der TISH');
      expect(word.exampleSentence, 'Der Tisch ist neu.');
      expect(word.realLifeUsage, 'Used when talking about furniture.');
    });

    test('defaults missing word fields and leaves optionals null', () {
      final word = SavedWord.fromMap({'id': 'x'});

      expect(word.id, 'x');
      expect(word.word, '');
      expect(word.normalizedWord, '');
      expect(word.sourceContext, isNull);
      expect(word.meaning, isNull);
      expect(word.pronunciation, isNull);
      expect(word.exampleSentence, isNull);
      expect(word.realLifeUsage, isNull);
    });
  });
}
