import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/composer.dart';
import '../widgets/rich_text.dart';

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

class _BranchScreenState extends State<BranchScreen> {
  final _scroll = ScrollController();
  bool _stick = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final near = _scroll.position.maxScrollExtent - _scroll.position.pixels < 90;
      if (near != _stick) setState(() => _stick = near);
    });
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
      await widget.state.sendBranch(widget.conversation, widget.branch, text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        if (_stick) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(branch.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Text(
                              '原对话片段 · ${branch.anchor.runes.length} 字',
                              style: const TextStyle(fontSize: 13),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            children: [
                              Container(
                                width: double.infinity,
                                child: RichMessage(text: branch.anchor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final message in branch.messages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: message.role == 'user'
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.role == 'user' ? '你' : '助手',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: message.role == 'user'
                                        ? theme.colorScheme.primaryContainer.withOpacity(0.35)
                                        : theme.colorScheme.surface,
                                    border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: RichMessage(text: message.text, streaming: message.streaming),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (!_stick)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'branch-bottom',
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
                hint: '在这条分支里继续问…',
              ),
            ],
          ),
        );
      },
    );
  }
}
