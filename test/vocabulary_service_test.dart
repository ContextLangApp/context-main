import 'package:context/services/vocabulary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VocabularyService.normalize', () {
    test('lowercases and trims surrounding whitespace', () {
      expect(VocabularyService.normalize('  Tisch  '), 'tisch');
    });

    test('strips surrounding punctuation and quotes', () {
      expect(VocabularyService.normalize('Hund,'), 'hund');
      expect(VocabularyService.normalize('„Haus"'), 'haus');
      expect(VocabularyService.normalize('groß.'), 'groß');
    });

    test('preserves German umlauts and ß', () {
      expect(VocabularyService.normalize('Straße'), 'straße');
      expect(VocabularyService.normalize('Äpfel'), 'äpfel');
    });

    test('returns empty string for punctuation-only input', () {
      expect(VocabularyService.normalize('...'), '');
      expect(VocabularyService.normalize('   '), '');
    });

    test('keeps internal whitespace (multi-word rejected upstream)', () {
      expect(VocabularyService.normalize('foo bar'), 'foo bar');
    });
  });
}
