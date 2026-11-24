import 'dart:io';

String mimeForName(String name) {
  final lower = name.toLowerCase();
  int dot = lower.lastIndexOf('.');
  final ext = dot >= 0 ? lower.substring(dot + 1) : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'txt':
    case 'md':
    case 'csv':
    case 'json':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}

bool isTextName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.txt') ||
      lower.endsWith('.md') ||
      lower.endsWith('.csv') ||
      lower.endsWith('.json') ||
      lower.endsWith('.dart') ||
      lower.endsWith('.py') ||
      lower.endsWith('.js') ||
      lower.endsWith('.ts') ||
      lower.endsWith('.java') ||
      lower.endsWith('.c') ||
      lower.endsWith('.cpp') ||
      lower.endsWith('.h') ||
      lower.endsWith('.tex') ||
      lower.endsWith('.log');
}

class Attachment {
  Attachment({
    required this.path,
    required this.name,
    required this.mime,
    this.fileId,
  });

  final String path;
  final String name;
  final String mime;
  String? fileId;

  bool get isImage => mime.startsWith('image/');
  bool get isText => isTextName(name);

  File get file => File(path);

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'mime': mime,
    if (fileId != null) 'fileId': fileId,
  };

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    path: json['path'] as String? ?? '',
    name: json['name'] as String? ?? '附件',
    mime: json['mime'] as String? ?? 'application/octet-stream',
    fileId: json['fileId'] as String?,
  );
}

class WebSource {
  WebSource({
    required this.title,
    required this.url,
    this.summary = '',
    this.date = '',
  });

  final String title;
  final String url;
  final String summary;
  final String date;

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    if (summary.isNotEmpty) 'summary': summary,
    if (date.isNotEmpty) 'date': date,
  };

  factory WebSource.fromJson(Map<String, dynamic> json) => WebSource(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    date: json['date'] as String? ?? '',
  );
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? at,
    this.streaming = false,
    List<Attachment>? attachments,
    List<WebSource>? sources,
  }) : at = at ?? DateTime.now(),
       attachments = attachments ?? [],
       sources = sources ?? [];

  final String role;
  String text;
  final DateTime at;
  bool streaming;
  List<Attachment> attachments;
  List<WebSource> sources;

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'at': at.millisecondsSinceEpoch,
    'attachments': attachments.map((item) => item.toJson()).toList(),
    if (sources.isNotEmpty)
      'sources': sources.map((item) => item.toJson()).toList(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String? ?? 'assistant',
    text: json['text'] as String? ?? '',
    at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num?)?.toInt() ?? 0),
    attachments: ((json['attachments'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Attachment.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    sources: ((json['sources'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => WebSource.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );
}

class Branch {
  Branch({
    required this.id,
    required this.title,
    required this.anchor,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  }) : createdAt = createdAt ?? DateTime.now(),
       messages = messages ?? [];

  final String id;
  String title;
  final String anchor;
  final DateTime createdAt;
  List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'anchor': anchor,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '分支',
    anchor: json['anchor'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
    messages: ((json['messages'] as List?) ?? const [])
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class Conversation {
  Conversation({
    required this.id,
    required this.title,
    this.subject = '未分类',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    List<Branch>? branches,
    this.answerLength = 'medium',
    this.thinking = 'high',
    this.webSearch = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       messages = messages ?? [],
       branches = branches ?? [];

  final String id;
  String title;
  String subject;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ChatMessage> messages;
  List<Branch> branches;
  String answerLength;
  String thinking;
  bool webSearch;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'messages': messages.map((message) => message.toJson()).toList(),
    'branches': branches.map((branch) => branch.toJson()).toList(),
    'answerLength': answerLength,
    'thinking': thinking,
    'webSearch': webSearch,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '新对话',
    subject: json['subject'] as String? ?? '未分类',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['updatedAt'] as num?)?.toInt() ?? 0,
    ),
    messages: ((json['messages'] as List?) ?? const [])
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList(),
    branches: ((json['branches'] as List?) ?? const [])
        .map((item) => Branch.fromJson(item as Map<String, dynamic>))
        .toList(),
    answerLength: json['answerLength'] as String? ?? 'medium',
    thinking: json['thinking'] as String? ?? 'high',
    webSearch: json['webSearch'] as bool? ?? false,
  );
}

String shortId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String summarizeTitle(String text, {int max = 20}) {
  final line = text
      .split('\n')
      .map((item) => item.trim())
      .firstWhere((item) => item.isNotEmpty, orElse: () => '');
  final cleaned = line.replaceAll(RegExp(r'[`*#>]'), '').trim();
  final chars = cleaned.runes.toList();
  if (chars.isEmpty) return '新对话';
  return chars.length <= max
      ? cleaned
      : '${String.fromCharCodes(chars.take(max))}…';
}
