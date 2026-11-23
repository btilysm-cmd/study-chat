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
      final near =
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 90;
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
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        if (_stick) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(animate: false),
          );
        }
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
                    ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: scheme.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.bookmark_border,
                                    size: 15,
                                    color: scheme.primary,
                                  ),
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
                        const SizedBox(height: 16),
                        for (final message in branch.messages)
                          RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Align(
                                alignment: message.role == 'user'
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 680,
                                  ),
                                  child: Container(
                                    width: message.role == 'user'
                                        ? null
                                        : double.infinity,
                                    padding: message.role == 'user'
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          )
                                        : const EdgeInsets.symmetric(
                                            horizontal: 2,
                                            vertical: 2,
                                          ),
                                    decoration: message.role == 'user'
                                        ? BoxDecoration(
                                            color: scheme.primaryContainer
                                                .withOpacity(0.55),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(20),
                                                  topRight: Radius.circular(20),
                                                  bottomLeft: Radius.circular(
                                                    20,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    6,
                                                  ),
                                                ),
                                          )
                                        : null,
                                    child: RichMessage(
                                      text: message.text,
                                      streaming: message.streaming,
                                    ),
                                  ),
                                ),
                              ),
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
}
