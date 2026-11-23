import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Gemini-style live stream: characters reveal smoothly, the bottom edge of the
/// text fades out, and formulas are typeset as soon as their delimiters close,
/// without waiting for the whole answer to finish.
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

  @override
  void initState() {
    super.initState();
    _shown = min(widget.text.length, 12);
    _timer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      if (!mounted) return;
      final target = widget.text.length;
      if (_shown >= target) return;
      final remaining = target - _shown;
      final step = max(1, (remaining * 0.22).ceil());
      setState(() => _shown = min(target, _shown + step));
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
        TextStyle(fontSize: 15.5, height: 1.7, color: scheme.onSurface);
    final visible = widget.text.substring(0, _shown);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _streamBlocks(context, visible, base),
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Color(0x33FFFFFF)],
        stops: [0, 0.62, 1],
      ).createShader(rect),
      child: content,
    );
  }
}

List<Widget> _streamBlocks(
  BuildContext context,
  String source,
  TextStyle base,
) {
  if (source.isEmpty) {
    return [
      Text('…', style: base.copyWith(color: base.color?.withOpacity(0.4))),
    ];
  }
  final widgets = <Widget>[];
  final display = RegExp(r'\$\$([\s\S]+?)\$\$');
  var last = 0;
  for (final match in display.allMatches(source)) {
    _streamParagraph(widgets, source.substring(last, match.start), base);
    final tex = (match.group(1) ?? '').trim();
    if (tex.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              tex,
              mathStyle: MathStyle.display,
              textStyle: TextStyle(fontSize: 16, color: base.color),
            ),
          ),
        ),
      );
    }
    last = match.end;
  }
  _streamParagraph(widgets, source.substring(last), base);
  return widgets;
}

void _streamParagraph(List<Widget> widgets, String raw, TextStyle base) {
  if (raw.isEmpty) return;
  final text = raw;
  final inline = RegExp(r'\$([^$\n]+?)\$');
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in inline.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    final tex = (match.group(1) ?? '').trim();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          tex,
          mathStyle: MathStyle.text,
          textStyle: TextStyle(fontSize: 15.5, color: base.color),
        ),
      ),
    );
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  widgets.add(Text.rich(TextSpan(style: base, children: spans)));
}
