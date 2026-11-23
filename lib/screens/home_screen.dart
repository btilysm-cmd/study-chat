import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  void _open(BuildContext context, Conversation conversation) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(state: state, conversation: conversation),
    ));
  }

  Future<void> _create(BuildContext context) async {
    final conversation = state.createConversation();
    await state.store.saveConversations(state.conversations);
    if (!context.mounted) return;
    _open(context, conversation);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final theme = Theme.of(context);
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
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(state: state),
                )),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('新对话'),
          ),
          body: conversations.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  children: [
                    if (state.config?.ready != true) _configBanner(context),
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                        child: Text(
                          entry.key,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final conversation in entry.value)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${_formatTime(conversation.updatedAt)}'
                              '${conversation.branches.isEmpty ? '' : ' · ${conversation.branches.length} 个分支'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(context, conversation),
                            onLongPress: () => _confirmDelete(context, conversation),
                          ),
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text('开始一次学习提问', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '长按助手的回复可以建立分支，分支里的追问不会出现在主对话里。',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            if (state.config?.ready != true) _configBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _configBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
      child: ListTile(
        leading: const Icon(Icons.vpn_key_outlined),
        title: const Text('还没有配置 API'),
        subtitle: const Text('填地址、Key 和模型后才能提问'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SettingsScreen(state: state),
        )),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Conversation conversation) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('删除「${conversation.title}」？分支也会一起删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await state.deleteConversation(conversation);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}-${time.day}';
  }
}
