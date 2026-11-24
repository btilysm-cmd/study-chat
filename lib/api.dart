import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiConfig {
  ApiConfig({required this.baseUrl, required this.apiKey, required this.model});

  String baseUrl;
  String apiKey;
  String model;

  bool get ready =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  String get root => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
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
    required List<Map<String, dynamic>> messages,
    required String system,
    String? reasoningEffort,
    void Function(String reasoning)? onReasoning,
  }) async* {
    final uri = Uri.parse('${config.root}/chat/completions');
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
        if (reasoningEffort != null && reasoningEffort.isNotEmpty)
          'reasoning_effort': reasoningEffort,
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw ApiException(_errorText(response.statusCode, body));
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
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
      final reasoning = delta?['reasoning_content'] ?? delta?['reasoning'];
      if (reasoning is String && reasoning.isNotEmpty) {
        onReasoning?.call(reasoning);
      }
      final content = delta?['content'];
      if (content is String && content.isNotEmpty) yield content;
    }
  }

  Future<List<WebSource>> searchWeb({
    required ApiConfig config,
    required String query,
    int count = 5,
  }) async {
    final uri = Uri.parse('${config.root}/v1/tools/search');
    final response = await _client
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer ${config.apiKey.trim()}',
          },
          body: jsonEncode({
            'query': query,
            'count': count,
            'ori_question': query.length > 128
                ? query.substring(0, 128)
                : query,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw ApiException(_errorText(response.statusCode, response.body));
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final raw = json['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return WebSource(
            title: (map['title'] as String? ?? '').trim(),
            url: (map['url'] as String? ?? '').trim(),
            summary:
                (map['summary'] as String? ?? map['snippet'] as String? ?? '')
                    .trim(),
            date: (map['date'] as String? ?? '').trim(),
          );
        })
        .where((source) => source.url.isNotEmpty)
        .toList();
  }

  Future<String> uploadDocument({
    required ApiConfig config,
    required String path,
    required String name,
  }) async {
    final uri = Uri.parse('${config.root}/files');
    final request = http.MultipartRequest('POST', uri)
      ..headers['authorization'] = 'Bearer ${config.apiKey.trim()}'
      ..fields['purpose'] = _purposeFor(name);
    request.files.add(
      await http.MultipartFile.fromPath('file', path, filename: name),
    );

    final response = await _client
        .send(request)
        .timeout(const Duration(minutes: 4));
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw ApiException(_errorText(response.statusCode, body));
    }
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null || id.isEmpty) throw const FormatException();
      return id;
    } catch (_) {
      throw ApiException('文件上传返回无法解析');
    }
  }

  static String _purposeFor(String name) {
    final lower = name.toLowerCase();
    const userData = [
      '.txt',
      '.md',
      '.csv',
      '.json',
      '.xlsx',
      '.xls',
      '.epub',
      '.mobi',
    ];
    if (userData.any(lower.endsWith)) return 'user_data';
    return 'text_recognition';
  }

  static String _errorText(int status, String body) {
    var detail = body.trim();
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map && error['message'] is String) {
        detail = error['message'] as String;
      }
    } catch (_) {
      // Keep the raw body when it is not JSON.
    }
    if (detail.length > 300) detail = detail.substring(0, 300);
    return 'HTTP $status：$detail';
  }
}

Future<String> fileToDataUrl(String path, String mime) async {
  final bytes = await File(path).readAsBytes();
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
