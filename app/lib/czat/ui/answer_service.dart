import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../answer_router.dart';
import '../templates/panel_model.dart';

/// What the chat controller gives the service besides the question.
class ChatContext {
  const ChatContext({
    required this.chatId,
    this.previousQuestion,
    this.history = const [],
  });

  final String chatId;

  /// Previous user question in this chat (spec: the model gets the current and
  /// the previous question).
  final String? previousQuestion;

  /// Last turns of this chat, oldest first, for the conversational reply.
  /// An assistant turn answered from the guides is its titles only.
  final List<ChatTurn> history;

  /// The last assistant turn was a conversational reply (not the guides).
  bool get inConversation => history.isNotEmpty && !history.last.user && history.last.chat;
}

/// One past turn as the conversational reply sees it.
typedef ChatTurn = ({bool user, String text, bool chat});

/// Phase shown in the thinking bubble (spec ekran-1-czat.md, "Teksty").
enum ThinkingPhase {
  /// "Szukam w źródłach…"
  searching('Szukam w źródłach…'),

  /// "Układam odpowiedź…"
  composing('Układam odpowiedź…'),

  /// "Uruchamiam model. Pierwsza odpowiedź trwa dłużej."
  modelLoading('Uruchamiam model. Pierwsza odpowiedź trwa dłużej.');

  const ThinkingPhase(this.label);

  final String label;
}

/// Events of one answer. Flow: zero or more [AnswerThinking] / [AnswerPartialText],
/// then exactly one [AnswerReady] or [AnswerFailed], then the stream closes.
sealed class AnswerEvent {
  const AnswerEvent();
}

/// Changes the phase label of the thinking skeleton.
class AnswerThinking extends AnswerEvent {
  const AnswerThinking([this.phase = ThinkingPhase.searching, this.risk = false]);

  final ThinkingPhase phase;

  /// The question is a risk phrase: the chat shows the `call` panel above the
  /// thinking skeleton right away (sticky until the answer replaces it).
  final bool risk;
}

/// Optional streamed preview, shown only inside the thinking bubble. The
/// answer itself is never rendered in pieces.
class AnswerPartialText extends AnswerEvent {
  const AnswerPartialText(this.text);

  final String text;
}

/// The validated answer; all templates appear at once.
class AnswerReady extends AnswerEvent {
  const AnswerReady(this.answer);

  final AssistantAnswer answer;
}

/// Failure with a user-facing Polish [message] (shown as the assistant bubble).
class AnswerFailed extends AnswerEvent {
  const AnswerFailed(this.message);

  final String message;
}

/// Produces the answer to a question. The real pipeline (A06) and the rescue
/// card path (D03) implement this; cancelling the stream subscription must
/// stop the work.
// ignore: one_member_abstracts
abstract interface class AnswerService {
  Stream<AnswerEvent> answer(String question, ChatContext ctx);
}

/// Test / gallery double. Records [questions]; [script] decides what to emit
/// (default: thinking, a partial text, then a steps answer after [delay]).
class FakeAnswerService implements AnswerService {
  FakeAnswerService({this.script, this.delay = Duration.zero});

  final Stream<AnswerEvent> Function(String question, ChatContext ctx)? script;
  final Duration delay;

  final List<String> questions = [];

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) {
    questions.add(question);
    final s = script;
    if (s != null) return s(question, ctx);
    return _default(question);
  }

  Stream<AnswerEvent> _default(String question) async* {
    yield const AnswerThinking();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    yield const AnswerPartialText('Szukam…');
    yield const AnswerThinking(ThinkingPhase.composing);
    yield AnswerReady(fakeStepsAnswer());
  }
}

/// A small steps answer with a source (synthetic text, not safety content).
AssistantAnswer fakeStepsAnswer() => AssistantAnswer.fromJson({
  'origin': 'ai',
  'panels': [
    {
      'type': 'steps',
      'title': 'Teraz',
      'items': [
        {'text': 'Przykładowy krok pierwszy', 'source_id': 'fake-s1-f1'},
        {'text': 'Przykładowy krok drugi', 'source_id': 'fake-s1-f1'},
      ],
    },
  ],
  'sources': {
    'fake-s1-f1': {
      'source_id': 'fake-s1-f1',
      'doc_id': 'fake',
      'doc_title': 'Dokument przykładowy',
      'doc_short': 'Przykład',
      'page_label': '14',
      'pdf_page': 16,
      'text': 'Przykładowy fragment źródła.',
    },
  },
});

/// Temporary default: answers every question with the calm "brak w źródłach"
/// refusal. Later tasks override [answerServiceProvider].
class EchoQuoteAnswerService implements AnswerService {
  const EchoQuoteAnswerService();

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) async* {
    yield const AnswerThinking();
    yield const AnswerReady(
      AssistantAnswer(
        origin: AnswerOrigin.refusal,
        panels: [NoSourcePanel(NoSourceKind.noSource, {'type': 'no_source', 'kind': 'no_source'})],
      ),
    );
  }
}

/// The production answer path: rescue card → map intent → sourced pipeline
/// (see `RoutedAnswerService`). Tests override it with [FakeAnswerService].
final answerServiceProvider = Provider<AnswerService>(
  (ref) => ref.watch(routedAnswerServiceProvider),
);
