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

    test('talk: feelings, family, thanks, the assistant, the profile', () {
      for (final q in [
        'Co bys zrobil na moim miejscu?',
        'Poklocilem sie dzisiaj z mama i jest mi smutno',
        'Jak myslisz, co powinienem jej powiedziec?',
        'Dzieki, ze mnie wysluchales',
        'Moj tata jest chory i boje sie, ze umrze',
        'Boje sie wojny, nie moge spac',
        'Kim jestes?',
        'Co o mnie wiesz?',
        'Ile osob mieszka ze mna?',
        'Jakie leki biore?',
      ]) {
        expect(isTalk(q), isTrue, reason: q);
      }
    });

    test('not talk: questions for the guides, also with a greeting or a feeling', () {
      for (final q in [
        'Jak przygotowac sie na brak pradu?',
        'Cześć, jak zatamować krwawienie?',
        'Boję się burzy, co robić?',
        'Co mam spakowac do plecaka dla mojej rodziny?',
        'Co zrobic gdy wyja syreny?',
      ]) {
        expect(isTalk(q), isFalse, reason: q);
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

    test('crisis: no search, call panel first, reply ends with 116 123 / 112', () async {
      final e = FakeEngine([
        ['Bardzo mi przykro, że tak się czujesz. Czy jesteś teraz bezpieczny?'],
      ]);
      final a = ready(await svc(e).answer('Nie chce mi sie zyc', const ChatContext(chatId: 'c')).toList());
      expect(searched, isEmpty);
      expect(a.panels.first, isA<CallPanel>());
      final text = (a.panels.last as ChatTextPanel).text;
      expect(text, contains('116 123'));
      expect(text, contains('112'));
      expect(e.requests.single.systemPrompt, contains(kCrisisPromptNote.trim()));
    });

    test('crisis with the model down: fixed caring text, 116 123, call panel', () async {
      final e = FakeEngine([const LlmUnavailable('down')]);
      final a = ready(await svc(e).answer('Mam atak paniki', const ChatContext(chatId: 'c')).toList());
      expect(a.panels.first, isA<CallPanel>());
      expect((a.panels.last as ChatTextPanel).text, startsWith(kCrisisFallback));
      expect((a.panels.last as ChatTextPanel).text, contains('116 123'));
    });

    test('talk sees the history and the profile, and skips the guides', () async {
      final e = FakeEngine([
        ['Rozumiem, że kłótnia z mamą boli.'],
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
      expect(searched, isEmpty);
      expect(a.panels.single, isA<ChatTextPanel>());
      final req = e.requests.single;
      expect(req.messages.length, 3);
      expect(req.messages.first.content, 'Poklocilem sie z mama');
      expect(req.messages[1].role, LlmRole.assistant);
      expect(req.systemPrompt, contains('Profil domu: Domownicy: 1 dziecko.'));
    });

    test('no source in the middle of a conversation: talk instead of "Nie wiem"', () async {
      final e = FakeEngine([
        ['Słyszę, że czujesz się niedoceniony.'],
      ]);
      const ctx = ChatContext(
        chatId: 'c',
        history: [
          (user: true, text: 'Jest mi smutno', chat: false),
          (user: false, text: 'Przykro mi. Co się stało?', chat: true),
        ],
      );
      final a = ready(await svc(e).answer('Ona uwaza ze za malo pomagam w domu', ctx).toList());
      expect(a.panels.single, isA<ChatTextPanel>());
    });

    test('no source outside a conversation: still the refusal, no model', () async {
      final e = FakeEngine([]);
      final a = ready(await svc(e).answer('ugryzienie weza', const ChatContext(chatId: 'c')).toList());
      expect(a.panels.single, isA<NoSourcePanel>());
      expect(e.requests, isEmpty);
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
