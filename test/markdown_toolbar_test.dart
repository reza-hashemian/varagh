import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:varagh/notes/markdown_toolbar.dart';

TextEditingValue value(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

void main() {
  test('bold wraps the selection and unwraps it again', () {
    final wrapped = wrapSelection(value('a word b', 2, 6), '**', '**');
    expect(wrapped.text, 'a **word** b');
    expect(wrapped.selection.textInside(wrapped.text), 'word');
    expect(wrapSelection(wrapped, '**', '**').text, 'a word b');
  });

  test('with nothing selected a placeholder is inserted and selected', () {
    final result = wrapSelection(
      value('ab', 1),
      '*',
      '*',
      placeholder: 'italic',
    );
    expect(result.text, 'a*italic*b');
    expect(result.selection.textInside(result.text), 'italic');
  });

  test('list buttons prefix each selected line and number them', () {
    final text = 'one\ntwo\nthree';
    expect(
      prefixLines(value(text, 1, 6), (_) => '- ').text,
      '- one\n- two\nthree',
    );
    expect(
      prefixLines(value(text, 0, text.length), (n) => '$n. ').text,
      '1. one\n2. two\n3. three',
    );
  });

  test('a prefix toggles off and replaces other markers', () {
    expect(prefixLines(value('- item', 3), (_) => '- ').text, 'item');
    expect(prefixLines(value('- item', 3), (n) => '$n. ').text, '1. item');
    expect(prefixLines(value('## Title', 4), (_) => '# ').text, '# Title');
    expect(prefixLines(value('x', 1), (_) => '- [ ] ').text, '- [ ] x');
  });

  test('a block goes on its own lines', () {
    expect(insertBlock(value('text', 4), '---').text, 'text\n\n---\n\n');
    expect(insertBlock(value('', 0), '---').text, '\n---\n\n');
  });
}
