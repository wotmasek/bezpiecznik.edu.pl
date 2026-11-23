import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ratunek/cpr/cpr_session.dart';
import '../data/chat_store.dart';
import '../templates/panel_model.dart';
import 'answer_service.dart';

/// Note appended to a message stopped by the user (spec "Przerwanie").
const String stoppedNote = 'Przerwano.';

/// Toast text when the conversation cannot be saved (spec "Błąd zapisu").
const String saveErrorText = 'Nie mogę zapisać rozmowy. Brak miejsca w telefonie.';

/// A message in the current chat: user text, assistant answer, or the
/// thinking state ([status] == generating).
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    this.text = '',
    this.status = MessageStatus.done,
    this.answer,
    this.phase = ThinkingPhase.searching,
    this.partialText,
    this.risk = false,
  });

  final String id;
  final ChatRole role;
  final DateTime createdAt;

  /// User text; for assistant messages the error text or [stoppedNote].
  final String text;
  final MessageStatus status;

  /// Validated answer (assistant, status done).
  final AssistantAnswer? answer;

  /// Phase label while generating.
  final ThinkingPhase phase;

  /// Optional streamed preview while generating.
  final String? partialText;

  /// Risk phrase: the thinking bubble shows the `call` panel first.
  final bool risk;

  bool get isUser => role == ChatRole.user;
  bool get isThinking => !isUser && status == MessageStatus.generating;

  ChatMessage copyWith({
    String? text,
    MessageStatus? status,
    AssistantAnswer? answer,
    ThinkingPhase? phase,
    String? partialText,
    bool? risk,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      createdAt: createdAt,
      text: text ?? this.text,
      status: status ?? this.status,
      answer: answer ?? this.answer,
      phase: phase ?? this.phase,
      partialText: partialText ?? this.partialText,
      risk: risk ?? this.risk,
    );
  }

  StoredMessage toStored() => StoredMessage(
    id: id,
    role: role,
    text: text,
    status: status,
    answer: answer,
    createdAt: createdAt,
  );

  static ChatMessage fromStored(StoredMessage m) => ChatMessage(
    id: m.id,
    role: m.role,
    createdAt: m.createdAt,
    text: m.text,
    status: m.status,
    answer: m.answer,
  );
}

@immutable
class ChatState {
  const ChatState({this.chatId, this.messages = const [], this.saveFailed = false});

  /// Null until the first message is sent (an empty chat is not saved).
  final String? chatId;
  final List<ChatMessage> messages;

  /// A write failed; the UI shows [saveErrorText] once.
  final bool saveFailed;

  bool get isEmpty => messages.isEmpty;
  bool get generating => messages.any((m) => m.isThinking);

  ChatState copyWith({String? chatId, List<ChatMessage>? messages, bool? saveFailed}) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      saveFailed: saveFailed ?? this.saveFailed,
    );
  }
}

/// The current chat: sends questions to the [AnswerService], tracks the
/// thinking state and persists to the [ChatStore].
class ChatController extends Notifier<ChatState> {
  StreamSubscription<AnswerEvent>? _sub;
  String? _activeId;
  Future<void> _writes = Future.value();

  @override
  ChatState build() {
    ref.onDispose(() => _sub?.cancel());
    return const ChatState();
  }

  /// Completes when all pending writes are done (tests).
  Future<void> flush() => _writes;

  /// Sends [text]. While an answer is generating this stops it first (status
  /// `stopped`, "Przerwano.") and starts the new flow.
  void send(String text) {
    final question = text.trim();
    if (question.isEmpty) return;
    if (state.generating) stop();

    final chatId = state.chatId ?? newChatId();
    final previous = [
      for (final m in state.messages)
        if (m.isUser) m.text,
    ].lastOrNull;
    final history = chatHistory(state.messages);
    final now = DateTime.now();
    final user = ChatMessage(
      id: newChatId(),
      role: ChatRole.user,
      createdAt: now,
      text: question,
    );
    final assistant = ChatMessage(
      id: newChatId(),
      role: ChatRole.assistant,
      createdAt: now.add(const Duration(milliseconds: 1)),
      status: MessageStatus.generating,
    );
    state = state.copyWith(chatId: chatId, messages: [...state.messages, user, assistant]);
    _persist(chatId, user);
    _run(
      question,
      ChatContext(chatId: chatId, previousQuestion: previous, history: history),
      assistant.id,
    );
  }

