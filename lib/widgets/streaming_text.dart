import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Live stream renderer with an incremental cache.
///
/// The expensive parts (TeX layout, finished paragraphs) are built once and the
/// exact same widget instances are reused on later frames, so Flutter skips
/// rebuilding them. Only the paragraph currently being typed is rebuilt, and
/// only that paragraph is masked for the bottom fade. This keeps answers with
/// dozens of formulas from melting the UI thread.
class StreamingText extends StatefulWidget {
  const StreamingText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _Block {
  const _Block.paragraph(this.raw) : tex = null;
  const _Block.display(this.tex) : raw = '';

  final String raw;
  final String? tex;
  bool get isDisplay => tex != null;
}

class _StreamingTextState extends State<StreamingText> {
  Timer? _timer;
  int _shown = 0;
  String _cacheSignature = '';
  final Map<String, Widget> _blocks = {};
  final Map<String, Widget> _math = {};

  @override
  void initState() {
    super.initState();
    _shown = min(widget.text.length, 10);
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      final target = widget.text.length;
      if (_shown >= target) return;
      final remaining = target - _shown;
      final step = max(1, (remaining * 0.32).ceil());
      setState(() => _shown = min(target, _shown + step));
    });
  }

  @override
  void didUpdateWidget(covariant StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text.length < _shown) _shown = widget.text.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final style =
        widget.style ??
        TextStyle(color: Theme.of(context).colorScheme.onSurface);
    final signature = '${style.fontSize}|${style.color?.value}';
    if (signature != _cacheSignature) {
      _cacheSignature = signature;
      _blocks.clear();
      _math.clear();
    }
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
    final parsed = _parse(visible);
    final children = <Widget>[];
    for (var i = 0; i < parsed.length; i++) {
      final block = parsed[i];
      Widget widget = _blockWidget(
        block,
        base,
        scheme,
        cache: i < parsed.length - 1,
      );
      if (i == parsed.length - 1 && !block.isDisplay) {
        widget = _fadeTail(widget);
      }
      children.add(widget);
    }
    if (children.isEmpty) {
      children.add(
        Text('…', style: base.copyWith(color: base.color?.withOpacity(0.35))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<_Block> _parse(String source) {
    final result = <_Block>[];
    if (source.isEmpty) return result;
    final display = RegExp(r'\$\$([\s\S]+?)\$\$');
    var last = 0;
    for (final match in display.allMatches(source)) {
      _addParagraph(result, source.substring(last, match.start));
      result.add(_Block.display((match.group(1) ?? '').trim()));
      last = match.end;
    }
    _addParagraph(result, source.substring(last));
    return result;
  }

  void _addParagraph(List<_Block> result, String raw) {
    if (raw.isEmpty) return;
    result.add(_Block.paragraph(raw));
  }

  Widget _blockWidget(
    _Block block,
    TextStyle base,
    ColorScheme scheme, {
    required bool cache,
  }) {
    if (block.isDisplay) {
      final tex = block.tex ?? '';
      return _math.putIfAbsent('d|$_cacheSignature|$tex', () {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              tex,
              mathStyle: MathStyle.display,
              textStyle: TextStyle(fontSize: 16, color: base.color),
            ),
          ),
        );
      });
    }
    if (!cache) {
      return Text.rich(
        TextSpan(style: base, children: _inlineSpans(block.raw, base)),
      );
    }
    return _blocks.putIfAbsent('p|$_cacheSignature|${block.raw}', () {
      return Text.rich(
        TextSpan(style: base, children: _inlineSpans(block.raw, base)),
      );
    });
  }

  List<InlineSpan> _inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final inline = RegExp(r'\$([^$\n]+?)\$');
    var last = 0;
    for (final match in inline.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final tex = (match.group(1) ?? '').trim();
      if (tex.isNotEmpty) {
        final widget = _math.putIfAbsent('i|$_cacheSignature|$tex', () {
          return Math.tex(
            tex,
            mathStyle: MathStyle.text,
            textStyle: TextStyle(fontSize: 15.5, color: base.color),
          );
        });
        spans.add(
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: widget),
        );
      }
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    if (_blocks.length > 500 || _math.length > 500) {
      _blocks.clear();
      _math.clear();
    }
    return spans;
  }

  Widget _fadeTail(Widget child) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Color(0x22FFFFFF)],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: child,
    );
  }
}
