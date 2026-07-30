import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _urlController = TextEditingController(text: auth.baseUrl);
    _emailController = TextEditingController(text: auth.email);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectEnvironment(ApiEnvironment env) {
    ref.read(authProvider.notifier).selectEnvironment(env);
    _urlController.text = env.baseUrl;
  }

  Future<void> _submit() async {
    final auth = ref.read(authProvider.notifier);
    auth.setBaseUrl(_urlController.text);
    auth.setEmail(_emailController.text);
    await auth.login(_passwordController.text);
  }

  /// A page served over HTTPS cannot call an `http://` API — browsers block
  /// mixed active content and the request fails before it leaves the tab.
  /// Surfacing this inline turns an invisible failure into an obvious one.
  bool get _hasMixedContentProblem {
    if (!kIsWeb) return false;
    if (Uri.base.scheme != 'https') return false;
    return _urlController.text.trim().toLowerCase().startsWith('http://');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final palette = context.palette;
    final selectedEnv = ApiEnvironment.forUrl(auth.baseUrl);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.maxFormWidth),
              child: GlassCard(
                padding: const EdgeInsets.all(28),
                radius: AppTheme.sheetRadius,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Octopus Owner',
                      textAlign: TextAlign.center,
                      style: AppText.appTitle(palette.primaryText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Business Dashboard',
                      textAlign: TextAlign.center,
                      style: AppText.body(palette.dim(0.7)),
                    ),
                    const SizedBox(height: 26),

                    _FieldLabel('Environment', palette: palette),
                    const SizedBox(height: 8),
                    _EnvironmentPicker(
                      selected: selectedEnv,
                      onChanged: _selectEnvironment,
                    ),
                    const SizedBox(height: 18),

                    _FieldLabel('API Base URL', palette: palette),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: AppText.body(palette.primaryText),
                      decoration: const InputDecoration(hintText: 'https://...'),
                      onChanged: (value) {
                        ref.read(authProvider.notifier).setBaseUrl(value);
                        setState(() {}); // refresh the mixed-content notice
                      },
                    ),
                    if (_hasMixedContentProblem) ...[
                      const SizedBox(height: 8),
                      _InlineNotice(
                        icon: Icons.info_outline_rounded,
                        color: palette.warning,
                        message:
                            'This page is served over HTTPS, so the browser will block '
                            'requests to an http:// address. Use the Test environment, '
                            'or open this app over http.',
                      ),
                    ],
                    const SizedBox(height: 18),

                    _FieldLabel('Email', palette: palette),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.username],
                      style: AppText.body(palette.primaryText),
                      decoration: const InputDecoration(hintText: 'Email'),
                      onChanged: ref.read(authProvider.notifier).setEmail,
                    ),
                    const SizedBox(height: 18),

                    _FieldLabel('Password', palette: palette),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      style: AppText.body(palette.primaryText),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: palette.dim(0.6),
                            size: 20,
                          ),
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),

                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppText.caption(
                          palette.negative,
                        ).copyWith(fontSize: 13),
                      ),
                    ],

                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppTheme.onAccent(palette.accent),
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvironmentPicker extends StatelessWidget {
  const _EnvironmentPicker({required this.selected, required this.onChanged});

  final ApiEnvironment selected;
  final ValueChanged<ApiEnvironment> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SegmentedButton<ApiEnvironment>(
      segments: [
        for (final env in ApiEnvironment.values)
          ButtonSegment(value: env, label: Text(env.label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(AppText.style(size: 14, weight: 600)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTheme.onAccent(palette.accent)
              : palette.dim(0.75),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : Colors.transparent,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: palette.primaryText.withValues(alpha: 0.18)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.palette});

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.caption(palette.dim(0.8)).weighted(600));
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: AppText.caption(color))),
      ],
    );
  }
}