  void _run(String question, ChatContext ctx, String assistantId) {
    _activeId = assistantId;
    final stream = ref.read(answerServiceProvider).answer(question, ctx);
    var finished = false;
    void finish(ChatMessage Function(ChatMessage) change) {
      if (finished || _activeId != assistantId) return;
      finished = true;
      _activeId = null;
      _sub = null;
      _update(assistantId, change, persistChatId: ctx.chatId);
    }

    _sub = stream.listen(
      (event) {
        if (_activeId != assistantId) return;
        switch (event) {
          case AnswerThinking(:final phase, :final risk):
            _update(assistantId, (m) => m.copyWith(phase: phase, risk: m.risk || risk));
          case AnswerPartialText(:final text):
            _update(assistantId, (m) => m.copyWith(partialText: text));
          case AnswerReady(:final answer):
            finish((m) => m.copyWith(status: MessageStatus.done, answer: answer));
          case AnswerFailed(:final message):
            finish((m) => m.copyWith(status: MessageStatus.error, text: message));
        }
      },
      onError: (Object e) => finish(
        (m) => m.copyWith(status: MessageStatus.error, text: 'Coś poszło nie tak. Spróbuj ponownie.'),
      ),
      onDone: () => finish(
        (m) => m.copyWith(status: MessageStatus.error, text: 'Coś poszło nie tak. Spróbuj ponownie.'),
      ),
    );
  }

  /// Stops the current generation without sending anything: the message keeps
  /// status `stopped`, no templates, note "Przerwano.".
  void stop() {
    final id = _activeId;
    if (id == null) return;
    _sub?.cancel();
    _sub = null;
    _activeId = null;
    _update(
      id,
      (m) => ChatMessage(
        id: m.id,
        role: m.role,
        createdAt: m.createdAt,
        text: stoppedNote,
        status: MessageStatus.stopped,
        risk: m.risk,
      ),
      persistChatId: state.chatId,
    );
  }

  /// Starts a new empty chat (not saved until the first message).
  void newChat() {
    stop();
    ref.read(cprSessionProvider).dismissSummary();
    state = const ChatState();
  }

  /// Opens a saved chat from the list.
  Future<void> openChat(String chatId) async {
    stop();
    ref.read(cprSessionProvider).dismissSummary();
    try {
      final stored = await ref.read(chatStoreProvider).loadMessages(chatId);
      state = ChatState(chatId: chatId, messages: [for (final m in stored) ChatMessage.fromStored(m)]);
    } on Object {
      state = state.copyWith(saveFailed: true);
    }
  }

  /// Appends a finished assistant message holding [answer] without a user
  /// bubble and without touching a running generation (e.g. the AED card
  /// inserted from the CPR instructor). Persisted like any other message.
  void insertAssistantAnswer(AssistantAnswer answer) {
    final chatId = state.chatId ?? newChatId();
    final message = ChatMessage(
      id: newChatId(),
      role: ChatRole.assistant,
      createdAt: DateTime.now(),
      answer: answer,
    );
    state = state.copyWith(chatId: chatId, messages: [...state.messages, message]);
    _persist(chatId, message);
  }

  /// Stores a changed answer (variant switch, checked step) of [messageId].
  void updateAnswer(String messageId, AssistantAnswer answer) {
    _update(messageId, (m) => m.copyWith(answer: answer), persistChatId: state.chatId);
  }

  /// The UI showed the save-error toast.
  void ackSaveError() {
    if (state.saveFailed) state = state.copyWith(saveFailed: false);
  }

  void _update(
    String id,
    ChatMessage Function(ChatMessage) change, {
    String? persistChatId,
  }) {
    ChatMessage? updated;
    final next = [
      for (final m in state.messages)
        if (m.id == id) (updated = change(m)) else m,
    ];
    if (updated == null) return;
    state = state.copyWith(messages: next);
    if (persistChatId != null && updated.status != MessageStatus.generating) {
      _persist(persistChatId, updated);
    }
  }

  void _persist(String chatId, ChatMessage message) {
    final store = ref.read(chatStoreProvider);
    final stored = message.toStored();
    _writes = _writes.then((_) async {
      try {
        await store.saveMessage(chatId, stored);
        ref.read(chatRevisionProvider.notifier).bump();
      } on Object catch (e) {
        debugPrint('Chat save failed: $e');
        if (ref.mounted) state = state.copyWith(saveFailed: true);
      }
    });
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// The last [max] finished turns of [messages] for the conversational reply.
/// A conversational answer keeps its text; an answer from the guides becomes
/// its panel titles, so the model knows the topic without the whole list.
List<ChatTurn> chatHistory(List<ChatMessage> messages, {int max = 6}) {
  final out = <ChatTurn>[];
  for (final m in messages) {
    if (m.isUser) {
      out.add((user: true, text: m.text, chat: false));
      continue;
    }
    final a = m.answer;
    if (a == null || m.status == MessageStatus.generating) continue;
    final talk = [for (final p in a.panels) if (p is ChatTextPanel) p.text].join(' ');
    if (talk.isNotEmpty) {
      out.add((user: false, text: talk, chat: true));
    } else {
      final titles = [
        for (final p in a.panels)
          if (p.raw['title'] case final String t when t.isNotEmpty) t,
      ];
      out.add((
        user: false,
        text: titles.isEmpty ? '(odpowiedź z poradników)' : '(odpowiedź z poradników: ${titles.join(', ')})',
        chat: false,
      ));
    }
  }
  return out.length <= max ? out : out.sublist(out.length - max);
}
