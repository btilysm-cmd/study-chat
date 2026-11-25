import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../app_state.dart';
import '../mind_map.dart';
import '../models.dart';

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({
    super.key,
    required this.state,
    required this.conversation,
    required this.message,
  });

  final AppState state;
  final Conversation conversation;
  final ChatMessage message;

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  MindNode? _root;
  String? _error;
  bool _loading = true;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  String get _question {
    final messages = widget.conversation.messages;
    final index = messages.indexOf(widget.message);
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].role == 'user' && messages[i].text.trim().isNotEmpty) {
        return messages[i].text.trim();
      }
    }
    return widget.conversation.title;
  }

  Future<void> _generate() async {
    final config = widget.state.config;
    if (config == null || !config.ready) {
      setState(() {
        _loading = false;
        _error = '先去设置里填好 API 地址、Key 和模型';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _root = null;
    });
    var answer = widget.message.text.trim();
    if (answer.length > 14000) {
      answer =
          '${answer.substring(0, 9000)}\n\n[中间省略]\n\n${answer.substring(answer.length - 5000)}';
    }
    final question = _question;
    final prompt =
        '请把下面的问答整理成一张思维导图。\n\n'
        '只输出一个 JSON 对象，不要 Markdown 代码围栏，不要解释。格式：\n'
        '{"title":"根主题","children":[{"title":"一级要点","children":[{"title":"二级要点"}]}]}\n'
        '要求：根主题不超过 18 字；一级要点 3–6 个；每个节点不超过 24 字；'
        '最多 4 层、40 个节点；只保留知识结构，不要客套话。\n\n'
        '【问题】\n$question\n\n【回答】\n$answer';
    final buffer = StringBuffer();
    final done = Completer<void>();
    final stream = widget.state.api.streamChat(
      config: config,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      system: '你是知识结构化助手。把内容整理成层级清楚的思维导图，只输出 JSON。',
      reasoningEffort: 'none',
    );
    _sub = stream.listen(
      buffer.write,
      onError: (Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    try {
      await done.future;
      final root = parseMindMap(
        buffer.toString(),
        fallbackTitle: question.isEmpty ? '思维导图' : _short(question, 18),
      );
      if (!mounted) return;
      setState(() {
        _root = root;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    } finally {
      _sub = null;
    }
  }

  static String _short(String text, int max) {
    final chars = text.replaceAll(RegExp(r'\s+'), ' ').runes.toList();
    if (chars.length <= max) return String.fromCharCodes(chars);
    return '${String.fromCharCodes(chars.take(max))}…';
  }

  void _copyOutline() {
    final root = _root;
    if (root == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: mindMapOutline(root))));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('大纲已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('思维导图'),
        actions: [
          IconButton(
            tooltip: '复制大纲',
            onPressed: _root == null ? null : _copyOutline,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: '重新生成',
            onPressed: _loading ? null : () => unawaited(_generate()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('正在把这段问答整理成脑图…'),
          ],
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_outlined, size: 44, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                '脑图生成失败\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: () => unawaited(_generate()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final root = _root;
    if (root == null) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Icon(Icons.pinch_outlined, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                '双指缩放，拖动查看',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              Text(
                '${_count(root)} 个节点',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.55),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _MindMapView(root: root),
          ),
        ),
      ],
    );
  }

  int _count(MindNode node) =>
      1 + node.children.fold<int>(0, (sum, item) => sum + _count(item));
}

class _MindMapView extends StatelessWidget {
  const _MindMapView({required this.root});

  final MindNode root;

  @override
  Widget build(BuildContext context) {
    final layout = _MindLayout(root);
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(160),
      minScale: 0.35,
      maxScale: 2.6,
      child: SizedBox(
        width: layout.width,
        height: layout.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ConnectorPainter(layout.nodes)),
            ),
            for (final item in layout.nodes)
              Positioned(
                left: item.x,
                top: item.y,
                child: _MindCard(item: item),
              ),
          ],
        ),
      ),
    );
  }
}

class _MindCard extends StatelessWidget {
  const _MindCard({required this.item});

  final _LaidNode item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final root = item.depth == 0;
    final color = root
        ? scheme.primaryContainer
        : item.depth == 1
        ? scheme.surfaceContainerHighest
        : scheme.surface;
    return Container(
      width: _MindLayout.nodeWidth,
      height: _MindLayout.nodeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(root ? 14 : 11),
        border: Border.all(
          color: root
              ? scheme.primary.withOpacity(0.5)
              : scheme.outlineVariant.withOpacity(0.7),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          item.node.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: root ? 14.5 : 13,
            height: 1.3,
            fontWeight: root
                ? FontWeight.w700
                : (item.depth == 1 ? FontWeight.w600 : FontWeight.w400),
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _LaidNode {
  _LaidNode({
    required this.node,
    required this.depth,
    required this.x,
    required this.y,
    required this.parent,
  });

  final MindNode node;
  final int depth;
  final double x;
  final double y;
  final _LaidNode? parent;
  final List<_LaidNode> children = [];
}

class _MindLayout {
  _MindLayout(MindNode root) {
    final heights = <MindNode, double>{};
    double measure(MindNode node) {
      final cached = heights[node];
      if (cached != null) return cached;
      if (node.children.isEmpty) return heights[node] = nodeHeight;
      var total = 0.0;
      for (final child in node.children) {
        total += measure(child);
      }
      total += vGap * (node.children.length - 1);
      return heights[node] = total < nodeHeight ? nodeHeight : total;
    }

    void place(MindNode node, int depth, double top, _LaidNode? parent) {
      final height = measure(node);
      final laid = _LaidNode(
        node: node,
        depth: depth,
        x: pad + depth * (nodeWidth + hGap),
        y: top + height / 2 - nodeHeight / 2,
        parent: parent,
      );
      nodes.add(laid);
      parent?.children.add(laid);
      var childTop = top;
      for (final child in node.children) {
        place(child, depth + 1, childTop, laid);
        childTop += measure(child) + vGap;
      }
    }

    place(root, 0, pad, null);
    var maxDepth = 0;
    for (final item in nodes) {
      if (item.depth > maxDepth) maxDepth = item.depth;
    }
    width = pad * 2 + (maxDepth + 1) * nodeWidth + maxDepth * hGap;
    height = measure(root) + pad * 2;
  }

  static const nodeWidth = 184.0;
  static const nodeHeight = 62.0;
  static const hGap = 62.0;
  static const vGap = 14.0;
  static const pad = 24.0;

  final List<_LaidNode> nodes = [];
  late final double width;
  late final double height;
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.nodes);

  final List<_LaidNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9AA4B2).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final item in nodes) {
      final parent = item.parent;
      if (parent == null) continue;
      final start = Offset(
        parent.x + _MindLayout.nodeWidth,
        parent.y + _MindLayout.nodeHeight / 2,
      );
      final end = Offset(item.x, item.y + _MindLayout.nodeHeight / 2);
      final mid = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => false;
}
