import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Reveals incoming text character by character with a short fade-in tail and
/// a blinking caret, so SSE bursts feel like a steady typewriter stream.
class StreamingText extends StatefulWidget {
  const StreamingText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  Timer? _timer;
  int _shown = 0;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _shown = min(widget.text.length, 24);
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      _tick++;
      final target = widget.text.length;
      if (_shown < target) {
        final remaining = target - _shown;
        final step = max(1, (remaining * 0.28).ceil());
        setState(() => _shown = min(target, _shown + step));
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text.length < _shown) _shown = widget.text.length;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base =
        widget.style ??
        TextStyle(fontSize: 15.5, height: 1.65, color: scheme.onSurface);
    final visible = widget.text.substring(0, _shown);
    final blinkOn = (_tick ~/ 16).isEven;

    const fade = 8;
    final runes = visible.runes.toList();
    final fadeStart = max(0, runes.length - fade);
    final spans = <InlineSpan>[];
    if (fadeStart > 0) {
      spans.add(TextSpan(text: String.fromCharCodes(runes.take(fadeStart))));
    }
    for (var i = fadeStart; i < runes.length; i++) {
      final alpha = 0.35 + 0.65 * ((i - fadeStart + 1) / fade);
      spans.add(
        TextSpan(
          text: String.fromCharCode(runes[i]),
          style: TextStyle(color: base.color?.withOpacity(alpha)),
        ),
      );
    }
    if (visible.isEmpty) {
      spans.add(const TextSpan(text: '…'));
    }
    spans.add(
      TextSpan(
        text: '▍',
        style: TextStyle(
          color: scheme.primary.withOpacity(blinkOn ? 0.9 : 0.15),
          fontSize: base.fontSize,
        ),
      ),
    );

    return Text.rich(TextSpan(style: base, children: spans));
  }
}
