import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
      widgets.add(const SizedBox(height: 2));
      widgets.add(_mathBlock(tex));
      widgets.add(const SizedBox(height: 2));
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
          children: _inlineSpans(context, text, fontSize: 14),
        ),
      ),
    );
  }

  final table = Table(
    defaultColumnWidth: const MaxColumnWidth(
      IntrinsicColumnWidth(),
      FixedColumnWidth(132),
    ),
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
    child: _HScroll(
      hint: header.length > 3 ? '左右滑动查看完整表格' : null,
      child: table,
    ),
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
      spans.addAll(_styledSpans(context, text.substring(last, match.start)));
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
  if (last < text.length) {
    spans.addAll(_styledSpans(context, text.substring(last)));
  }
  flush();
}

final _inlinePattern = RegExp(
  r'\\([\\`*_{}\[\]()#+\-.!~>|])'
  r'|\*\*\*(.+?)\*\*\*'
  r'|\*\*(.+?)\*\*'
  r'|\*(.+?)\*'
  r'|~~(.+?)~~'
  r'|`([^`\n]+)`'
  r'|\[([^\]]+)\]\(([^)\s]+)\)',
);

List<InlineSpan> _inlineSpans(
  BuildContext context,
  String text, {
  double fontSize = 15.5,
}) {
  final spans = <InlineSpan>[];
  final inline = RegExp(r'\$([^$\n]+?)\$|\\\(([\s\S]+?)\\\)');
  var last = 0;
  for (final match in inline.allMatches(text)) {
    if (match.start > last) {
      spans.addAll(_styledSpans(context, text.substring(last, match.start)));
    }
    final tex = (match.group(1) ?? match.group(2) ?? '').trim();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: mathWidget(tex, textStyle: TextStyle(fontSize: fontSize)),
      ),
    );
    last = match.end;
  }
  if (last < text.length) {
    spans.addAll(_styledSpans(context, text.substring(last)));
  }
  return spans;
}

List<InlineSpan> _styledSpans(BuildContext context, String text) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in _inlinePattern.allMatches(text)) {
    if (match.start > last) {
      spans.addAll(_plainSpans(text.substring(last, match.start)));
    }
    final escaped = match.group(1);
    if (escaped != null) {
      spans.add(TextSpan(text: escaped));
    } else if (match.group(2) != null) {
      spans.add(
        TextSpan(
          text: match.group(2),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (match.group(3) != null) {
      spans.add(
        TextSpan(
          text: match.group(3),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (match.group(4) != null) {
      spans.add(
        TextSpan(
          text: match.group(4),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (match.group(5) != null) {
      spans.add(
        TextSpan(
          text: match.group(5),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      );
    } else if (match.group(6) != null) {
      spans.add(
        TextSpan(
          text: match.group(6),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.7),
          ),
        ),
      );
    } else if (match.group(7) != null) {
      final label = match.group(7)!;
      final url = match.group(8)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _openLink(url),
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary
                    .withOpacity(0.5),
              ),
            ),
          ),
        ),
      );
    }
    last = match.end;
  }
  if (last < text.length) spans.addAll(_plainSpans(text.substring(last)));
  return spans;
}

List<InlineSpan> _plainSpans(String text) {
  final spans = <InlineSpan>[];
  final run = RegExp(r'[^\s\u4e00-\u9fff]{28,}');
  var last = 0;
  for (final match in run.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    final value = match.group(0)!;
    final broken = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i > 0 && i % 20 == 0) broken.write('\u200B');
      broken.write(value[i]);
    }
    spans.add(TextSpan(text: broken.toString()));
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

Future<void> _openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Widget _mathBlock(String tex) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(
              child: mathWidget(
                tex,
                display: true,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      },
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
    child: _HScroll(
      hint: code.split('\n').any((line) => line.length > 48)
          ? '左右滑动查看完整代码'
          : null,
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

class _HScroll extends StatefulWidget {
  const _HScroll({required this.child, this.hint});

  final Widget child;
  final String? hint;

  @override
  State<_HScroll> createState() => _HScrollState();
}

class _HScrollState extends State<_HScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scroll = Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
    final hint = widget.hint;
    if (hint == null) return scroll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withOpacity(0.42),
          ),
        ),
        const SizedBox(height: 4),
        scroll,
      ],
    );
  }
}

/// Long answers are split into pages instead of laying out thousands of
/// formula and table widgets at once (which can freeze the UI thread).
class LongRichMessage extends StatefulWidget {
  const LongRichMessage({super.key, required this.text});

  final String text;

  @override
  State<LongRichMessage> createState() => _LongRichMessageState();
}

class _LongRichMessageState extends State<LongRichMessage> {
  static const _pageChars = 4000;
  List<String> _pages = const [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pages = _splitPages(widget.text);
  }

  @override
  void didUpdateWidget(covariant LongRichMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _pages = _splitPages(widget.text);
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.length <= 1) return RichMessage(text: widget.text);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichMessage(text: _pages[_page]),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '长回答 · 第 ${_page + 1}/${_pages.length} 页',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withOpacity(0.45),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('上页'),
            ),
            TextButton.icon(
              onPressed: _page + 1 < _pages.length
                  ? () => setState(() => _page++)
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('下页'),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _splitPages(String source) {
    final pages = <String>[];
    final buffer = StringBuffer();
    for (final line in source.split('\n')) {
      if (buffer.length > 0 && buffer.length + line.length > _pageChars) {
        pages.add(buffer.toString());
        buffer.clear();
      }
      buffer.write(line);
      buffer.write('\n');
    }
    if (buffer.isNotEmpty) pages.add(buffer.toString());
    return pages.isEmpty ? [source] : pages;
  }
}
