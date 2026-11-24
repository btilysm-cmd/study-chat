import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.importAttachment,
    required this.onPickModel,
    this.model = 'deepseek-flash',
    this.enabled = true,
    this.attachmentsEnabled = true,
    this.showModel = true,
    this.hint = '提问…',
    this.onStop,
    this.showStop = false,
    this.notice,
  });

  final Future<void> Function(String text, List<Attachment> attachments) onSend;
  final Future<Attachment> Function(String path, String name) importAttachment;
  final VoidCallback onPickModel;
  final String model;
  final bool enabled;
  final bool attachmentsEnabled;
  final bool showModel;
  final String hint;
  final VoidCallback? onStop;
  final bool showStop;
  final String? notice;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final List<Attachment> _attachments = [];
  bool _sending = false;
  bool _picking = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || _sending) return;
    setState(() => _sending = true);
    try {
      final outgoing = List<Attachment>.of(_attachments);
      await widget.onSend(text, outgoing);
      if (!mounted) return;
      _controller.clear();
      setState(_attachments.clear);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _focus.requestFocus();
      }
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      if (source == ImageSource.camera) {
        final file = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (file != null) await _add(file.path, file.name);
      } else {
        final files = await _picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1600,
        );
        for (final file in files) {
          await _add(file.path, file.name);
        }
      }
    } catch (error) {
      _toast('选择图片失败：$error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickFiles() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles();
      for (final file in files) {
        final path = file.path;
        if (path != null) await _add(path, file.name);
      }
    } catch (error) {
      _toast('选择文件失败：$error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _add(String path, String name) async {
    final attachment = await widget.importAttachment(path, name);
    if (!mounted) return;
    setState(() => _attachments.add(attachment));
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _attachSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_pick(ImageSource.camera));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('相册'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_pick(ImageSource.gallery));
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('文件（PDF / Word / PPT / 文本）'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_pickFiles());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _modelLabel {
    final model = widget.model;
    if (model == 'deepseek-flash') return 'Flash';
    if (model == 'deepseek-v4-pro') return 'V4 Pro';
    return model;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 4, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: scheme.onSurface.withOpacity(0.55),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.notice!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ),
                    if (widget.onStop != null)
                      TextButton(
                        onPressed: widget.onStop,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('中断'),
                      ),
                  ],
                ),
              ),
            if (_attachments.isNotEmpty)
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: _attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) =>
                      _attachmentTile(_attachments[index], index),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.attachmentsEnabled)
                  IconButton(
                    onPressed: widget.enabled && !_picking
                        ? _attachSheet
                        : null,
                    icon: _picking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    tooltip: '添加图片或文件',
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.showStop
                        ? widget.onStop
                        : widget.enabled && !_sending
                        ? () => unawaited(_send())
                        : null,
                    icon: widget.showStop
                        ? Icon(
                            Icons.stop_rounded,
                            color: scheme.surface,
                            size: 22,
                          )
                        : _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.surface,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward,
                            color: scheme.surface,
                            size: 20,
                          ),
                    tooltip: widget.showStop ? '中断生成' : '发送',
                  ),
                ),
              ],
            ),
            if (widget.showModel)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.enabled ? widget.onPickModel : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _modelLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                            Icon(
                              Icons.expand_less,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'DeepSeek',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(Attachment attachment, int index) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: attachment.isImage
              ? Image.file(File(attachment.path), fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: scheme.primary,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: () => setState(() => _attachments.removeAt(index)),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
