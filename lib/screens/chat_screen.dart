import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../plain_text.dart';
import '../widgets/appear.dart';
import '../widgets/composer.dart';
import '../widgets/rich_text.dart';
import '../widgets/streaming_text.dart';
import 'branch_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final AppState state;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _follow;
  bool _stick = true;
  bool _dragging = false;
  bool _initialized = false;
  int _idleTicks = 0;
  GptMarkdownConfig? _mdConfig;
  ThemeData? _mdTheme;
  GptMarkdownThemeData? _mdThemeData;
  ThemeData? _mdThemeDataTheme;

  @override
  void initState() {
    super.initState();
    _follow = createTicker(_onFollowTick);
  }

  @override
  void dispose() {
    _follow.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFollowTick(Duration _) {
    if (!mounted || !_scroll.hasClients || _dragging || !_stick) {
      _follow.stop();
      return;
    }
    final target = _scroll.position.maxScrollExtent;
    final current = _scroll.offset;
    final delta = target - current;
    if (delta <= 0.6) {
      if (++_idleTicks > 30) _follow.stop();
      return;
    }
    _idleTicks = 0;
    _scroll.jumpTo(current + delta * 0.22);
  }

  void _scheduleFollow() {
    if (!_stick || _dragging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_stick || _dragging) return;
      if (!_scroll.hasClients) return;
      if (!_initialized) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _initialized = true;
        return;
      }
      _idleTicks = 0;
      if (!_follow.isActive) _follow.start();
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
      _stick = false;
      _follow.stop();
      if (mounted) setState(() {});
    } else if (notification is ScrollEndNotification &&
        notification.dragDetails != null) {
      _dragging = false;
      if (_scroll.hasClients) {
        final atBottom = _scroll.position.maxScrollExtent - _scroll.offset < 80;
        _stick = atBottom;
        if (atBottom) _scheduleFollow();
      }
      if (mounted) setState(() {});
    }
    return false;
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _stick = true;
    _dragging = false;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send(String text, List<Attachment> attachments) async {
    try {
      await widget.state.sendMain(
        widget.conversation,
        text,
        attachments: attachments,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _copy(ChatMessage message) {
    var text = readableText(message.text);
    if (message.sources.isNotEmpty) {
      final sources = <String>[];
      for (var i = 0; i < message.sources.length; i++) {
        final source = message.sources[i];
        sources.add('[${i + 1}] ${source.title}\n${source.url}');
      }
      text = '$text\n\n来源：\n${sources.join('\n')}';
    }
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制为可读文本')));
  }

  bool _hasPair(ChatMessage message) {
    final messages = widget.conversation.messages;
    final index = messages.indexOf(message);
    if (index < 0) return false;
    if (message.role == 'user') {
      return index + 1 < messages.length &&
          messages[index + 1].role == 'assistant';
    }
    return index > 0 && messages[index - 1].role == 'user';
  }

  void _delete(ChatMessage message, {bool withPair = false}) {
    widget.state.deleteMessage(
      widget.conversation,
      message,
      withPair: withPair,
    );
  }

  void _branch(ChatMessage message) {
    final branch = widget.state.createBranch(widget.conversation, message.text);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已建立分叉：${branch.title}')));
  }

  Future<void> _pickModel() async {
    final current = widget.state.config?.model ?? 'deepseek-flash';
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择模型',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final entry in const [
              ('deepseek-flash', 'Flash', '快，支持图片与文档'),
              ('deepseek-v4-pro', 'V4 Pro', '更强推理，纯文本'),
            ])
              RadioListTile<String>(
                value: entry.$1,
                groupValue: current,
                title: Text(entry.$2),
                subtitle: Text(entry.$3),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      await widget.state.switchModel(picked);
    }
  }

  Future<void> _openOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final conversation = widget.conversation;
            final scheme = Theme.of(context).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '对话设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '回答长度',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'short', label: Text('短')),
                        ButtonSegment(value: 'medium', label: Text('中')),
                        ButtonSegment(value: 'long', label: Text('长')),
                      ],
                      selected: {conversation.answerLength},
                      onSelectionChanged: (value) {
                        widget.state.setAnswerLength(conversation, value.first);
                        setSheet(() {});
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '思考等级',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'none', label: Text('无')),
                        ButtonSegment(value: 'low', label: Text('低')),
                        ButtonSegment(value: 'high', label: Text('高')),
                        ButtonSegment(value: 'max', label: Text('最高')),
                      ],
                      selected: {conversation.thinking},
                      onSelectionChanged: (value) {
                        widget.state.setThinking(conversation, value.first);
                        setSheet(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '只对这条对话生效：长度会作为隐藏提示随问题提交，思考等级作为请求参数。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openBranches() async {
    final conversation = widget.conversation;
    final navigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  '分支（${conversation.branches.length}）',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (conversation.branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('还没有分支。点助手回复下的「分支」即可从这段回答继续追问。'),
                ),
              for (final branch in conversation.branches.reversed)
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(
                    branch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${branch.messages.length} 条问答'),
                  onTap: () {
                    Navigator.pop(context);
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => BranchScreen(
                          state: widget.state,
                          conversation: conversation,
                          branch: branch,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  GptMarkdownConfig _markdownConfig(BuildContext context) {
    final theme = Theme.of(context);
    if (identical(theme, _mdTheme) && _mdConfig != null) return _mdConfig!;
    final scheme = theme.colorScheme;
    _mdTheme = theme;
    _mdConfig = GptMarkdownConfig(
      style: TextStyle(fontSize: 15.5, height: 1.65, color: scheme.onSurface),
      onLinkTap: (url, title) => unawaited(_openUrl(url)),
      onCodeCopy: (code) {
        unawaited(Clipboard.setData(ClipboardData(text: code)));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('代码已复制')));
        }
      },
      onImageTap: (url) => unawaited(_openUrl(url)),
      styleSheet: const GptMarkdownStyleSheet(
        latex: LatexStyle(scrollBlockHorizontally: true),
      ),
    );
    return _mdConfig!;
  }

  GptMarkdownThemeData _markdownTheme(BuildContext context) {
    final theme = Theme.of(context);
    if (identical(theme, _mdThemeDataTheme) && _mdThemeData != null) {
      return _mdThemeData!;
    }
    final scheme = theme.colorScheme;
    final base = TextStyle(
      color: scheme.onSurface,
      fontSize: 15.5,
      height: 1.65,
    );
    _mdThemeDataTheme = theme;
    _mdThemeData = GptMarkdownThemeData(
      brightness: theme.brightness,
      h1: base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      h2: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      h3: base.copyWith(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h4: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
      h5: base.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h6: base.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      autoAddDividerLineAfterH1: false,
      linkColor: scheme.primary,
      linkHoverColor: scheme.primary,
      styleSheet: const GptMarkdownStyleSheet(
        latex: LatexStyle(
          textStyle: TextStyle(fontSize: 14.5),
          scrollBlockHorizontally: true,
        ),
        codeBlock: CodeBlockStyle(fontSize: 13, highlightWhileStreaming: false),
        heading: HeadingStyle(padding: EdgeInsets.only(top: 6, bottom: 2)),
        blockSpacing: 10,
      ),
    );
    return _mdThemeData!;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  List<Widget> _assistantSlivers(
    BuildContext context,
    ChatMessage message,
    GptMarkdownConfig config,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final slivers = <Widget>[];
    if (message.attachments.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          sliver: SliverToBoxAdapter(
            child: _AttachmentStrip(attachments: message.attachments),
          ),
        ),
      );
    }
    if (message.text.trim().isEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              message.streaming ? '…' : '',
              style: const TextStyle(fontSize: 15.5, height: 1.65),
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          sliver: SliverGptMarkdown(
            message.text,
            config: config,
            useDollarSignsForLatex: true,
          ),
        ),
      );
    }
    if (message.sources.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < message.sources.length; i++)
                  _sourceChip(context, scheme, i, message.sources[i]),
              ],
            ),
          ),
        ),
      );
    }
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
        sliver: SliverToBoxAdapter(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _action(scheme, Icons.copy_rounded, '复制', () => _copy(message)),
              if (message.role == 'assistant' && !message.streaming)
                _action(
                  scheme,
                  Icons.account_tree_outlined,
                  '分支',
                  () => _branch(message),
                ),
              if (!message.streaming && _hasPair(message))
                _action(
                  scheme,
                  Icons.delete_sweep_outlined,
                  '删问答',
                  () => _delete(message, withPair: true),
                ),
              if (!message.streaming)
                _action(
                  scheme,
                  Icons.delete_outline,
                  '删除',
                  () => _delete(message),
                ),
            ],
          ),
        ),
      ),
    );
    return slivers;
  }

  List<Widget> _buildSlivers(BuildContext context) {
    final config = _markdownConfig(context);
    final slivers = <Widget>[];
    for (final message in widget.conversation.messages) {
      if (message.role == 'user') {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            sliver: SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Appear(
                  key: ValueKey(
                    '${message.at.microsecondsSinceEpoch}-${message.role}',
                  ),
                  child: _MessageTile(
                    message: message,
                    sources: message.sources,
                    onCopy: () => _copy(message),
                    onDeletePair: message.streaming || !_hasPair(message)
                        ? null
                        : () => _delete(message, withPair: true),
                    onDelete: message.streaming ? null : () => _delete(message),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        slivers.addAll(_assistantSlivers(context, message, config));
      }
    }
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        _scheduleFollow();
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            actions: [
              IconButton(
                tooltip: '回答设置',
                icon: const Icon(Icons.tune),
                onPressed: _openOptions,
              ),
              Badge(
                isLabelVisible: conversation.branches.isNotEmpty,
                label: Text('${conversation.branches.length}'),
                child: IconButton(
                  tooltip: '分支',
                  icon: const Icon(Icons.account_tree_outlined),
                  onPressed: _openBranches,
                ),
              ),
              IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(state: widget.state),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: GptMarkdownTheme(
                        gptThemeData: _markdownTheme(context),
                        child: CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 8),
                            ),
                            ..._buildSlivers(context),
                          ],
                        ),
                      ),
                    ),
                    if (!_stick)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'chat-bottom',
                          onPressed: () => _scrollToBottom(),
                          backgroundColor: theme.colorScheme.surface,
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                  ],
                ),
              ),
              Composer(
                onSend: _send,
                importAttachment: widget.state.store.importAttachment,
                onPickModel: _pickModel,
                model: widget.state.config?.model ?? 'deepseek-flash',
                enabled: !widget.state.busy,
                onStop: widget.state.stopGeneration,
                showStop: widget.state.isStreamingIn(conversation),
                webSearch: conversation.webSearch,
                onToggleWebSearch: () => widget.state.setWebSearch(
                  conversation,
                  !conversation.webSearch,
                ),
                notice:
                    widget.state.busy &&
                        !widget.state.isStreamingIn(conversation)
                    ? '另一条对话正在生成，这里的记录不会受影响'
                    : null,
                hint: '向学习助手提问…',
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _needsPlainStream(String text) {
  if (text.length > 1500) return true;
  final displays = RegExp(r'\$\$|\\\[').allMatches(text).length;
  final inline = RegExp(r'\$[^$\n]+?\$|\\\([\s\S]+?\\\)')
      .allMatches(text)
      .length;
  return displays >= 6 || inline >= 24;
}

Widget _messageBody(ChatMessage message) {
  if (message.streaming) {
    return _needsPlainStream(message.text)
        ? LongStreamingText(text: message.text)
        : StreamingText(text: message.text);
  }
  if (message.text.trim().isEmpty) return const SizedBox.shrink();
  return message.text.length > 6000
      ? LongRichMessage(text: message.text)
      : RichMessage(text: message.text);
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    this.sources = const [],
    this.onCopy,
    this.onDelete,
    this.onDeletePair,
    this.onBranch,
  });

  final ChatMessage message;
  final List<WebSource> sources;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onDeletePair;
  final VoidCallback? onBranch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              width: isUser ? null : double.infinity,
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: isUser
                  ? BoxDecoration(
                      color: scheme.primaryContainer.withOpacity(0.55),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.attachments.isNotEmpty) ...[
                    _AttachmentStrip(attachments: message.attachments),
                    if (message.text.trim().isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  _messageBody(message),
                ],
              ),
            ),
          ),
          if (sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < sources.length; i++)
                    _sourceChip(context, scheme, i, sources[i]),
                ],
              ),
            ),
          if (onCopy != null || onDelete != null || onBranch != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCopy != null)
                    _action(scheme, Icons.copy_rounded, '复制', onCopy),
                  if (onBranch != null)
                    _action(
                      scheme,
                      Icons.account_tree_outlined,
                      '分支',
                      onBranch,
                    ),
                  if (onDeletePair != null)
                    _action(
                      scheme,
                      Icons.delete_sweep_outlined,
                      '删问答',
                      onDeletePair,
                    ),
                  if (onDelete != null)
                    _action(scheme, Icons.delete_outline, '删除', onDelete),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _sourceChip(
  BuildContext context,
  ColorScheme scheme,
  int index,
  WebSource source,
) {
  final title = source.title.trim().isEmpty ? source.url : source.title.trim();
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () {
      unawaited(Clipboard.setData(ClipboardData(text: source.url)));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('来源链接已复制')));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Text(
        '[${index + 1}] ${title.length > 28 ? '${title.substring(0, 28)}…' : title}',
        style: TextStyle(
          fontSize: 11.5,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _action(
  ColorScheme scheme,
  IconData icon,
  String label,
  VoidCallback? onTap,
) {
  return TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: scheme.onSurface.withOpacity(0.42),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      minimumSize: const Size(0, 30),
    ),
  );
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments});

  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          if (attachment.isImage && File(attachment.path).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(attachment.path),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: scheme.outlineVariant.withOpacity(0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    attachment.isImage
                        ? Icons.image_outlined
                        : Icons.description_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
