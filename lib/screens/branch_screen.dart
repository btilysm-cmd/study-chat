import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/composer.dart';
import '../widgets/markdown_theme.dart';

class BranchScreen extends StatefulWidget {
  const BranchScreen({
    super.key,
    required this.state,
    required this.conversation,
    required this.branch,
  });

  final AppState state;
  final Conversation conversation;
  final Branch branch;

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _follow;
  bool _stick = true;
  bool _dragging = false;
  bool _initialized = false;
  int _idleTicks = 0;
  GptMarkdownConfig? _mdConfig;
  ThemeData? _mdTheme;

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

  Future<void> _send(String text, List<Attachment> _) async {
    try {
      await widget.state.sendBranch(widget.conversation, widget.branch, text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  GptMarkdownConfig _markdownConfig(BuildContext context) {
    final theme = Theme.of(context);
    if (identical(theme, _mdTheme) && _mdConfig != null) return _mdConfig!;
    _mdTheme = theme;
    _mdConfig = studyMarkdownConfig(
      context,
      onLinkTap: (url) => unawaited(_openUrl(url)),
      onImageTap: (url) => unawaited(_openUrl(url)),
      onCodeCopy: (code) {
        unawaited(Clipboard.setData(ClipboardData(text: code)));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('代码已复制')));
        }
      },
    );
    return _mdConfig!;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        _scheduleFollow();
        final config = _markdownConfig(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              branch.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: StudyMarkdownTheme(
                        child: CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                              sliver: SliverToBoxAdapter(
                                child: _anchorCard(branch, scheme),
                              ),
                            ),
                            for (final message in branch.messages)
                              ..._messageSlivers(message, config),
                          ],
                        ),
                      ),
                    ),
                    if (!_stick)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'branch-bottom',
                          onPressed: _scrollToBottom,
                          backgroundColor: scheme.surface,
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                  ],
                ),
              ),
              Composer(
                onSend: _send,
                importAttachment: widget.state.store.importAttachment,
                onPickModel: () {},
                attachmentsEnabled: false,
                showModel: false,
                enabled: !widget.state.busy,
                onStop: widget.state.stopGeneration,
                showStop: widget.state.isStreamingIn(widget.conversation),
                notice:
                    widget.state.busy &&
                        !widget.state.isStreamingIn(widget.conversation)
                    ? '另一条对话正在生成'
                    : null,
                hint: '在这条分支里继续问…',
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _messageSlivers(ChatMessage message, GptMarkdownConfig config) {
    if (message.role == 'user') {
      final scheme = Theme.of(context).colorScheme;
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withOpacity(0.55),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(fontSize: 15.5, height: 1.6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ];
    }
    if (message.text.trim().isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          sliver: SliverToBoxAdapter(
            child: Text(
              message.streaming ? '…' : '',
              style: const TextStyle(fontSize: 15.5, height: 1.65),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        sliver: SliverGptMarkdown(
          message.text,
          config: config,
          useDollarSignsForLatex: true,
        ),
      ),
    ];
  }

  Widget _anchorCard(Branch branch, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_border, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                '原对话片段 · ${branch.anchor.runes.length} 字',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GptMarkdown(
            branch.anchor,
            useDollarSignsForLatex: true,
            onLinkTap: (url, title) => unawaited(_openUrl(url)),
          ),
        ],
      ),
    );
  }
}
