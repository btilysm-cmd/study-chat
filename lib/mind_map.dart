import 'dart:convert';

class MindNode {
  MindNode(this.title, [List<MindNode>? children]) : children = children ?? [];

  String title;
  final List<MindNode> children;
}

MindNode parseMindMap(String raw, {required String fallbackTitle}) {
  final text = raw.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) {
        final node = _fromMap(decoded, 0);
        if (node != null && node.title.trim().isNotEmpty) return node;
      }
    } catch (_) {
      // Fall through to a Markdown outline.
    }
  }
  return _fromOutline(text, fallbackTitle);
}

MindNode? _fromMap(Map map, int depth) {
  if (depth > 6) return null;
  final title = (map['title'] ?? map['name'] ?? map['text'] ?? '')
      .toString()
      .trim();
  if (title.isEmpty) return null;
  final children = <MindNode>[];
  final rawChildren = map['children'] ?? map['nodes'];
  if (rawChildren is List) {
    for (final item in rawChildren) {
      MindNode? child;
      if (item is Map) child = _fromMap(item, depth + 1);
      if (child != null) children.add(child);
      if (children.length >= 40) break;
    }
  }
  return MindNode(title, children);
}

MindNode _fromOutline(String text, String fallbackTitle) {
  final root = MindNode(fallbackTitle, []);
  final stack = <(int, MindNode)>[(0, root)];
  for (var line in text.split('\n')) {
    line = line.trimRight();
    if (line.trim().isEmpty || line.trim() == '```') continue;
    if (line.trim().startsWith('```')) continue;
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line.trim());
    final bullet = RegExp(r'^(\s*)(?:[-*+]|\d+[.)])\s+(.*)$').firstMatch(line);
    int level;
    String title;
    if (heading != null) {
      level = heading.group(1)!.length;
      title = heading.group(2)!.trim();
    } else if (bullet != null) {
      level = 2 + (bullet.group(1)!.replaceAll('\t', '  ').length ~/ 2);
      title = bullet.group(2)!.trim();
    } else {
      continue;
    }
    title = title
        .replaceAll(RegExp(r'\*\*|`|~~'), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+'), '')
        .trim();
    if (title.isEmpty) continue;
    while (stack.length > 1 && stack.last.$1 >= level) {
      stack.removeLast();
    }
    final node = MindNode(title);
    stack.last.$2.children.add(node);
    stack.add((level, node));
    if (_count(root) >= 120) break;
  }
  if (root.children.isEmpty) {
    root.children.add(MindNode(text.trim().isEmpty ? '无法解析' : _shorten(text)));
  }
  return root;
}

int _count(MindNode node) =>
    1 + node.children.fold<int>(0, (sum, child) => sum + _count(child));

String _shorten(String text) {
  final cleaned = text.replaceAll(RegExp(r'[#*`>]'), ' ').trim();
  return cleaned.length <= 60 ? cleaned : '${cleaned.substring(0, 60)}…';
}

String mindMapOutline(MindNode node) {
  final buffer = StringBuffer();
  void walk(MindNode item, int depth) {
    buffer.writeln('${'  ' * depth}- ${item.title}');
    for (final child in item.children) {
      walk(child, depth + 1);
    }
  }

  walk(node, 0);
  return buffer.toString().trimRight();
}
