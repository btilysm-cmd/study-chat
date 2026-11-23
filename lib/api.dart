import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiConfig {
  ApiConfig({required this.baseUrl, required this.apiKey, required this.model});

  String baseUrl;
  String apiKey;
  String model;

  bool get ready => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty && model.trim().isNotEmpty;
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client = http.Client();

  Stream<String> streamChat({
    required ApiConfig config,
    required List<Map<String, String>> messages,
    required String system,
  }) async* {
    final root = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$root/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'content-type': 'application/json',
        'authorization': 'Bearer ${config.apiKey.trim()}',
      })
      ..body = jsonEncode({
        'model': config.model.trim(),
        'messages': [
          {'role': 'system', 'content': system},
          ...messages,
        ],
        'stream': true,
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw ApiException('HTTP ${response.statusCode}：${body.length > 200 ? body.substring(0, 200) : body}');
    }

    final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') break;
      Map<String, dynamic> json;
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final delta = (choices.first as Map)['delta'] as Map?;
      final content = delta?['content'];
      if (content is String && content.isNotEmpty) yield content;
    }
  }
}
