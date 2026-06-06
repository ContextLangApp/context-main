import 'package:flutter/material.dart';

import '../services/vocabulary_service.dart';

/// Drop-in replacement for a [Text] showing German content. Long-pressing a
/// word adds a "Save to Dictionary" action to the text-selection toolbar that
/// enriches and saves the single selected word.
class VocabularySelectableText extends StatefulWidget {
  const VocabularySelectableText(
    this.text, {
    super.key,
    this.style,
    this.sourceContext,
  });

  final String text;
  final TextStyle? style;

  /// Surrounding text passed to enrichment for disambiguation. Defaults to
  /// the full [text] when null.
  final String? sourceContext;

  @override
  State<VocabularySelectableText> createState() =>
      _VocabularySelectableTextState();
}

class _VocabularySelectableTextState extends State<VocabularySelectableText> {
  final VocabularyService _service = VocabularyService();
  bool _saving = false;

  Future<void> _save(String word) async {
    if (_saving) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Saving "$word"…')),
    );

    final result = await _service.saveVocabulary(
      word,
      widget.sourceContext ?? widget.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    final message = switch (result.status) {
      SaveStatus.saved =>
        'Added to Dictionary. You can practice this word in the Practice tab.',
      SaveStatus.alreadySaved => 'This word is already in your Dictionary.',
      SaveStatus.error =>
        result.message ?? "Couldn't save the word. Please try again.",
    };

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      widget.text,
      style: widget.style,
      contextMenuBuilder: (context, editableTextState) {
        final value = editableTextState.textEditingValue;
        final selected = value.selection.textInside(value.text).trim();
        final isSingleWord =
            selected.isNotEmpty && !RegExp(r'\s').hasMatch(selected);

        final items = List<ContextMenuButtonItem>.of(
          editableTextState.contextMenuButtonItems,
        );

        if (isSingleWord && !_saving) {
          items.insert(
            0,
            ContextMenuButtonItem(
              label: 'Save to Dictionary',
              onPressed: () {
                editableTextState.hideToolbar();
                _save(selected);
              },
            ),
          );
        }

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
  }
}
