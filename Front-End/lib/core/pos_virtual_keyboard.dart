import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';

/// On-screen keyboard for the touch POS terminal.
///
/// Routing is built on Flutter's [TextInputControl] (the same hook the platform
/// soft-keyboard uses), so key presses edit *whatever* [TextField] currently
/// holds the input connection — no per-field controller wiring. The control is
/// only registered while [SettingKeys.enableVirtualKeyboard] is on, so with the
/// setting off the native keyboard behaves exactly as before.
///
/// Mount [VirtualKeyboardHost] once, around the whole app (see `main.dart`'s
/// `MaterialApp.builder`).

// ─────────────────────────────────────────────────────────────────────────────
// Controller — the input-routing brain
// ─────────────────────────────────────────────────────────────────────────────

/// Single app-wide keyboard controller. Owns the [TextInputControl] connection
/// and exposes [isVisible] so the host can animate. Created by
/// [virtualKeyboardControllerProvider]; never instantiate it directly.
class VirtualKeyboardController extends ChangeNotifier with TextInputControl {
  bool _registered = false;
  bool _visible = false;

  TextInputClient? _client;
  TextEditingValue _editingState = TextEditingValue.empty;
  bool _multiline = false;
  TextInputAction _inputAction = TextInputAction.done;

  /// True while a text field is being edited (input connection shown) and the
  /// keyboard should be on screen.
  bool get isVisible => _visible;

  /// Takes over text input from the platform control. Idempotent. Called by the
  /// host when the virtual-keyboard setting turns on.
  void register() {
    if (_registered) return;
    TextInput.setInputControl(this);
    FocusManager.instance.addListener(_onFocusChanged);
    _registered = true;
  }

  /// Hands input back to the platform control (restoring the native keyboard on
  /// Android). Idempotent. Called when the setting turns off, and on dispose.
  void unregister() {
    if (!_registered) return;
    FocusManager.instance.removeListener(_onFocusChanged);
    TextInput.restorePlatformInputControl();
    _registered = false;
    _setVisible(false);
  }

  // ── TextInputControl overrides ──────────────────────────────────────────────

  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    _client = client;
    _applyConfig(configuration);
  }

  @override
  void detach(TextInputClient client) {
    if (identical(client, _client)) {
      _client = null;
      _setVisible(false);
    }
  }

  @override
  void updateConfig(TextInputConfiguration configuration) =>
      _applyConfig(configuration);

  @override
  void show() => _setVisible(true);

  @override
  void hide() => _setVisible(false);

  @override
  void setEditingState(TextEditingValue value) => _editingState = value;

  // ── Editing operations (called by the keys) ─────────────────────────────────

  /// Replaces the current selection with [text] (a single glyph, in practice)
  /// and places the caret after it.
  void insertText(String text) {
    if (text.isEmpty) return;
    final value = _normalized(_editingState);
    final sel = value.selection;
    final newText = value.text.replaceRange(sel.start, sel.end, text);
    _apply(value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
      composing: TextRange.empty,
    ));
  }

  /// Deletes the selection, or the glyph before the caret when collapsed.
  void backspace() {
    final value = _normalized(_editingState);
    final sel = value.selection;
    if (sel.isCollapsed) {
      if (sel.start == 0) return;
      final start = _prevBoundary(value.text, sel.start);
      _apply(value.copyWith(
        text: value.text.replaceRange(start, sel.start, ''),
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      ));
    } else {
      _apply(value.copyWith(
        text: value.text.replaceRange(sel.start, sel.end, ''),
        selection: TextSelection.collapsed(offset: sel.start),
        composing: TextRange.empty,
      ));
    }
  }

  /// Moves the caret one glyph left ([delta] < 0) or right ([delta] > 0),
  /// collapsing any existing selection toward that side first.
  void moveCursor(int delta) {
    final value = _normalized(_editingState);
    final sel = value.selection;
    int offset;
    if (!sel.isCollapsed) {
      offset = delta < 0 ? sel.start : sel.end;
    } else if (delta < 0) {
      offset = _prevBoundary(value.text, sel.baseOffset);
    } else {
      offset = _nextBoundary(value.text, sel.baseOffset);
    }
    _apply(value.copyWith(selection: TextSelection.collapsed(offset: offset)));
  }

  /// Enter/Return: a newline in a multiline field, otherwise the field's own
  /// submit action (search / done / next …).
  void submit() {
    if (_multiline) {
      insertText('\n');
    } else {
      _client?.performAction(_inputAction);
    }
  }

  /// Advances focus to the next / previous field in the traversal order.
  void focusNext() => FocusManager.instance.primaryFocus?.nextFocus();
  void focusPrevious() => FocusManager.instance.primaryFocus?.previousFocus();

  /// Dismisses the keyboard by dropping focus — the input connection then emits
  /// [hide], which lowers the keyboard.
  void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  // ── Internals ───────────────────────────────────────────────────────────────

  void _applyConfig(TextInputConfiguration configuration) {
    _multiline = configuration.inputType == TextInputType.multiline;
    _inputAction = configuration.inputAction;
  }

  void _onFocusChanged() {
    // Safety net for the explicit "listen to primaryFocus" contract: if focus is
    // cleared entirely (tap on empty space, programmatic unfocus) the connection
    // usually emits hide() — but if it doesn't, drop the keyboard anyway. Field
    // → field moves keep primaryFocus non-null, so this never flickers.
    if (FocusManager.instance.primaryFocus == null) _setVisible(false);
  }

  void _apply(TextEditingValue value) {
    _editingState = value;
    TextInput.updateEditingValue(value);
  }

  /// Guarantees a valid caret — a field that was never touched reports an
  /// invalid selection (offset -1); treat that as the end of the text.
  TextEditingValue _normalized(TextEditingValue value) {
    if (value.selection.isValid) return value;
    return value.copyWith(
      selection: TextSelection.collapsed(offset: value.text.length),
    );
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    unregister();
    super.dispose();
  }

  static bool _isHigh(int c) => c >= 0xD800 && c <= 0xDBFF;
  static bool _isLow(int c) => c >= 0xDC00 && c <= 0xDFFF;

  /// UTF-16-aware previous boundary (keeps surrogate pairs / emoji intact).
  static int _prevBoundary(String text, int index) {
    if (index <= 1) return math.max(0, index - 1);
    final prev = index - 1;
    if (_isLow(text.codeUnitAt(prev)) && _isHigh(text.codeUnitAt(prev - 1))) {
      return prev - 1;
    }
    return prev;
  }

  static int _nextBoundary(String text, int index) {
    if (index >= text.length) return text.length;
    final next = index + 1;
    if (next < text.length &&
        _isHigh(text.codeUnitAt(index)) &&
        _isLow(text.codeUnitAt(next))) {
      return next + 1;
    }
    return next;
  }
}

