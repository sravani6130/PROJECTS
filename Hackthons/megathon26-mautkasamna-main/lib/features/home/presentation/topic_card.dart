import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common.dart';
import '../../progress/domain/progress_models.dart';

/// Chapter status with icon and text (never colour alone).
Widget chapterStatusPill(
  AppStrings t,
  MissionProgress chapter, {
  required bool locked,
  required bool started,
}) {
  if (chapter.isCompleted) {
    return StatusPill(
      icon: Icons.check_circle,
      label: t('status_completed', {'stars': chapter.bestStars}),
      color: GullakColors.success,
    );
  }
  if (locked) {
    return StatusPill(
      icon: Icons.lock_outline,
      label: t('st_locked_short'),
      color: Colors.grey,
    );
  }
  return started
      ? StatusPill(
          icon: Icons.timelapse,
          label: t('status_in_progress'),
          color: GullakColors.caution,
        )
      : StatusPill(
          icon: Icons.radio_button_unchecked,
          label: t('status_not_started'),
          color: Colors.blueGrey,
        );
}
