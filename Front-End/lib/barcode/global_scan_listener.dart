import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/barcode/scan_bus.dart';

/// Catches keyboard-wedge scans anywhere in the app.
///
/// 🚨 Why this exists: until now a scan only reached the till if the product
/// search field happened to be RENDERED and FOCUSED. That made three ordinary
/// situations lose the sale — the cashier had not tapped the search box, the
/// company had turned the search bar off (`Products.ShowSearchBtn = false`), or
/// focus was sitting in some other field where the scan silently typed itself
/// into a quantity. A scanner is a device the operator points at a product, not
/// a text field they have to prepare first.
///
/// **How a scan is told apart from typing:** a wedge emits its characters in a
/// burst — tens of milliseconds apart — and terminates with Enter. Anything
/// slower than [_maxGap] between two characters starts a new buffer, so human
/// typing can never accumulate into a scan.
///
/// **What it never does:** it does not touch input that belongs to a text
/// field. If an [EditableText] holds focus the buffer is dropped and the keys
/// go where the operator is looking — stealing keystrokes out from under
/// someone mid-word would be a far worse bug than the one this fixes. It also
/// never CONSUMES a key event (the handler always returns false); it only
/// watches.
class GlobalScanListener extends ConsumerStatefulWidget {
  const GlobalScanListener({super.key});

  @override
  ConsumerState<GlobalScanListener> createState() =>
      _GlobalScanListenerState();
}

class _GlobalScanListenerState extends ConsumerState<GlobalScanListener> {
  /// Longest pause between two characters that still counts as one burst.
  /// A wedge is 5–30 ms per character; a fast human is 100 ms+ and is checked
  /// for anyway (see [_editableHasFocus]).
  static const _maxGap = Duration(milliseconds: 120);

  /// Shorter than this and it is a stray keypress, not a barcode.
  static const _minLength = 4;

  /// No symbology reaches this. A longer run means something is holding a key
  /// down, and the buffer would otherwise grow without bound.
  static const _maxLength = 64;

  final _buffer = StringBuffer();
  DateTime? _lastKey;

  /// Decided once per burst rather than per character: walking the element tree
  /// on every keystroke of a 13-character scan is waste, and focus does not
  /// move mid-burst.
  bool _burstIgnored = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _reset() {
    _buffer.clear();
    _lastKey = null;
    _burstIgnored = false;
  }

  /// True when the keystroke belongs to a text field the operator is using.
  ///
  /// The focused node is attached by the `Focus` widget that `EditableText`
  /// builds, so the EditableText itself is an ANCESTOR of that context — which
  /// is why this looks upwards rather than at the widget directly.
  bool _editableHasFocus() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    // Always observe, never consume: whatever this decides, the app's own
    // shortcuts and fields must behave exactly as they did before.
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final last = _lastKey;
    final startsBurst = last == null || now.difference(last) > _maxGap;
    if (startsBurst) {
      _buffer.clear();
      // One focus check per burst.
      _burstIgnored = _editableHasFocus();
    }
    _lastKey = now;

    if (_burstIgnored) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString();
      _reset();
      if (code.length >= _minLength) {
        ref.read(scanBusProvider).emit(code, source: ScanSource.hardware);
      }
      return false;
    }

    final char = event.character;
    // Modifiers, arrows and function keys carry no character — they are not
    // part of a barcode, and a scanner never sends them mid-code.
    if (char == null || char.length != 1 || char.codeUnitAt(0) < 0x20) {
      return false;
    }

    _buffer.write(char);
    if (_buffer.length > _maxLength) _reset();
    return false;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
