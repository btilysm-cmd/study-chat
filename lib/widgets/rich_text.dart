import 'package:flutter/material.dart';

import 'latex.dart';

class RichMessage extends StatefulWidget {
  const RichMessage({
    super.key,
    required this.text,
    this.streaming = false,
    this.selectable = true,
  });

  final String text;
  final bool streaming;
  final bool selectable;

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
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _cachedBlocks!,
    );
    return widget.selectable ? SelectionArea(child: column) : column;
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
  final display = RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]');
  var last = 0;
  for (final match in display.allMatches(chunk)) {
    _appendParagraph(context, widgets, chunk.substring(last, match.start));
    final tex = (match.group(1) ?? match.group(2) ?? '').trim();
    if (tex.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: mathWidget(
              tex,
              display: true,
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
  final lines = chunk.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    if (_isTableStart(lines, i)) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        final cells = _tableCells(lines[i]);
        if (!_isSeparatorRow(cells)) rows.add(cells);
        i++;
      }
      i--;
      if (rows.isNotEmpty) widgets.add(_table(context, rows));
      continue;
    }
    if (line.startsWith('>')) {
      final quoted = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        var text = lines[i].trim();
        text = text.substring(1);
        if (text.startsWith(' ')) text = text.substring(1);
        quoted.add(text);
        i++;
      }
      i--;
      final body = quoted.join('\n').trim();
      if (body.isNotEmpty) {
        final scheme = Theme.of(context).colorScheme;
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: scheme.primary.withOpacity(0.45),
                  width: 3,
                ),
              ),
            ),
            child: RichMessage(text: body, selectable: false),
          ),
        );
      }
      continue;
    }
    if (_listItem(lines[i]) != null) {
      final items = <_ListItem>[];
      while (i < lines.length) {
        final item = _listItem(lines[i]);
        if (item == null) break;
        items.add(item);
        i++;
      }
      i--;
      if (items.isNotEmpty) widgets.add(_listBlock(context, items));
      continue;
    }
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

class _ListItem {
  _ListItem(this.level, this.marker, this.text, this.task);

  final int level;
  final String marker;
  final String text;
  final bool? task;
}

_ListItem? _listItem(String raw) {
  final match = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$').firstMatch(raw);
  if (match == null) return null;
  final indent = match.group(1)!.replaceAll('\t', '  ').length;
  var text = match.group(3)!.trim();
  bool? task;
  final check = RegExp(r'^\[([ xX])\]\s*(.*)$').firstMatch(text);
  if (check != null) {
    task = check.group(1)!.toLowerCase() == 'x';
    text = check.group(2)!.trim();
  }
  return _ListItem(
    (indent / 2).floor().clamp(0, 4),
    match.group(2)!,
    text,
    task,
  );
}

Widget _listBlock(BuildContext context, List<_ListItem> items) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(
              left: item.level * 16.0,
              top: 2,
              bottom: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: item.task != null
                      ? Icon(
                          item.task!
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: item.task!
                              ? scheme.primary
                              : scheme.onSurface.withOpacity(0.4),
                        )
                      : Text(
                          RegExp(r'^\d').hasMatch(item.marker)
                              ? item.marker
                              : '•',
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.55,
                            color: scheme.onSurface.withOpacity(0.65),
                          ),
                        ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 15, height: 1.6),
                      children: _inlineSpans(context, item.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

bool _isTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) return false;
  if (!lines[index].trim().startsWith('|')) return false;
  return _isSeparatorRow(_tableCells(lines[index + 1]));
}

List<String> _tableCells(String line) {
  var raw = line.trim();
  if (raw.startsWith('|')) raw = raw.substring(1);
  if (raw.endsWith('|')) raw = raw.substring(0, raw.length - 1);
  return raw.split('|').map((cell) => cell.trim()).toList();
}

bool _isSeparatorRow(List<String> cells) {
  if (cells.isEmpty) return false;
  return cells.every(
    (cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.replaceAll(' ', '')),
  );
}

Widget _table(BuildContext context, List<List<String>> rows) {
  final scheme = Theme.of(context).colorScheme;
  final header = rows.first;
  final body = rows.skip(1).toList();
  Widget cell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          ),
          children: _inlineSpans(context, text),
        ),
      ),
    );
  }

  final wide = header.length > 3;
  final table = Table(
    defaultColumnWidth: wide
        ? const IntrinsicColumnWidth()
        : const FlexColumnWidth(),
    border: TableBorder.all(
      color: scheme.outlineVariant.withOpacity(0.55),
      borderRadius: BorderRadius.circular(8),
    ),
    children: [
      TableRow(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.45),
        ),
        children: [for (final text in header) cell(text, isHeader: true)],
      ),
      for (final row in body)
        TableRow(
          children: [
            for (var i = 0; i < header.length; i++)
              cell(i < row.length ? row[i] : ''),
          ],
        ),
    ],
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: wide
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table)
        : table,
  );
}

/// Inline math is kept in the text flow, but a long formula is promoted to a
/// horizontally scrollable block so it can never overflow the screen.
void _inlineParagraph(BuildContext context, List<Widget> widgets, String text) {
  final inline = RegExp(r'\$([^$\n]+?)\$|\\\(([\s\S]+?)\\\)');
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
    final tex = (match.group(1) ?? match.group(2) ?? '').trim();
    if (tex.length > 32) {
      flush();
      widgets.add(_mathBlock(tex));
    } else {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: mathWidget(tex, textStyle: const TextStyle(fontSize: 15.5)),
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
  final inline = RegExp(r'\$([^$\n]+?)\$|\\\(([\s\S]+?)\\\)');
  var last = 0;
  for (final match in inline.allMatches(text)) {
    if (match.start > last) {
      spans.addAll(_boldSpans(text.substring(last, match.start)));
    }
    final tex = (match.group(1) ?? match.group(2) ?? '').trim();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: mathWidget(tex, textStyle: const TextStyle(fontSize: 15.5)),
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
      child: mathWidget(
        tex,
        display: true,
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
