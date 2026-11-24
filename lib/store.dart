import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'models.dart';

class Store {
  static const _apiKeyName = 'study_chat_api_key';
  static const defaultModel = 'deepseek-flash';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<File> _dataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/study_chat.json');
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _dataFile();
      if (!file.existsSync()) return {};
      final text = await file.readAsString();
      if (text.trim().isEmpty) return {};
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> doc) async {
    final file = await _dataFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(doc));
    await temp.rename(file.path);
  }

  Future<ApiConfig?> loadConfig() async {
    final doc = await _read();
    final config = doc['config'] as Map<String, dynamic>?;
    String key = '';
    try {
      key = await _secure.read(key: _apiKeyName) ?? '';
    } catch (_) {
      key = '';
    }
    if (config == null && key.isEmpty) return null;
    var model = config?['model'] as String? ?? defaultModel;
    if (model == 'deepseek-chat' || model == 'deepseek-reasoner')
      model = defaultModel;
    return ApiConfig(
      baseUrl: config?['baseUrl'] as String? ?? 'https://api.deepseek.com',
      apiKey: key,
      model: model,
    );
  }

  Future<void> saveConfig(ApiConfig config) async {
    final doc = await _read();
    doc['config'] = {'baseUrl': config.baseUrl, 'model': config.model};
    await _write(doc);
    try {
      await _secure.write(key: _apiKeyName, value: config.apiKey);
    } catch (_) {
      // Keystore may be unavailable on some devices; the UI reports it.
    }
  }

  Future<List<Conversation>> loadConversations() async {
    final doc = await _read();
    final list = doc['conversations'] as List? ?? const [];
    final result = <Conversation>[];
    for (final item in list.whereType<Map>()) {
      try {
        result.add(Conversation.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // One broken conversation should not take the others down.
      }
    }
    return result;
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final doc = await _read();
    doc['conversations'] = conversations.map((item) => item.toJson()).toList();
    await _write(doc);
  }

  Future<Attachment> importAttachment(String sourcePath, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/attachments');
    if (!target.existsSync()) await target.create(recursive: true);
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path =
        '${target.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await File(sourcePath).copy(path);
    return Attachment(path: path, name: name, mime: mimeForName(name));
  }
}
