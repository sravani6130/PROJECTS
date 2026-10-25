import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/app_session_controller.dart';
import '../../profiles/presentation/profile_form.dart';
import 'level_select_screen.dart';
import 'notice_screen.dart';
import 'welcome_screen.dart';

enum OnboardingStep { welcome, notice, profile, level }

/// First-launch journey: language → pretend-money notice → optional profile →
/// level. Onboarding is marked done only at the last step.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  OnboardingStep _step = OnboardingStep.welcome;

  void _go(OnboardingStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == OnboardingStep.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(OnboardingStep.values[_step.index - 1]);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_step) {
          OnboardingStep.welcome => WelcomeScreen(
            key: const ValueKey('welcome'),
            onLanguageChosen: () => _go(OnboardingStep.notice),
          ),
          OnboardingStep.notice => NoticeScreen(
            key: const ValueKey('notice'),
            onAccept: () => _go(OnboardingStep.profile),
            onBack: () => _go(OnboardingStep.welcome),
          ),
          OnboardingStep.profile => ProfileFormScreen(
            key: const ValueKey('profile'),
            showExistingProfiles: true,
            onDone: () => _go(OnboardingStep.level),
            onBack: () => _go(OnboardingStep.notice),
          ),
          OnboardingStep.level => LevelSelectScreen(
            key: const ValueKey('level'),
            onEasy: () =>
                ref.read(appSessionProvider.notifier).completeOnboarding(),
            onBack: () => _go(OnboardingStep.profile),
          ),
        },
      ),
    );
  }
}