/// App-wide singleton keyboard controller.
final virtualKeyboardControllerProvider =
    Provider<VirtualKeyboardController>((ref) {
  final controller = VirtualKeyboardController();
  ref.onDispose(controller.dispose);
  return controller;
});

// ─────────────────────────────────────────────────────────────────────────────
// Host — registration, slide animation, and content inset
// ─────────────────────────────────────────────────────────────────────────────

/// Wrap the app with this once. It (de)registers the input control in step with
/// [SettingKeys.enableVirtualKeyboard], slides the keyboard up from the bottom
/// when a field is focused, and pushes app content up by the keyboard's height
/// (via `viewInsets`, the same channel `Scaffold` already honours) so the
/// focused field is never hidden.
class VirtualKeyboardHost extends ConsumerStatefulWidget {
  const VirtualKeyboardHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VirtualKeyboardHost> createState() =>
      _VirtualKeyboardHostState();
}

class _VirtualKeyboardHostState extends ConsumerState<VirtualKeyboardHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final VirtualKeyboardController _kbd;
  late final Animation<double> _curve;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _kbd = ref.read(virtualKeyboardControllerProvider);
    _kbd.addListener(_onVisibilityChanged);
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    if (_kbd.isVisible && _enabled) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  @override
  void dispose() {
    _kbd.removeListener(_onVisibilityChanged);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // React to the setting. Registering only while enabled means a disabled
    // keyboard never intercepts the platform input control (native keyboard
    // keeps working on Android).
    final enabled = ref.watch(
      appSettingsProvider.select(
        (s) =>
            (s[SettingKeys.enableVirtualKeyboard] ?? 'false').toLowerCase() ==
            'true',
      ),
    );
    if (enabled != _enabled) {
      _enabled = enabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (enabled) {
          _kbd.register();
        } else {
          _kbd.unregister();
          _anim.reverse();
        }
      });
    }

    final media = MediaQuery.of(context);
    final keyboardHeight = _keyboardHeight(media.size);

    return Stack(
      children: [
        // Inset the app content by the currently-visible slice of the keyboard.
        // `widget.child` is passed by reference, so only MediaQuery dependents
        // (Scaffolds) relayout per frame — the app subtree is not rebuilt.
        AnimatedBuilder(
          animation: _curve,
          builder: (context, _) {
            final inset = keyboardHeight * _curve.value;
            return MediaQuery(
              data: media.copyWith(
                viewInsets: media.viewInsets.copyWith(
                  bottom: math.max(media.viewInsets.bottom, inset),
                ),
              ),
              child: widget.child,
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              if (_curve.value == 0) return const SizedBox.shrink();
              return FractionalTranslation(
                translation: Offset(0, 1 - _curve.value),
                child: child,
              );
            },
            child: _KeyboardShell(height: keyboardHeight, controller: _kbd),
          ),
        ),
      ],
    );
  }

  /// A comfortable touch height that scales with the screen but never dominates
  /// a short landscape tablet or grows silly on a large monitor.
  double _keyboardHeight(Size size) =>
      (size.height * 0.42).clamp(220.0, 360.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout + keycaps
// ─────────────────────────────────────────────────────────────────────────────

class _KeyboardShell extends StatelessWidget {
  const _KeyboardShell({required this.height, required this.controller});

  final double height;
  final VirtualKeyboardController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // TextFieldTapRegion marks the whole keyboard as part of the focused field's
    // tap group, so tapping a key does NOT fire TextField's tap-outside unfocus
    // (which would close the connection out from under us).
    return TextFieldTapRegion(
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Material(
          color: cs.surface,
          elevation: 8,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: _KeyboardBody(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardBody extends StatefulWidget {
  const _KeyboardBody({required this.controller});

  final VirtualKeyboardController controller;

  @override
  State<_KeyboardBody> createState() => _KeyboardBodyState();
}

class _KeyboardBodyState extends State<_KeyboardBody> {
  bool _symbols = false;
  bool _shift = false;

  VirtualKeyboardController get _c => widget.controller;

  void _toggleShift() => setState(() => _shift = !_shift);
  void _toggleSymbols() => setState(() => _symbols = !_symbols);

  /// A character key. Letters honour the current shift/caps state; everything
  /// else is inserted verbatim.
  _KeyModel _char(String ch) {
    final isLetter = ch.length == 1 && RegExp('[a-z]').hasMatch(ch);
    final out = _shift && isLetter ? ch.toUpperCase() : ch;
    return _KeyModel(label: out, onTap: () => _c.insertText(out));
  }

  List<List<_KeyModel>> _buildRows() {
    final backspace = _KeyModel(
      icon: Icons.backspace_outlined,
      flex: 3,
      onTap: _c.backspace,
    );
    final enter = _KeyModel(
      icon: Icons.keyboard_return,
      flex: 3,
      emphasize: true,
      onTap: _c.submit,
    );
    final shift = _KeyModel(
      icon: Icons.arrow_upward,
      flex: 3,
      active: _shift,
      onTap: _toggleShift,
    );

    // Row 4 is shared between both modes except the mode-toggle and its adjacent
    // punctuation key.
    List<_KeyModel> bottomRow(_KeyModel modeToggle, _KeyModel punctuation) => [
      _KeyModel(icon: Icons.keyboard_arrow_down, flex: 3, onTap: _c.hideKeyboard),
      modeToggle,
      punctuation,
      _KeyModel(icon: Icons.space_bar, flex: 12, onTap: () => _c.insertText(' ')),
      _KeyModel(label: 'prev', flex: 3, onTap: _c.focusPrevious),
      _KeyModel(label: 'next', flex: 3, onTap: _c.focusNext),
      _KeyModel(icon: Icons.chevron_left, onTap: () => _c.moveCursor(-1)),
      _KeyModel(icon: Icons.chevron_right, onTap: () => _c.moveCursor(1)),
    ];

    if (_symbols) {
      final toAbc = _KeyModel(
        label: 'ABC',
        flex: 3,
        emphasize: true,
        onTap: _toggleSymbols,
      );
      return [
        [...'1234567890'.split('').map(_char), backspace],
        [...r'!@#/^&*()"'.split('').map(_char), enter],
        [shift, ...r'-_[]|<>+=~'.split('').map(_char), shift],
        bottomRow(toAbc, _char('.')),
      ];
    }

    final toSymbols = _KeyModel(
      label: '&123',
      flex: 3,
      emphasize: true,
      onTap: _toggleSymbols,
    );
    return [
      [...'qwertyuiop'.split('').map(_char), backspace],
      [...'asdfghjkl'.split('').map(_char), _char("'"), enter],
      [shift, ...'zxcvbnm,.?'.split('').map(_char), shift],
      bottomRow(toSymbols, _char('@')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return Column(
      children: [
        for (final row in rows)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final key in row) _Key(key)],
            ),
          ),
      ],
    );
  }
}

/// One keycap. Flat surface, hairline [ColorScheme.outlineVariant] border,
/// tinted when it is a mode/enter key or an engaged shift.
class _Key extends StatelessWidget {
  const _Key(this.model);

  final _KeyModel model;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    if (model.active) {
      background = cs.primary;
      foreground = cs.onPrimary;
    } else if (model.emphasize) {
      background = cs.surfaceContainerHighest;
      foreground = cs.onSurface;
    } else {
      background = cs.surface;
      foreground = cs.onSurface;
    }

    return Expanded(
      flex: model.flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            canRequestFocus: false,
            onTap: model.onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant, width: 0.5),
              ),
              child: Center(
                child: model.icon != null
                    ? Icon(model.icon, size: 20, color: foreground)
                    : Text(
                        model.label ?? '',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Declarative spec for a keycap. Exactly one of [label] / [icon] is set.
class _KeyModel {
  const _KeyModel({
    this.label,
    this.icon,
    this.flex = 2,
    this.emphasize = false,
    this.active = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;

  /// Relative width within its row (space bar is widest; modifiers are wider
  /// than character keys).
  final int flex;

  /// Tinted surface — the mode-toggle and Enter keys.
  final bool emphasize;

  /// Filled with the primary colour — an engaged Shift.
  final bool active;

  final VoidCallback onTap;
}
