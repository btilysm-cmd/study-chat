class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? at,
    this.streaming = false,
  }) : at = at ?? DateTime.now();

  final String role;
  String text;
  final DateTime at;
  bool streaming;

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'at': at.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String? ?? 'assistant',
        text: json['text'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num?)?.toInt() ?? 0),
      );
}

class Branch {
  Branch({
    required this.id,
    required this.title,
    required this.anchor,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
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
        createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num?)?.toInt() ?? 0),
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
  })  : createdAt = createdAt ?? DateTime.now(),
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': messages.map((message) => message.toJson()).toList(),
        'branches': branches.map((branch) => branch.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '新对话',
        subject: json['subject'] as String? ?? '未分类',
        createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num?)?.toInt() ?? 0),
        messages: ((json['messages'] as List?) ?? const [])
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList(),
        branches: ((json['branches'] as List?) ?? const [])
            .map((item) => Branch.fromJson(item as Map<String, dynamic>))
            .toList(),
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
  return chars.length <= max ? cleaned : '${String.fromCharCodes(chars.take(max))}…';
}
