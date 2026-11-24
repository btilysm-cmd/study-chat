import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';
import 'pdf_pages.dart';
import 'store.dart';

const _mainSystem =
    r'你是一个学习问答助手。回答要准确、简洁，先给结论再给推导；'
    r'数学公式用 LaTeX（行内 $...$，独立公式 $$...$$），代码用围栏代码块。'
    r'用户可能附带图片或文档，请先确认题目内容再作答。';

const _branchSystem =
    '你在一条分支追问里回答。分支锚点是用户选中过的原回答，是这段对话里唯一的共识；'
    '看不到主对话的完整上下文，不要凭空假设。回答优先精确、可复核；公式用 LaTeX，代码用围栏代码块。';

String _lengthHint(String value) {
  return switch (value) {
    'short' => '回答长度：短。只给结论和关键步骤，省略铺垫，尽量控制在 300 字以内。',
    'long' => '回答长度：长。给出完整推导、多种角度和必要例子，充分展开。',
    _ => '回答长度：中。先给结论，再给必要推导和一个例子，尽量控制在 800 字以内。',
  };
}

class AppState extends ChangeNotifier {
  AppState(this.store);

  final Store store;
  final ApiClient api = ApiClient();

  ApiConfig? config;
  List<Conversation> conversations = [];
  bool ready = false;
  bool busy = false;
  String? streamingConversationId;

  Timer? _flush;
  StreamSubscription<String>? _streamSub;
  Completer<void>? _streamDone;
  bool _streamCancelled = false;

  bool isStreamingIn(Conversation conversation) =>
      streamingConversationId == conversation.id;

  Future<void> init() async {
    config = await store.loadConfig();
    conversations = await store.loadConversations();
    // A stream cannot survive a restart; don't leave half answers stuck in
    // the plain-text streaming state.
    for (final conversation in conversations) {
      conversation.messages.removeWhere(
        (message) => message.streaming && message.text.trim().isEmpty,
      );
      for (final message in conversation.messages) {
        message.streaming = false;
      }
      for (final branch in conversation.branches) {
        branch.messages.removeWhere(
          (message) => message.streaming && message.text.trim().isEmpty,
        );
        for (final message in branch.messages) {
          message.streaming = false;
        }
      }
    }
    ready = true;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> stopGeneration() async {
    if (!busy) return;
    _streamCancelled = true;
    final sub = _streamSub;
    _streamSub = null;
    try {
      await sub?.cancel();
    } catch (_) {
      // The socket may already be gone; the finally block still cleans up.
    }
    final done = _streamDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  void deleteMessage(
    Conversation conversation,
    ChatMessage message, {
    bool withPair = false,
  }) {
    if (message.streaming) return;
    final index = conversation.messages.indexOf(message);
    if (index < 0) return;
    final removed = <ChatMessage>{message};
    if (withPair) {
      if (message.role == 'user' && index + 1 < conversation.messages.length) {
        final next = conversation.messages[index + 1];
        if (next.role == 'assistant') removed.add(next);
      } else if (message.role == 'assistant' && index > 0) {
        final prev = conversation.messages[index - 1];
        if (prev.role == 'user') removed.add(prev);
      }
    }
    conversation.messages.removeWhere(removed.contains);
    conversation.updatedAt = DateTime.now();
    notifyListeners();
    unawaited(_persist());
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
    streamingConversationId = conversation.id;
    _streamCancelled = false;
    final done = Completer<void>();
    _streamDone = done;
    live.text = attachments.isEmpty ? '' : '正在准备附件…';
    notifyListeners();

    try {
      final history = await _apiHistory(current, conversation);
      if (_streamCancelled) {
        if (live.text.trim().isNotEmpty) {
          live.text = '${live.text.trim()}\n\n[已中断]';
        } else {
          live.text = '[已中断]';
        }
        return;
      }
      live.text = '';
      notifyListeners();
      final system =
          '$_mainSystem\n\n${_lengthHint(conversation.answerLength)}';
      final stream = api.streamChat(
        config: current,
        messages: history,
        system: system,
        reasoningEffort: conversation.thinking,
      );
      _streamSub = stream.listen(
        (delta) {
          live.text += delta;
          _tick();
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future;
    } catch (error) {
      if (_streamCancelled) {
        if (live.text.trim().isNotEmpty) {
          live.text = '${live.text.trim()}\n\n[已中断]';
        } else {
          live.text = '[已中断]';
        }
      } else {
        final message = '生成失败：$error';
        final current = live.text.trim();
        live.text = current.isEmpty || current == '正在准备附件…'
            ? message
            : '$current\n\n[$message]';
      }
    } finally {
      live.streaming = false;
      busy = false;
      streamingConversationId = null;
      _streamSub = null;
      _streamDone = null;
      _streamCancelled = false;
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
        } else if (attachment.mime == 'application/pdf') {
          final plan = await PdfImagePlan.prepare(attachment.path);
          // Scanned documents have no text layer; don't waste an upload.
          if (!plan.allPagesAreImages || plan.pages.isEmpty) {
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
          if (plan.pages.isNotEmpty) {
            parts.add({
              'type': 'text',
              'text':
                  '【PDF：共 ${plan.pageCount} 页，'
                  '其中 ${plan.imagePageCount} 页为图片/扫描页，'
                  '已读取图片页：${plan.pages.map((page) => page.page).join('、')}'
                  '${plan.imagePageCount > plan.pages.length ? '（只读取了前 ${plan.pages.length} 页）' : ''}】',
            });
            for (final page in plan.pages) {
              parts.add({'type': 'text', 'text': '【PDF 第 ${page.page} 页】'});
              parts.add({
                'type': 'image_url',
                'image_url': {
                  'url': await fileToDataUrl(page.path, 'image/jpeg'),
                },
              });
            }
          }
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
    streamingConversationId = conversation.id;
    _streamCancelled = false;
    final done = Completer<void>();
    _streamDone = done;
    notifyListeners();

    final prompt = [
      '【锚点原文】${branch.anchor}',
      if (prior.isNotEmpty) '【之前的问答】\n$prior',
      '【当前问题】$question',
      '请直接回答当前问题。',
    ].join('\n\n');

    try {
      final stream = api.streamChat(
        config: current,
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        system: '$_branchSystem\n\n${_lengthHint(conversation.answerLength)}',
        reasoningEffort: conversation.thinking,
      );
      _streamSub = stream.listen(
        (delta) {
          live.text += delta;
          _tick();
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future;
    } catch (error) {
      if (_streamCancelled) {
        live.text = live.text.trim().isEmpty
            ? '[已中断]'
            : '${live.text.trim()}\n\n[已中断]';
      } else {
        final message = '生成失败：$error';
        final current = live.text.trim();
        live.text = current.isEmpty || current == '正在准备附件…'
            ? message
            : '$current\n\n[$message]';
      }
    } finally {
      live.streaming = false;
      busy = false;
      streamingConversationId = null;
      _streamSub = null;
      _streamDone = null;
      _streamCancelled = false;
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
