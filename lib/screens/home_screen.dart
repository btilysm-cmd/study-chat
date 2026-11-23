import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  void _open(BuildContext context, Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(state: state, conversation: conversation),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final conversation = state.createConversation();
    await state.store.saveConversations(state.conversations);
    if (!context.mounted) return;
    _open(context, conversation);
  }

  void _settings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SettingsScreen(state: state)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final conversations = state.conversations;
        final grouped = <String, List<Conversation>>{};
        for (final conversation in conversations) {
          grouped.putIfAbsent(conversation.subject, () => []).add(conversation);
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('学习问答'),
            actions: [
              IconButton(
                tooltip: '新对话',
                onPressed: () => _create(context),
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: scheme.onSurface, size: 22),
                ),
              ),
              IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.tune),
                onPressed: () => _settings(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: conversations.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    if (state.config?.ready != true) _configBanner(context),
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                        child: Row(
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface.withOpacity(0.45),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                color: scheme.outlineVariant.withOpacity(0.6),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final conversation in entry.value) ...[
                        _ConversationTile(
                          conversation: conversation,
                          onTap: () => _open(context, conversation),
                          onLongPress: () =>
                              _confirmDelete(context, conversation),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_library_outlined,
                size: 38,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '开始一次学习提问。',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '可以拍照、传文档；长按或点助手回复下的「分支」，\n把不懂的地方单独拎出来追问。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 26),
            if (state.config?.ready != true) _configBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _configBanner(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(Icons.vpn_key_outlined, color: scheme.onSurface),
        title: const Text(
          '还没有配置 API',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('填地址、Key 和模型后才能提问'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _settings(context),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Conversation conversation,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('删除「${conversation.title}」？分支也会一起删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await state.deleteConversation(conversation);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBranches = conversation.branches.isNotEmpty;
    return Material(
      color: scheme.surfaceContainerHighest.withOpacity(0.45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatTime(conversation.updatedAt)}'
                      '${hasBranches ? ' · ${conversation.branches.length} 个分支' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}-${time.day}';
  }
}
