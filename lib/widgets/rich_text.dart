import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class RichMessage extends StatelessWidget {
  const RichMessage({super.key, required this.text, this.streaming = false});

  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final body = text.trim();
    if (streaming) {
      return SelectionArea(
        child: Text(
          body.isEmpty ? '…' : body,
          style: const TextStyle(fontSize: 15.5, height: 1.65),
        ),
      );
    }
    if (body.isEmpty) return const SizedBox.shrink();
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocks(context, body),
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
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ));
    }
    last = match.end;
  }
  _appendParagraph(context, widgets, chunk.substring(last));
}

void _appendParagraph(BuildContext context, List<Widget> widgets, String chunk) {
  final text = chunk.trim();
  if (text.isEmpty) return;
  final inline = RegExp(r'\$([^$\n]+?)\$');
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in inline.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    final tex = (match.group(1) ?? '').trim();
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Math.tex(
        tex,
        mathStyle: MathStyle.text,
        textStyle: const TextStyle(fontSize: 15.5),
      ),
    ));
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  widgets.add(Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 15.5, height: 1.65),
        children: spans,
      ),
    ),
  ));
}

Widget _codeBlock(BuildContext context, String code) {
  final theme = Theme.of(context);
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
      borderRadius: BorderRadius.circular(10),
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
