import 'dart:async';

import 'package:flutter/material.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.hint = '提问…',
  });

  final Future<void> Function(String text) onSend;
  final bool enabled;
  final String hint;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _controller.clear();
      await widget.onSend(text);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _focus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.4))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.enabled && !_sending ? () => unawaited(_send()) : null,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_upward),
              tooltip: '发送',
            ),
          ],
        ),
      ),
    );
  }
}
