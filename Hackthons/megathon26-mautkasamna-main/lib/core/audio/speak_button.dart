import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../game/game_style.dart';
import 'narrator.dart';

/// Speaker button that reads [text] aloud; tap again to stop. With
/// [autoPlay] it also reads the text as soon as it appears (and again when
/// the text changes). Shows nothing when reading aloud is off.
class SpeakButton extends ConsumerStatefulWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.autoPlay = false,
    this.size = 36,
  });

  final String text;
  final bool autoPlay;
  final double size;

  @override
  ConsumerState<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends ConsumerState<SpeakButton> {
  late final Narrator _narrator;

  @override
  void initState() {
    super.initState();
    _narrator = ref.read(narratorProvider);
    if (widget.autoPlay) _speakAfterFrame();
  }

  @override
  void didUpdateWidget(SpeakButton old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _stopLater(old.text);
      if (widget.autoPlay) _speakAfterFrame();
    }
  }

  // After the frame, so the newest text on screen is the one heard when
  // several appear together.
  void _speakAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speak();
    });
  }

  void _speak() {
    final pace = ref.read(readAloudProvider);
    if (!pace.enabled) return;
    _narrator.speak(widget.text, ref.read(languageProvider), pace);
  }

  // Stopping notifies other speaker buttons, which can't rebuild while the
  // tree is being built or torn down, so it waits for the frame to end.
  void _stopLater(String text) {
    final narrator = _narrator;
    scheduleMicrotask(() => narrator.stopIfSpeaking(text));
  }

  @override
  void dispose() {
    _stopLater(widget.text);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(readAloudProvider).enabled) return const SizedBox.shrink();
    final t = ref.watch(stringsProvider);
    return ValueListenableBuilder<String?>(
      valueListenable: _narrator.speaking,
      builder: (context, speaking, _) {
        final playing = speaking == widget.text;
        return Semantics(
          button: true,
          label: t(playing ? 'stop_reading' : 'read_aloud'),
          excludeSemantics: true,
          child: Tooltip(
            message: t(playing ? 'stop_reading' : 'read_aloud'),
            excludeFromSemantics: true,
            child: InkResponse(
              key: const ValueKey('speak_button'),
              radius: widget.size * 0.75,
              onTap: () => playing ? _narrator.stop() : _speak(),
              // The padding makes the touch target larger than the icon.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: playing ? Toon.gold : Toon.cream,
                    shape: BoxShape.circle,
                    border: Border.all(color: Toon.ink, width: 2),
                  ),
                  child: Icon(
                    playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: widget.size * 0.6,
                    color: Toon.ink,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
