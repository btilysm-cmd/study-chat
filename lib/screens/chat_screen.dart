import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/composer.dart';
import '../widgets/rich_text.dart';
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

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();
  bool _stick = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final near =
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 90;
      if (near != _stick) setState(() => _stick = near);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animate: false),
    );
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
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
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

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        if (_stick) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(animate: false),
          );
        }
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
                    ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      itemCount: conversation.messages.length,
                      itemBuilder: (context, index) {
                        final message = conversation.messages[index];
                        return RepaintBoundary(
                          child: _MessageTile(
                            message: message,
                            onBranch:
                                message.role == 'assistant' &&
                                    !message.streaming
                                ? () => _branch(message)
                                : null,
                          ),
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
                hint: '向学习助手提问…',
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
                  if (message.text.trim().isNotEmpty || message.streaming)
                    RichMessage(
                      text: message.text,
                      streaming: message.streaming,
                    ),
                ],
              ),
            ),
          ),
          if (onBranch != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: onBranch,
                icon: const Icon(Icons.account_tree_outlined, size: 15),
                label: const Text('分支', style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: scheme.onSurface.withOpacity(0.45),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
