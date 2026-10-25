import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_language.dart';
import '../core/widgets/common.dart';
import '../features/daily/presentation/daily_card.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/ngo/application/ngo_providers.dart';
import '../features/ngo/presentation/ngo_join_screen.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/profiles/application/app_session_controller.dart';
import '../features/profiles/presentation/profile_picker_screen.dart';
import 'providers.dart';
import 'theme.dart';

class GullakApp extends ConsumerWidget {
  const GullakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final t = ref.watch(stringsProvider);
    return MaterialApp(
      title: t('app_name'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Syncs NGO progress at launch and whenever the app returns.
      home: const NgoSyncTrigger(child: RootGate()),
    );
  }
}

/// Chooses the first screen from saved state: onboarding, "who is playing?"
/// on a shared device, or the mission map.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final t = ref.watch(stringsProvider);
    return switch (session) {
      // Each profile is asked once whether it belongs to an NGO.
      AsyncData(:final value)
          when value.readyForHome && !value.activeProfile!.ngoPromptDone =>
        NgoJoinScreen(
          key: ValueKey('ngo_join_${value.activeProfile!.id}'),
          firstRun: true,
        ),
      // Keyed by player, so switching profile checks the new player in.
      AsyncData(:final value) when value.readyForHome => DailyAutoCheckIn(
        key: ValueKey(value.activeProfile!.id),
        child: const HomeScreen(),
      ),
      AsyncData(:final value)
          when value.onboardingDone && value.activeProfile != null =>
        const ProfilePickerScreen(atLaunch: true),
      AsyncData() => const OnboardingFlow(),
      AsyncError() => Scaffold(
        body: MessageView(
          icon: Icons.error_outline,
          message: t('error_generic'),
          action: FilledButton(
            onPressed: () => ref.invalidate(appSessionProvider),
            child: Text(t('try_again')),
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
