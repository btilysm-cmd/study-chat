import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/composer.dart';
import '../widgets/rich_text.dart';
import 'branch_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.state, required this.conversation});

  final AppState state;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();
  bool _stick = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final near = _scroll.position.maxScrollExtent - _scroll.position.pixels < 90;
      if (near != _stick) setState(() => _stick = near);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _send(String text) async {
    try {
      await widget.state.sendMain(widget.conversation, text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _branch(ChatMessage message) {
    final branch = widget.state.createBranch(widget.conversation, message.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已建立分叉：${branch.title}')),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (conversation.branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('还没有分支。长按或点助手回复下的「分支」即可建立。'),
                ),
              for (final branch in conversation.branches.reversed)
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(branch.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${branch.messages.length} 条问答'),
                  onTap: () {
                    Navigator.pop(context);
                    navigator.push(MaterialPageRoute(
                      builder: (_) => BranchScreen(
                        state: widget.state,
                        conversation: conversation,
                        branch: branch,
                      ),
                    ));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        if (_stick) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
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
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(state: widget.state),
                )),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: conversation.messages.length,
                      itemBuilder: (context, index) {
                        final message = conversation.messages[index];
                        return _MessageTile(
                          message: message,
                          onBranch: message.role == 'assistant' && !message.streaming
                              ? () => _branch(message)
                              : null,
                        );
                      },
                    ),
                    if (!_stick)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'chat-bottom',
                          onPressed: () => _scrollToBottom(),
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                  ],
                ),
              ),
              Composer(
                onSend: _send,
                enabled: !widget.state.busy,
                hint: '提问…',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, this.onBranch});

  final ChatMessage message;
  final VoidCallback? onBranch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? '你' : '助手',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer.withOpacity(0.35)
                  : theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RichMessage(text: message.text, streaming: message.streaming),
          ),
          if (onBranch != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBranch,
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text('分支'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
