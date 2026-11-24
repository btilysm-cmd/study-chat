import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/appear.dart';
import '../widgets/composer.dart';
import '../widgets/rich_text.dart';
import '../widgets/streaming_text.dart';

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

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final scheme = Theme.of(context).colorScheme;
    final messages = branch.messages;
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        _scheduleFollow();
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
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return _anchorCard(branch, scheme);
                          final message = messages[index - 1];
                          return Appear(
                            key: ValueKey(
                              '${message.at.microsecondsSinceEpoch}-${message.role}',
                            ),
                            child: _messageTile(message, scheme),
                          );
                        },
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
                hint: '在这条分支里继续问…',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _anchorCard(Branch branch, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
            RichMessage(text: branch.anchor),
          ],
        ),
      ),
    );
  }

  Widget _messageTile(ChatMessage message, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: RepaintBoundary(
        child: Align(
          alignment: message.role == 'user'
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              width: message.role == 'user' ? null : double.infinity,
              padding: message.role == 'user'
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: message.role == 'user'
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.topStart,
                  children: [...previous, if (current != null) current],
                ),
                child: message.streaming
                    ? StreamingText(
                        key: const ValueKey('streaming'),
                        text: message.text,
                      )
                    : RichMessage(
                        key: const ValueKey('final'),
                        text: message.text,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
