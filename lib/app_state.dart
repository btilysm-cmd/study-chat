import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';
import 'store.dart';

const _mainSystem =
    r'你是一个学习问答助手。回答要准确、简洁，先给结论再给推导；'
    r'数学公式用 LaTeX（行内 $...$，独立公式 $$...$$），代码用围栏代码块。'
    r'用户可能附带图片或文档，请先确认题目内容再作答。';

const _branchSystem =
    '你在一条分支追问里回答。分支锚点是用户选中过的原回答，是这段对话里唯一的共识；'
    '看不到主对话的完整上下文，不要凭空假设。回答优先精确、可复核；公式用 LaTeX，代码用围栏代码块。';

class AppState extends ChangeNotifier {
  AppState(this.store);

  final Store store;
  final ApiClient api = ApiClient();

  ApiConfig? config;
  List<Conversation> conversations = [];
  bool ready = false;
  bool busy = false;

  Timer? _flush;

  Future<void> init() async {
    config = await store.loadConfig();
    conversations = await store.loadConversations();
    ready = true;
    notifyListeners();
  }

  Future<void> saveConfig(ApiConfig next) async {
    config = next;
    await store.saveConfig(next);
    notifyListeners();
  }

  Future<void> switchModel(String model) async {
    final current = config;
    if (current == null) return;
    current.model = model;
    await store.saveConfig(current);
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await store.saveConversations(conversations);
    } catch (_) {
      // Keeping the in-memory state is better than dropping the conversation.
    }
  }

  Conversation createConversation({String subject = '未分类'}) {
    final now = DateTime.now();
    final conversation = Conversation(
      id: shortId(),
      title: '新对话',
      subject: subject,
      createdAt: now,
      updatedAt: now,
    );
    conversations.insert(0, conversation);
    notifyListeners();
    return conversation;
  }

  void renameFromFirstQuestion(Conversation conversation, String question) {
    if (conversation.title == '新对话')
      conversation.title = summarizeTitle(question);
  }

  Branch createBranch(Conversation conversation, String anchor) {
    final text = anchor.length > 2500
        ? anchor.substring(anchor.length - 2500)
        : anchor;
    final branch = Branch(
      id: shortId(),
      title: summarizeTitle(text, max: 18),
      anchor: text,
    );
    conversation.branches.add(branch);
    conversation.updatedAt = DateTime.now();
    notifyListeners();
    unawaited(_persist());
    return branch;
  }

  void _tick() {
    if (_flush != null) return;
    _flush = Timer(const Duration(milliseconds: 80), () {
      _flush = null;
      notifyListeners();
    });
  }

  Future<void> sendMain(
    Conversation conversation,
    String text, {
    List<Attachment> attachments = const [],
  }) async {
    final question = text.trim();
    if ((question.isEmpty && attachments.isEmpty) || busy) return;
    final current = config;
    if (current == null || !current.ready)
      throw ApiException('先在设置里填 API 地址、Key 和模型');

    conversation.messages.add(
      ChatMessage(role: 'user', text: question, attachments: attachments),
    );
    renameFromFirstQuestion(
      conversation,
      question.isEmpty ? '图片/文件提问' : question,
    );
    final live = ChatMessage(role: 'assistant', text: '', streaming: true);
    conversation.messages.add(live);
    conversation.updatedAt = DateTime.now();
    busy = true;
    live.text = attachments.isEmpty ? '' : '正在准备附件…';
    notifyListeners();

    try {
      final history = await _apiHistory(current, conversation);
      live.text = '';
      notifyListeners();
      final system =
          '$_mainSystem\n\n${_lengthHint(conversation.answerLength)}';
      await for (final delta in api.streamChat(
        config: current,
        messages: history,
        system: system,
        reasoningEffort: conversation.thinking,
      )) {
        live.text += delta;
        _tick();
      }
    } catch (error) {
      final message = '生成失败：$error';
      final current = live.text.trim();
      live.text = current.isEmpty || current == '正在准备附件…'
          ? message
          : '$current\n\n[$message]';
    } finally {
      live.streaming = false;
      busy = false;
      _flush?.cancel();
      _flush = null;
      notifyListeners();
      unawaited(_persist());
    }
  }

  Future<List<Map<String, dynamic>>> _apiHistory(
    ApiConfig config,
    Conversation conversation,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final message in conversation.messages) {
      if (message.streaming) continue;
      if (message.attachments.isEmpty) {
        result.add({'role': message.role, 'content': message.text});
        continue;
      }
      final parts = <Map<String, dynamic>>[];
      if (message.text.trim().isNotEmpty) {
        parts.add({'type': 'text', 'text': message.text.trim()});
      }
      for (final attachment in message.attachments) {
        if (!File(attachment.path).existsSync()) {
          parts.add({'type': 'text', 'text': '[附件已丢失：${attachment.name}]'});
          continue;
        }
        if (attachment.isImage) {
          parts.add({
            'type': 'image_url',
            'image_url': {
              'url': await fileToDataUrl(attachment.path, attachment.mime),
            },
          });
        } else if (attachment.isText) {
          final file = File(attachment.path);
          var content = await file.readAsString();
          if (content.length > 60000) {
            content = '${content.substring(0, 60000)}\n\n[已截断]';
          }
          parts.add({
            'type': 'text',
            'text': '【附件：${attachment.name}】\n$content',
          });
        } else {
          var id = attachment.fileId;
          if (id == null || id.isEmpty) {
            id = await api.uploadDocument(
              config: config,
              path: attachment.path,
              name: attachment.name,
            );
            attachment.fileId = id;
          }
          parts.add({'type': 'file', 'file_id': id});
        }
      }
      result.add({'role': message.role, 'content': parts});
    }
    return result;
  }

  Future<void> sendBranch(
    Conversation conversation,
    Branch branch,
    String text,
  ) async {
    final question = text.trim();
    if (question.isEmpty || busy) return;
    final current = config;
    if (current == null || !current.ready)
      throw ApiException('先在设置里填 API 地址、Key 和模型');

    final prior = branch.messages
        .where((message) => !message.streaming)
        .map(
          (message) =>
              '${message.role == 'assistant' ? '助手' : '用户'}：${message.text}',
        )
        .join('\n');
    branch.messages.add(ChatMessage(role: 'user', text: question));
    final live = ChatMessage(role: 'assistant', text: '', streaming: true);
    branch.messages.add(live);
    conversation.updatedAt = DateTime.now();
    busy = true;
    notifyListeners();

    final prompt = [
      '【锚点原文】${branch.anchor}',
      if (prior.isNotEmpty) '【之前的问答】\n$prior',
      '【当前问题】$question',
      '请直接回答当前问题。',
    ].join('\n\n');

    try {
      await for (final delta in api.streamChat(
        config: current,
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        system: '$_branchSystem\n\n${_lengthHint(conversation.answerLength)}',
        reasoningEffort: conversation.thinking,
      )) {
        live.text += delta;
        _tick();
      }
    } catch (error) {
      final message = '生成失败：$error';
      final current = live.text.trim();
      live.text = current.isEmpty || current == '正在准备附件…'
          ? message
          : '$current\n\n[$message]';
    } finally {
      live.streaming = false;
      busy = false;
      _flush?.cancel();
      _flush = null;
      notifyListeners();
      unawaited(_persist());
    }
  }

  void setAnswerLength(Conversation conversation, String value) {
    conversation.answerLength = value;
    notifyListeners();
    unawaited(_persist());
  }

  void setThinking(Conversation conversation, String value) {
    conversation.thinking = value;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> deleteConversation(Conversation conversation) async {
    conversations.remove(conversation);
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    _flush?.cancel();
    super.dispose();
  }
}
