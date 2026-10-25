import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../game/game_style.dart';
import '../game/game_widgets.dart';
import '../game/scenes.dart';

/// Standard game page: illustrated backdrop, cartoon HUD (back, title,
/// actions), content on an outlined panel and an optional pinned action area,
/// so the main action is always in the same place.
class GullakScaffold extends StatelessWidget {
  const GullakScaffold({
    super.key,
    this.title,
    required this.body,
    this.bottom,
    this.actions,
    this.scrollable = true,
    this.showBack = true,
    this.onBack,
    this.scene = SceneKind.city,
    this.panel = true,
    this.header,
  });

  final String? title;
  final Widget body;
  final Widget? bottom;

  /// Icon buttons for the HUD; each is drawn as a round cartoon button.
  final List<Widget>? actions;
  final bool scrollable;
  final bool showBack;

  /// Custom back action for screens that are not separate routes.
  final VoidCallback? onBack;
  final SceneKind scene;

  /// When false, [body] sits directly on the scene (for stage-like screens).
  final bool panel;

  /// Optional illustration shown on the scene above the panel.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final canPop =
        onBack != null || (showBack && Navigator.of(context).canPop());
    final content = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.md),
            child: body,
          )
        : Padding(padding: const EdgeInsets.all(Gap.md), child: body);

    return Scaffold(
      backgroundColor: Toon.cream,
      body: SceneBackground(
        scene: scene,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
                child: Row(
                  children: [
                    if (canPop) ...[
                      RoundGameButton(back: true, onPressed: onBack),
                      const SizedBox(width: Gap.sm),
                    ],
                    if (title != null)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: toonPanel(
                              color: Toon.cream,
                              radius: 16,
                              shadow: 3,
                            ),
                            child: Text(
                              title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: toonTitle(context, size: 19),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    for (final action in actions ?? const <Widget>[])
                      Padding(
                        padding: const EdgeInsets.only(left: Gap.sm),
                        child: Container(
                          decoration: toonPanel(radius: 24, shadow: 3),
                          child: action,
                        ),
                      ),
                  ],
                ),
              ),
              ?header,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
                  child: panel
                      ? DecoratedBox(
                          decoration: toonPanel(color: Toon.cream),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: content,
                          ),
                        )
                      : content,
                ),
              ),
              if (bottom != null)
                Padding(padding: const EdgeInsets.all(Gap.md), child: bottom)
              else
                const SizedBox(height: Gap.md),
            ],
          ),
        ),
      ),
    );
  }
}
