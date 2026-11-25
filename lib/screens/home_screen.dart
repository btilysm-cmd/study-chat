import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<void> _showImportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '导入对话',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('从 下载/DSH-Go 导入'),
              subtitle: const Text('自动列出 DSH 打包的对话，不用翻文件管理器'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_scanDownloads(context));
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('选择 JSON 文件'),
              subtitle: const Text('从文件管理器手动选'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_pickFile(context));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureStoragePermission() async {
    final manage = await Permission.manageExternalStorage.status;
    if (manage.isGranted) return true;
    final requested = await Permission.manageExternalStorage.request();
    if (requested.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> _scanDownloads(BuildContext context) async {
    try {
      final allowed = await _ensureStoragePermission();
      if (!allowed) {
        if (!context.mounted) return;
        final goSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('需要读取下载目录'),
            content: const Text('授权「所有文件访问」后，学习问答会直接列出 DSH 打包的对话卡片，不再需要文件管理器。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('手动选择'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('去授权'),
              ),
            ],
          ),
        );
        if (goSettings == true) {
          await openAppSettings();
        } else if (context.mounted) {
          await _pickFile(context);
        }
        return;
      }
      final dirs = <String>{
        '/sdcard/Download/DSH-Go',
        '/storage/emulated/0/Download/DSH-Go',
      };
      final found = <_PackageInfo>[];
      for (final path in dirs) {
        final dir = Directory(path);
        if (!dir.existsSync()) continue;
        for (final entry in dir.listSync()) {
          if (entry is! File || !entry.path.toLowerCase().endsWith('.json')) {
            continue;
          }
          final info = await _readPackage(entry);
          if (info != null) found.add(info);
        }
      }
      found.sort((a, b) => b.modified.compareTo(a.modified));
      if (!context.mounted) return;
      if (found.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载/DSH-Go 里没有对话包，先在 DSH 里点「打包到学习问答」')),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 6, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '选择要导入的对话',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final info in found.take(30))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _packageCard(context, info, () {
                    Navigator.pop(sheetContext);
                    _openPackage(context, info);
                  }),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('扫描失败：$error')));
    }
  }

  Widget _packageCard(
    BuildContext context,
    _PackageInfo info,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withOpacity(0.42),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      info.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: scheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${info.messages.length} 条消息 · ${_formatStamp(info.modified)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStamp(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;
    final hm =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return sameDay ? '今天 $hm' : '${time.month}-${time.day} $hm';
  }

  Future<_PackageInfo?> _readPackage(File file) async {
    try {
      final stat = await file.stat();
      if (stat.size > 8 * 1024 * 1024) return null;
      final bytes = await file.readAsBytes();
      final parsed = _parsePackage(bytes);
      if (parsed == null) return null;
      final firstUser = parsed.$2.firstWhere(
        (message) => message.role == 'user',
        orElse: () => parsed.$2.first,
      );
      return _PackageInfo(
        file: file,
        title: parsed.$1,
        messages: parsed.$2,
        preview: firstUser.text.replaceAll(RegExp(r'\s+'), ' '),
        modified: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  (String, List<ChatMessage>)? _parsePackage(List<int> bytes) {
    final doc = jsonDecode(utf8.decode(bytes));
    if (doc is! Map) return null;
    final rawMessages = doc['messages'];
    if (rawMessages is! List || rawMessages.isEmpty) return null;
    final messages = <ChatMessage>[];
    for (final item in rawMessages) {
      if (item is! Map) continue;
      final role = item['role'] == 'user' ? 'user' : 'assistant';
      final text = (item['text'] ?? item['content'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      messages.add(ChatMessage(role: role, text: text));
    }
    if (messages.isEmpty) return null;
    var title = (doc['title'] ?? doc['name'] ?? '').toString().trim();
    if (title.isEmpty) {
      title = summarizeTitle(
        messages
            .firstWhere(
              (message) => message.role == 'user',
              orElse: () => messages.first,
            )
            .text,
      );
    }
    return (title, messages);
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (files.isEmpty) return;
      final file = files.first;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) throw const FormatException('读不到文件内容');
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('文件太大（上限 8 MB）');
      }
      final parsed = _parsePackage(bytes);
      if (parsed == null) throw const FormatException('对话包里没有可用文本');
      if (!context.mounted) return;
      _importParsed(context, parsed.$1, parsed.$2);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  void _openPackage(BuildContext context, _PackageInfo info) {
    _importParsed(context, info.title, info.messages);
  }

  void _importParsed(
    BuildContext context,
    String title,
    List<ChatMessage> messages,
  ) {
    final conversation = state.importConversation(
      title: title,
      messages: messages,
    );
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
                tooltip: '导入对话',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _showImportSheet(context),
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

class _PackageInfo {
  const _PackageInfo({
    required this.file,
    required this.title,
    required this.messages,
    required this.preview,
    required this.modified,
  });

  final File file;
  final String title;
  final List<ChatMessage> messages;
  final String preview;
  final DateTime modified;
}
