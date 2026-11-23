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

  @override
  void initState() {
    super.initState();
    final config = widget.state.config;
    _baseUrl = TextEditingController(text: config?.baseUrl ?? 'https://api.deepseek.com');
    _model = TextEditingController(text: config?.model ?? 'deepseek-chat');
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              hintText: 'https://api.deepseek.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型',
              hintText: 'deepseek-chat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _key,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API Key',
              helperText: '存在系统 Keystore 里，不会写进 APK',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '接口按 OpenAI 兼容格式调用：POST {地址}/chat/completions，stream=true。'
                'DeepSeek 官方地址就是 https://api.deepseek.com。',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
    );
  }
}
