import 'package:bezpiecznik/czat/answer/answer_prompt.dart';
import 'package:bezpiecznik/czat/answer/conversation.dart';
import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// Sentences from the phone test of 2026-11-23 (research/model-test/log.txt).
void main() {
  group('classifiers', () {
    test('crisis: suicidal thoughts, self-harm, panic; with or without Polish letters', () {
      for (final q in [
        'Nie chce mi sie zyc',
        'Nie chcę mi się żyć',
        'myślę o samobójstwie',
        'Mam atak paniki',
        'chyba zrobię sobie krzywdę',
      ]) {
        expect(isCrisis(q), isTrue, reason: q);
      }
      for (final q in ['Ktoś nie oddycha', 'pożar w bloku', 'zagrożenie życia', 'atak rakietowy']) {
        expect(isCrisis(q), isFalse, reason: q);
      }
    });

    test('follow-up', () {
      expect(isFollowUp('A ile wody?'), isTrue);
      expect(isFollowUp('i w nocy?'), isTrue);
      expect(isFollowUp('Ile wody?'), isFalse);
    });
  });

  group('pipeline', () {
    final searched = <String>[];
    PipelineAnswerService svc(
      FakeEngine e, {
      RetrievalResult? result,
      bool risk = false,
      String profile = '',
    }) => PipelineAnswerService(
      search: (q) async {
        searched.add(q);
        return result ?? const RetrievalResult(decision: RetrievalDecision.noSource, chunks: []);
      },
      engine: e,
      isRisk: (_) => risk,
      profileContext: () async => profile,
    );
    setUp(searched.clear);

    AssistantAnswer ready(List<AnswerEvent> ev) => (ev.last as AnswerReady).answer;

    test('crisis: no search, call panel first, crisis note in the turn, 116 123 added', () async {
      final e = FakeEngine([
        ['Bardzo mi przykro, że tak się czujesz. Czy jesteś teraz w bezpiecznym miejscu?'],
      ]);
      final a = ready(await svc(e).answer('Nie chce mi sie zyc', const ChatContext(chatId: 'c')).toList());
      expect(searched, isEmpty);
      expect(a.panels.first, isA<CallPanel>());
      final text = (a.panels.last as ChatTextPanel).text;
      expect(text, contains('116 123'));
      expect(text, contains('112'));
      expect(e.requests.single.messages.last.content, contains(kCrisisPromptNote));
      expect(a.panels.whereType<FormPanel>(), isEmpty);
    });

    test('crisis: 116 123 is not repeated when the model already gave it', () async {
      final e = FakeEngine([
        ['Dobrze, że piszesz. Zadzwoń pod 116 123. Czy jesteś bezpieczny?'],
      ]);
      final a = ready(await svc(e).answer('Mam atak paniki', const ChatContext(chatId: 'c')).toList());
      final all = [for (final p in a.panels) if (p is ChatTextPanel) p.text].join(' ');
      expect('116 123'.allMatches(all).length, 1);
    });

    test('crisis with the model down: fixed caring text, 116 123, call panel', () async {
      final e = FakeEngine([const LlmUnavailable('down')]);
      final a = ready(await svc(e).answer('Mam atak paniki', const ChatContext(chatId: 'c')).toList());
      expect(a.panels.first, isA<CallPanel>());
      expect((a.panels.last as ChatTextPanel).text, startsWith(kCrisisFallback));
      expect((a.panels.last as ChatTextPanel).text, contains('116 123'));
    });

    test('talk is answered by the model, never the canned "Nie wiem"', () async {
      final e = FakeEngine([
        ['Cieszę się, że mogłem pomóc. Jak się teraz czujesz?'],
      ]);
      final a = ready(await svc(e).answer('Dzięki, że mnie wysłuchałeś', const ChatContext(chatId: 'c')).toList());
      expect(searched, ['Dzięki, że mnie wysłuchałeś']);
      expect(e.requests, hasLength(1));
      expect(e.requests.single.messages.last.content, startsWith(kNoSnippets));
      expect(a.panels.single, isA<ChatTextPanel>());
      expect(a.panels.whereType<NoSourcePanel>(), isEmpty);
    });

    test('rebuilt transcript from the history (restart) and the profile', () async {
      final e = FakeEngine([
        ['Powiedz jej, co czujesz. Kiedy możecie porozmawiać?'],
      ]);
      const ctx = ChatContext(
        chatId: 'c',
        previousQuestion: 'Poklocilem sie z mama',
        history: [
          (user: true, text: 'Poklocilem sie z mama', chat: false),
          (user: false, text: 'To musi być przykre. Co się stało?', chat: true),
        ],
      );
      final a = ready(await svc(e, profile: 'Domownicy: 1 dziecko.')
          .answer('Jak myslisz, co powinienem jej powiedziec?', ctx)
          .toList());
      expect(a.panels.single, isA<ChatTextPanel>());
      final req = e.requests.single;
      expect(req.messages.length, 3);
      expect(req.messages.first.content, 'Pytanie: Poklocilem sie z mama');
      expect(req.messages[1].role, LlmRole.assistant);
      expect(req.conversationId, 'c');
      expect(req.systemPrompt, contains('Profil domu: Domownicy: 1 dziecko.'));
    });

    test('empty profile is said in the prompt', () async {
      final e = FakeEngine([['Ok.']]);
      await svc(e).answer('Co o mnie wiesz?', const ChatContext(chatId: 'c')).toList();
      expect(e.requests.single.systemPrompt, endsWith('Profil domu: pusty.'));
    });

    test('no source and the model down: the calm refusal', () async {
      final e = FakeEngine([const LlmUnavailable('down')]);
      final a = ready(await svc(e).answer('ugryzienie weza', const ChatContext(chatId: 'c')).toList());
      expect(a.panels.single, isA<NoSourcePanel>());
    });

    test('follow-up is searched with the previous question', () async {
      await svc(FakeEngine([])).answer(
        'A ile wody?',
        const ChatContext(chatId: 'c', previousQuestion: 'Jak przygotowac sie na brak pradu?'),
      ).toList();
      expect(searched.first, 'Jak przygotowac sie na brak pradu? A ile wody?');
    });

    test('short question with no source: one retry with the previous question', () async {
      await svc(FakeEngine([])).answer(
        'ile wody?',
        const ChatContext(chatId: 'c', previousQuestion: 'brak prądu'),
      ).toList();
      expect(searched, ['ile wody?', 'brak prądu ile wody?']);
    });
  });
}
