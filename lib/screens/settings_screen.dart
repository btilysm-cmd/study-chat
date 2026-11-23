import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _key;
  bool _saving = false;
  bool _obscure = true;

  static const _models = [
    ('deepseek-flash', 'Flash', '快，支持图片和文档'),
    ('deepseek-v4-pro', 'V4 Pro', '更强推理，纯文本'),
  ];

  @override
  void initState() {
    super.initState();
    final config = widget.state.config;
    _baseUrl = TextEditingController(
      text: config?.baseUrl ?? 'https://api.deepseek.com',
    );
    _model = TextEditingController(text: config?.model ?? 'deepseek-flash');
    _key = TextEditingController(text: config?.apiKey ?? '');
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final config = ApiConfig(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _key.text.trim(),
        model: _model.text.trim(),
      );
      if (!config.ready) {
        throw ApiException('三项都要填');
      }
      await widget.state.saveConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixIcon: suffix,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _model.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            '模型',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in _models)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected == entry.$1
                    ? scheme.primaryContainer.withOpacity(0.7)
                    : scheme.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() {
                    _model.text = entry.$1;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Icon(
                          selected == entry.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: selected == entry.$1
                              ? scheme.primary
                              : scheme.onSurface.withOpacity(0.35),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          entry.$1,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withOpacity(0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            decoration: _decoration('API 地址', hint: 'https://api.deepseek.com'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: _decoration('模型名', helper: '也可以手填别的模型名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: _obscure,
            decoration: _decoration(
              'API Key',
              helper: '存在系统 Keystore 里，不会写进安装包',
              suffix: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '接口按 OpenAI 兼容格式调用：POST {地址}/chat/completions（流式），文件走 POST {地址}/files。'
              '选 Flash 时图片会直接读图，PDF / Word / PPT 会先解析再回答。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: scheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
    );
  }
}
