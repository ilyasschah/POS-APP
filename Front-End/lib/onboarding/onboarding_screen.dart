import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:pos_app/onboarding/widgets/activity_slide.dart';
import 'package:pos_app/onboarding/widgets/features_slide.dart';
import 'package:pos_app/onboarding/widgets/layout_slide.dart';
import 'package:pos_app/onboarding/widgets/onboarding_controls.dart';
import 'package:pos_app/onboarding/widgets/quick_start_slide.dart';
import 'package:pos_app/onboarding/widgets/setup_slide.dart';
import 'package:pos_app/onboarding/widgets/welcome_slide.dart';

/// First-run flow: welcome → feature tour → theme setup → Get Started.
///
/// Completing (or skipping) always flips [onboardingCompleteProvider]. What
/// happens next depends on how this screen was reached, which is why the
/// handoff is injected rather than hardcoded:
///
///  - **As `MyApp`'s `home`** (already-registered device that has never been
///    onboarded): pass nothing. Flipping the provider rebuilds `MyApp` straight
///    past this screen, and calling Navigator here would fight that.
///  - **Pushed by `MasterLoginScreen`** (the first-install path): there is no
///    `home` rebuild to fall back on, so it passes an [onFinished] that
///    replaces this route with the PIN screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  /// Invoked once onboarding has been marked complete. Null means "nothing to
  /// do" — see the class docs.
  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <Widget>[
    WelcomeSlide(),
    FeaturesSlide(),
    QuickStartSlide(),
    SetupSlide(),
    LayoutSlide(),
    ActivitySlide(),
  ];

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompleteProvider.notifier).complete();
    if (!mounted) return;
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // On the first page, let Android back exit the app; after that, back
        // steps to the previous slide instead of leaving onboarding.
        child: PopScope(
          canPop: _page == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Column(
            children: [
              // Skip — hidden on the last page (Get Started is the action there).
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _isLast
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton(
                            onPressed: _finish,
                            child: Text(
                                AppLocalizations.of(context).actionSkip),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: _pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: OnboardingControls(
                  pageCount: _pages.length,
                  currentPage: _page,
                  onBack: _page == 0 ? null : _back,
                  onNext: _next,
                  isLastPage: _isLast,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
