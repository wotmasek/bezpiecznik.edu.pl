import 'dart:async';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ratunek/cpr/cpr_fakes.dart';

/// A service whose streams the test controls.
class ManualService implements AnswerService {
  final calls = <(String, ChatContext, StreamController<AnswerEvent>)>[];

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) {
    final c = StreamController<AnswerEvent>();
    calls.add((question, ctx, c));
    return c.stream;
  }
}

class FailingStore extends ChatStore {
  FailingStore() : super(() async => throw StateError('disk full'));
}

ProviderContainer makeContainer(AnswerService service, ChatStore store) {
  final c = ProviderContainer(
    overrides: [
      answerServiceProvider.overrideWithValue(service),
      chatStoreProvider.overrideWithValue(store),
      cprSessionProvider.overrideWithValue(Rig().session),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

AssistantAnswer answerOf(String text) => AssistantAnswer.fromJson({
  'panels': [
    {
      'type': 'steps',
      'title': text,
      'items': [
        {'text': text},
      ],
    },
  ],
});

void main() {
  late ChatStore store;
  setUp(() => store = ChatStore.inMemory());
  tearDown(() => store.close());

  test(
    'send: user message + thinking, then the answer appears at once',
    () async {
      final service = ManualService();
      final c = makeContainer(service, store);
      ChatController ctl() => c.read(chatControllerProvider.notifier);
      ChatState st() => c.read(chatControllerProvider);

      expect(st().isEmpty, isTrue);
      expect(st().chatId, isNull);

      ctl().send('  Brak prądu  ');
      expect(st().messages, hasLength(2));
      expect(st().messages[0].isUser, isTrue);
      expect(st().messages[0].text, 'Brak prądu', reason: 'trimmed');
      expect(st().messages[1].isThinking, isTrue);
      expect(st().generating, isTrue);
      expect(st().chatId, isNotNull);

      final (q, ctx, stream) = service.calls.single;
      expect(q, 'Brak prądu');
      expect(ctx.previousQuestion, isNull);
      expect(ctx.chatId, st().chatId);

      stream.add(const AnswerThinking(ThinkingPhase.composing));
      stream.add(const AnswerPartialText('Szukam'));
      await pumpEventQueue();
      expect(st().messages[1].phase, ThinkingPhase.composing);
      expect(st().messages[1].partialText, 'Szukam');
      expect(
        st().messages[1].answer,
        isNull,
        reason: 'no panels before validation',
      );

      stream.add(AnswerReady(answerOf('Gotowe')));
      await pumpEventQueue();
      expect(st().generating, isFalse);
      expect(st().messages[1].status, MessageStatus.done);
      expect(st().messages[1].answer!.panels.single, isA<StepsPanel>());

      await ctl().flush();
      final saved = await store.loadMessages(st().chatId!);
      expect(saved.map((m) => m.role), [ChatRole.user, ChatRole.assistant]);
      expect(saved[1].answer, isNotNull);
      expect((await store.listChats()).single.title, 'Brak prądu');
    },
  );

  test('blank messages are ignored; no chat is created', () async {
    final service = ManualService();
    final c = makeContainer(service, store);
    c.read(chatControllerProvider.notifier).send('   \n ');
    expect(c.read(chatControllerProvider).isEmpty, isTrue);
    expect(service.calls, isEmpty);
    await c.read(chatControllerProvider.notifier).flush();
    expect(await store.listChats(), isEmpty);
  });

  test('stop: message becomes stopped with "Przerwano.", no templates, service cancelled', () async {
    final service = ManualService();
    final c = makeContainer(service, store);
    c.read(chatControllerProvider.notifier).send('Pytanie');
    final stream = service.calls.single.$3;
    var cancelled = false;
    stream.onCancel = () => cancelled = true;

    c.read(chatControllerProvider.notifier).stop();
    final st = c.read(chatControllerProvider);
    expect(st.generating, isFalse);
    expect(st.messages[1].status, MessageStatus.stopped);
    expect(st.messages[1].text, 'Przerwano.');
    expect(st.messages[1].answer, isNull);
    expect(cancelled, isTrue);

    // A late event of the cancelled run changes nothing.
    stream.add(AnswerReady(answerOf('late')));
    await pumpEventQueue();
    expect(c.read(chatControllerProvider).messages[1].answer, isNull);

    await c.read(chatControllerProvider.notifier).flush();
    final saved = await store.loadMessages(st.chatId!);
    expect(saved[1].status, MessageStatus.stopped);
  });

  test('form answers come back as the next message with the asked question as context', () async {
    final service = ManualService();
    final c = makeContainer(service, store);
    final ctl = c.read(chatControllerProvider.notifier);
    ctl.send('Jak się przygotować?');
    service.calls[0].$3.add(
      AnswerReady(
        AssistantAnswer.fromJson({
          'panels': [
            {
              'type': 'form',
              'questions': [
                {'text': 'Na co?', 'options': ['Powódź', 'Brak prądu']},
              ],
            },
          ],
        }),
      ),
    );
    await pumpEventQueue();
    ctl.send('Powódź');
    expect(service.calls[1].$1, 'Powódź');
    expect(service.calls[1].$2.previousQuestion, 'Jak się przygotować?');
  });

  test('stop without a running generation does nothing', () {
    final c = makeContainer(ManualService(), store);
    c.read(chatControllerProvider.notifier).stop();
    expect(c.read(chatControllerProvider).isEmpty, isTrue);
  });

  test(
    'sending during generation stops the current one and starts the new one',
    () async {
      final service = ManualService();
      final c = makeContainer(service, store);
      final ctl = c.read(chatControllerProvider.notifier);
      ctl.send('Pierwsze');
      ctl.send('Drugie');

      final st = c.read(chatControllerProvider);
      expect(st.messages.map((m) => m.isUser ? m.text : m.status.name), [
        'Pierwsze',
        'stopped',
        'Drugie',
        'generating',
      ]);
      expect(service.calls, hasLength(2));
      expect(service.calls[1].$2.previousQuestion, 'Pierwsze');
      expect(st.chatId, service.calls[0].$2.chatId, reason: 'same chat');

      service.calls[0].$3.add(AnswerReady(answerOf('stale')));
      service.calls[1].$3.add(AnswerReady(answerOf('fresh')));
      await pumpEventQueue();
      final after = c.read(chatControllerProvider);
      expect(after.messages[1].answer, isNull, reason: 'stale answer dropped');
      expect(after.messages[3].answer!.panels.single.raw['title'], 'fresh');
    },
  );

  test(
    'failure shows the service message; stream ending silently is an error',
    () async {
      final service = ManualService();
      final c = makeContainer(service, store);
      final ctl = c.read(chatControllerProvider.notifier);
      ctl.send('A');
      service.calls[0].$3.add(
        const AnswerFailed('Baza wiedzy nie jest pobrana.'),
      );
      await pumpEventQueue();
      var m = c.read(chatControllerProvider).messages[1];
      expect(m.status, MessageStatus.error);
      expect(m.text, 'Baza wiedzy nie jest pobrana.');

      ctl.send('B');
      await service.calls[1].$3.close();
      await pumpEventQueue();
      m = c.read(chatControllerProvider).messages[3];
      expect(m.status, MessageStatus.error);
    },
  );

  test(
    'FakeAnswerService default script gives a steps answer with a source',
    () async {
      final c = makeContainer(FakeAnswerService(), store);
      c.read(chatControllerProvider.notifier).send('x');
      await pumpEventQueue();
      final a = c.read(chatControllerProvider).messages[1].answer!;
      expect(a.source('fake-s1-f1')!.chipLabel, '▸ Przykład, s. 14');
    },
  );

  test(
    'EchoQuoteAnswerService answers with the calm NoSource refusal',
    () async {
      final c = makeContainer(const EchoQuoteAnswerService(), store);
      c.read(chatControllerProvider.notifier).send('Jak naprawić agregat?');
      await pumpEventQueue();
      final a = c.read(chatControllerProvider).messages[1].answer!;
      expect(a.origin, AnswerOrigin.refusal);
      expect(a.panels.single, isA<NoSourcePanel>());
    },
  );

  test('updateAnswer stores a checked step; openChat / newChat', () async {
    final c = makeContainer(FakeAnswerService(), store);
    final ctl = c.read(chatControllerProvider.notifier);
    ctl.send('x');
    await pumpEventQueue();
    final msg = c.read(chatControllerProvider).messages[1];
    ctl.updateAnswer(msg.id, msg.answer!.withDone(0, null, 0, true));
    await ctl.flush();
    final chatId = c.read(chatControllerProvider).chatId!;

    ctl.newChat();
    expect(c.read(chatControllerProvider).isEmpty, isTrue);
    expect(c.read(chatControllerProvider).chatId, isNull);

    await ctl.openChat(chatId);
    final st = c.read(chatControllerProvider);
    expect(st.chatId, chatId);
    expect(st.messages, hasLength(2));
    expect(st.messages[1].answer!.doneFor(0, null), {0});
  });

  test('chatListProvider follows saves', () async {
    final c = makeContainer(FakeAnswerService(), store);
    expect(await c.read(chatListProvider.future), isEmpty);
    c.read(chatControllerProvider.notifier).send('Nowy czat testowy');
    await pumpEventQueue();
    await c.read(chatControllerProvider.notifier).flush();
    final list = await c.read(chatListProvider.future);
    expect(list.single.title, 'Nowy czat testowy');
  });

  test(
    'a failing store keeps the chat working in memory and flags the error',
    () async {
      final c = makeContainer(FakeAnswerService(), FailingStore());
      final ctl = c.read(chatControllerProvider.notifier);
      ctl.send('x');
      await pumpEventQueue();
      await ctl.flush();
      final st = c.read(chatControllerProvider);
      expect(st.saveFailed, isTrue);
      expect(st.messages[1].answer, isNotNull);
      ctl.ackSaveError();
      expect(c.read(chatControllerProvider).saveFailed, isFalse);
    },
  );

  test(
    'insertAssistantAnswer: one assistant message, no user bubble, persisted',
    () async {
      final service = ManualService();
      final c = makeContainer(service, store);
      c
          .read(chatControllerProvider.notifier)
          .insertAssistantAnswer(answerOf('aed'));
      await c.read(chatControllerProvider.notifier).flush();
      final st = c.read(chatControllerProvider);
      expect(st.messages, hasLength(1));
      expect(st.messages.single.isUser, isFalse);
      expect(st.messages.single.status, MessageStatus.done);
      expect(st.chatId, isNotNull);
      expect(service.calls, isEmpty);
      final stored = await store.loadMessages(st.chatId!);
      expect(stored, hasLength(1));
      expect(stored.single.answer, isNotNull);
    },
  );
}
