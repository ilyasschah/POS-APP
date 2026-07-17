// Verifies the virtual keyboard's TextInputControl routing: once registered and
// a field is focused, insert / backspace / cursor-move operations must edit the
// currently focused TextField's value in place. This exercises the whole chain
// (attach → show → setEditingState → updateEditingValue → client update) that
// the real POS relies on, without touching the platform.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/pos_virtual_keyboard.dart';

void main() {
  Future<(VirtualKeyboardController, TextEditingController)> boot(
    WidgetTester tester,
  ) async {
    final keyboard = VirtualKeyboardController();
    addTearDown(keyboard.dispose);
    keyboard.register();

    final text = TextEditingController();
    addTearDown(text.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: text, focusNode: focus),
        ),
      ),
    );

    focus.requestFocus();
    await tester.pump();
    return (keyboard, text);
  }

  testWidgets('shows when a field is focused', (tester) async {
    final (keyboard, _) = await boot(tester);
    expect(keyboard.isVisible, isTrue);
  });

  testWidgets('insert routes typed glyphs into the focused field', (
    tester,
  ) async {
    final (keyboard, text) = await boot(tester);
    keyboard.insertText('H');
    keyboard.insertText('i');
    await tester.pump();
    expect(text.text, 'Hi');
    expect(text.selection.baseOffset, 2);
  });

  testWidgets('backspace deletes the glyph before the caret', (tester) async {
    final (keyboard, text) = await boot(tester);
    for (final ch in 'abc'.split('')) {
      keyboard.insertText(ch);
    }
    keyboard.backspace();
    await tester.pump();
    expect(text.text, 'ab');
  });

  testWidgets('cursor move + insert edits mid-string', (tester) async {
    final (keyboard, text) = await boot(tester);
    keyboard.insertText('a');
    keyboard.insertText('b');
    keyboard.moveCursor(-1); // caret now between a and b
    keyboard.insertText('X');
    await tester.pump();
    expect(text.text, 'aXb');
  });

  testWidgets('hideKeyboard drops focus and lowers the keyboard', (
    tester,
  ) async {
    final (keyboard, _) = await boot(tester);
    expect(keyboard.isVisible, isTrue);
    keyboard.hideKeyboard();
    await tester.pump();
    expect(keyboard.isVisible, isFalse);
  });

  testWidgets('backspace keeps a surrogate pair (emoji) intact', (
    tester,
  ) async {
    final (keyboard, text) = await boot(tester);
    keyboard.insertText('a');
    keyboard.insertText('😀'); // 2 UTF-16 code units
    keyboard.backspace(); // must remove the whole emoji, not half of it
    await tester.pump();
    expect(text.text, 'a');
  });
}
