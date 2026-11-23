import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class RichMessage extends StatefulWidget {
  const RichMessage({super.key, required this.text, this.streaming = false});

  final String text;
  final bool streaming;

  @override
  State<RichMessage> createState() => _RichMessageState();
}

class _RichMessageState extends State<RichMessage> {
  String? _cachedText;
  List<Widget>? _cachedBlocks;

  @override
  Widget build(BuildContext context) {
    final body = widget.text.trim();
    if (widget.streaming) {
      return Text(
        body.isEmpty ? '…' : body,
        style: const TextStyle(fontSize: 15.5, height: 1.65),
      );
    }
    if (body.isEmpty) return const SizedBox.shrink();
    if (_cachedText != body || _cachedBlocks == null) {
      _cachedText = body;
      _cachedBlocks = _blocks(context, body);
    }
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _cachedBlocks!,
      ),
    );
  }
}

List<Widget> _blocks(BuildContext context, String source) {
  final widgets = <Widget>[];
  final fence = RegExp(r'```[a-zA-Z0-9_+-]*\n?([\s\S]*?)```');
  var last = 0;
  for (final match in fence.allMatches(source)) {
    _appendText(context, widgets, source.substring(last, match.start));
    final code = (match.group(1) ?? '').trimRight();
    if (code.isNotEmpty) widgets.add(_codeBlock(context, code));
    last = match.end;
  }
  _appendText(context, widgets, source.substring(last));
  return widgets;
}

void _appendText(BuildContext context, List<Widget> widgets, String chunk) {
  if (chunk.trim().isEmpty) return;
  final display = RegExp(r'\$\$([\s\S]+?)\$\$');
  var last = 0;
  for (final match in display.allMatches(chunk)) {
    _appendParagraph(context, widgets, chunk.substring(last, match.start));
    final tex = (match.group(1) ?? '').trim();
    if (tex.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              tex,
              mathStyle: MathStyle.display,
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }
    last = match.end;
  }
  _appendParagraph(context, widgets, chunk.substring(last));
}

void _appendParagraph(
  BuildContext context,
  List<Widget> widgets,
  String chunk,
) {
  for (final raw in chunk.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line)) {
      widgets.add(const Divider(height: 22));
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final text = heading.group(2)!.trim();
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: level <= 2 ? 12 : 8, bottom: 6),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: level == 1 ? 20 : (level == 2 ? 18 : 16.5),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
              children: _inlineSpans(context, text),
            ),
          ),
        ),
      );
      continue;
    }
    _inlineParagraph(context, widgets, line);
  }
}

/// Inline math is kept in the text flow, but a long formula is promoted to a
/// horizontally scrollable block so it can never overflow the screen.
void _inlineParagraph(BuildContext context, List<Widget> widgets, String text) {
  final inline = RegExp(r'\$([^$\n]+?)\$');
  final spans = <InlineSpan>[];
  var last = 0;
  void flush() {
    if (spans.isEmpty) return;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 15.5, height: 1.65),
            children: List.of(spans),
          ),
        ),
      ),
    );
    spans.clear();
  }

  for (final match in inline.allMatches(text)) {
    if (match.start > last) {
      spans.addAll(_boldSpans(text.substring(last, match.start)));
    }
    final tex = (match.group(1) ?? '').trim();
    if (tex.length > 32) {
      flush();
      widgets.add(_mathBlock(tex));
    } else {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.text,
            textStyle: const TextStyle(fontSize: 15.5),
          ),
        ),
      );
    }
    last = match.end;
  }
  if (last < text.length) spans.addAll(_boldSpans(text.substring(last)));
  flush();
}

List<InlineSpan> _inlineSpans(BuildContext context, String text) {
  final spans = <InlineSpan>[];
  final inline = RegExp(r'\$([^$\n]+?)\$');
  var last = 0;
  for (final match in inline.allMatches(text)) {
    if (match.start > last) {
      spans.addAll(_boldSpans(text.substring(last, match.start)));
    }
    final tex = (match.group(1) ?? '').trim();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          tex,
          mathStyle: MathStyle.text,
          textStyle: const TextStyle(fontSize: 15.5),
        ),
      ),
    );
    last = match.end;
  }
  if (last < text.length) spans.addAll(_boldSpans(text.substring(last)));
  return spans;
}

List<InlineSpan> _boldSpans(String text) {
  final spans = <InlineSpan>[];
  final bold = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final match in bold.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

Widget _mathBlock(String tex) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        mathStyle: MathStyle.display,
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
  );
}

Widget _codeBlock(BuildContext context, String code) {
  final theme = Theme.of(context);
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
        ),
      ),
    ),
  );
}
