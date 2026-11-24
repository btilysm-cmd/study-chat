import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'rich_text.dart';

/// Live stream renderer.
///
/// Blocks are append-only while an answer streams: finished blocks (text or a
/// closed `$$...$$` formula) are built exactly once and then reused at the same
/// index. Only the last, still-growing block is rebuilt, so an answer with many
/// formulas no longer recreates every TeX widget on every tick.
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
  final List<Widget> _done = [];
  String? _signature;

  @override
  void initState() {
    super.initState();
    // When a screen is rebuilt mid-stream (leaving and coming back), show
    // everything already received immediately; only new deltas are revealed.
    _shown = widget.text.length;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final target = widget.text.length;
      if (_shown >= target) return;
      final remaining = target - _shown;
      final step = max(2, min(48, (remaining * 0.16).ceil()));
      setState(() => _shown = min(target, _shown + step));
    });
  }

  @override
  void didUpdateWidget(covariant StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text.length < _shown) {
      _shown = widget.text.length;
      _done.clear();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final style =
        widget.style ??
        TextStyle(color: Theme.of(context).colorScheme.onSurface);
    final signature = '${style.fontSize}|${style.color?.value}';
    if (_signature != null && _signature != signature) _done.clear();
    _signature = signature;
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
    final blocks = _parse(visible);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final isLast = i == blocks.length - 1;
      if (!isLast) {
        if (i < _done.length) {
          children.add(_done[i]);
        } else {
          final widget = _renderDone(block, base);
          _done.add(widget);
          children.add(widget);
        }
      } else if (block.isDisplay) {
        children.add(_renderDone(block, base));
      } else {
        children.add(_renderGrowing(block.raw, base));
      }
    }
    if (children.isEmpty) {
      children.add(
        Text('…', style: base.copyWith(color: base.color?.withOpacity(0.35))),
      );
    }
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 58,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.surface.withOpacity(0), scheme.surface],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_Block> _parse(String source) {
    final result = <_Block>[];
    if (source.isEmpty) return result;
    final display = RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]');
    var last = 0;
    for (final match in display.allMatches(source)) {
      _splitParagraphs(result, source.substring(last, match.start));
      result.add(
        _Block.display((match.group(1) ?? match.group(2) ?? '').trim()),
      );
      last = match.end;
    }
    _splitParagraphs(result, source.substring(last));
    return result;
  }

  void _splitParagraphs(List<_Block> result, String raw) {
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'\n\s*\n'));
    for (final part in parts) {
      if (part.isNotEmpty) result.add(_Block.paragraph(part));
    }
  }

  Widget _renderDone(_Block block, TextStyle base) {
    if (block.isDisplay) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            block.tex ?? '',
            mathStyle: MathStyle.display,
            textStyle: TextStyle(fontSize: 16, color: base.color),
          ),
        ),
      );
    }
    return RichMessage(text: block.raw, selectable: false);
  }

  Widget _renderGrowing(String raw, TextStyle base) {
    final cleaned = raw
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
    return Text(
      cleaned,
      style: base.copyWith(color: base.color?.withOpacity(0.92)),
    );
  }

  List<InlineSpan> _inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final inline = RegExp(r'\$([^$\n]+?)\$|\\\(([^)\n]+?)\\\)');
    var last = 0;
    for (final match in inline.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final tex = (match.group(1) ?? match.group(2) ?? '').trim();
      if (tex.isNotEmpty) {
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
      }
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}
