import 'dart:async';

import 'package:bezpiecznik/czat/answer/answer_prompt.dart';
import 'package:bezpiecznik/czat/answer/answer_builder.dart';
import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const ctx = ChatContext(chatId: 'c');

final lift = chunk('c1', 'W razie pożaru nie wchodź do windy. Zejdź schodami na zewnątrz budynku.');
final water = chunk('c2', 'Zapas wody to trzy litry na osobę na dobę.', page: '6');

String good() => '1. Nie wchodź do windy [1].\n2. Zejdź schodami na zewnątrz [1].';

PipelineAnswerService svc(
  FakeEngine engine, {
  RetrievalResult? result,
  bool risk = false,
  String profile = '',
  void Function(String)? log,
  String? Function()? modelNote,
}) => PipelineAnswerService(
  search: (_) async => result ?? found([lift, water]),
  engine: engine,
  isRisk: (_) => risk,
  profileContext: () async => profile,
  onLog: log,
  modelNote: modelNote,
);

Future<List<AnswerEvent>> run(PipelineAnswerService s, [String q = 'pożar w bloku']) =>
    s.answer(q, ctx).toList();

AssistantAnswer ready(List<AnswerEvent> ev) {
  expect(ev.last, isA<AnswerReady>());
  expect(ev.whereType<AnswerReady>().length + ev.whereType<AnswerFailed>().length, 1);
  return (ev.last as AnswerReady).answer;
}

List<String> types(AssistantAnswer a) => [for (final p in a.panels) p.type];

void main() {
  test('happy path: events, steps from a numbered list, sources, request shape', () async {
    final e = FakeEngine([
      [good()],
    ]);
    final ev = await run(svc(e));
    expect(ev.first, isA<AnswerThinking>());
    final a = ready(ev);
    expect(a.origin, AnswerOrigin.ai);
    expect(types(a), ['steps']);
    final steps = a.panels.single as StepsPanel;
    expect([for (final i in steps.items) i.text], ['Nie wchodź do windy.', 'Zejdź schodami na zewnątrz.']);
    expect(steps.items.every((i) => i.sourceId == 'c1'), isTrue);
    expect(a.sources.keys, ['c1']);
    final req = e.requests.single;
    expect(req.jsonMode, isFalse);
    expect(req.jsonSchema, isNull);
    expect(req.conversationId, 'c');
    expect(req.temperature, 0.6);
    expect(req.maxTokens, kAnswerMaxTokens);
    expect(req.messages.single.content, startsWith('$kSnippetHeader\n[1] (RCB, s. 14) W razie pożaru'));
    expect(req.messages.single.content, endsWith('Pytanie: pożar w bloku'));
  });

  test('markdown -> panels: paragraph with citations, bullets, unknown [n] stripped', () async {
    const md = 'Zapas wody to trzy litry na dobę [2]. Nie wchodź do windy [1].\n\n'
        '## Spakuj\n- woda [2]\n- latarka [7]\n\nChcesz więcej?';
    final a = ready(await run(svc(FakeEngine([[md]]))));
    expect(types(a), ['chat_text', 'bullets', 'chat_text']);
    final para = a.panels.first as ChatTextPanel;
    expect([for (final i in para.items) i.sourceId], ['c2', 'c1']);
    expect(para.text, 'Zapas wody to trzy litry na dobę. Nie wchodź do windy.');
    final bullets = a.panels[1] as BulletsPanel;
    expect(bullets.title, 'Spakuj');
    expect([for (final i in bullets.items) (i.text, i.sourceId)], [('woda', 'c2'), ('latarka', null)]);
    expect((a.panels.last as ChatTextPanel).items, isEmpty);
    expect(a.sources.keys.toSet(), {'c1', 'c2'});
  });

  test('only 3 chunks go to the model, each cut to <= 600 characters', () async {
    final long = 'To jest zdanie o bezpieczeństwie. ' * 40;
    final many = [for (var i = 0; i < 5; i++) chunk('k$i', long)];
    final e = FakeEngine([['Ok [1].']]);
    await run(svc(e, result: found(many)));
    final m = e.requests.single.messages.single.content;
    expect(m, contains('[3]'));
    expect(m, isNot(contains('[4]')));
    for (final line in m.split('\n').where((l) => l.startsWith('['))) {
      expect(line.length, lessThan(600 + 20));
    }
  });

  test('noSource / offTopic: the model still answers, without snippets', () async {
    for (final d in [RetrievalDecision.noSource, RetrievalDecision.offTopic]) {
      final e = FakeEngine([
        ['Poradniki tego nie opisują. Mogę pomóc w sprawach bezpieczeństwa.'],
      ]);
      final a = ready(await run(svc(e, result: RetrievalResult(decision: d, chunks: const [])), 'przepis na pierogi'));
      expect(e.requests.single.messages.single.content, startsWith(kNoSnippets));
      expect(types(a), ['chat_text']);
      expect(a.sources, isEmpty);
    }
  });

  test('offTopic and the model down: off-topic refusal, no 112', () async {
    final e = FakeEngine([const LlmUnavailable('down')]);
    final a = ready(await run(
      svc(e, result: const RetrievalResult(decision: RetrievalDecision.offTopic, chunks: [])),
      'przepis na pierogi',
    ));
    expect(types(a), ['no_source']);
    expect((a.panels.single as NoSourcePanel).kind, NoSourceKind.offTopic);
  });

  group('live conversation transcript', () {
    test('grows as an exact prefix over 3 turns', () async {
      final e = FakeEngine([
        ['Pierwsza [1]. '],
        ['Druga.'],
        ['Trzecia [2].'],
      ]);
      final s = svc(e, profile: 'Domownicy: 2 dorosłych.');
      for (final q in ['pożar w bloku', 'a z dzieckiem?', 'ile wody?']) {
        await s.answer(q, ctx).toList();
      }
      expect(e.requests, hasLength(3));
      for (var i = 1; i < 3; i++) {
        final prev = e.requests[i - 1], cur = e.requests[i];
        expect(cur.systemPrompt, prev.systemPrompt);
        expect(cur.maxTokens, prev.maxTokens);
        expect(cur.temperature, prev.temperature);
        expect(cur.messages.length, prev.messages.length + 2);
        for (var j = 0; j < prev.messages.length; j++) {
          expect(cur.messages[j].content, prev.messages[j].content);
        }
      }
      // The assistant turn is the raw streamed text, byte for byte.
      expect(e.requests[1].messages[1].content, 'Pierwsza [1]. ');
      expect(e.requests[2].messages[2].content, startsWith(kSnippetHeader));
      expect(s.transcriptOf('c'), hasLength(6));
    });

    test('a profile change does not change the system prompt of a running chat', () async {
      var profile = '';
      final e = FakeEngine([['A.'], ['B.'], ['C.']]);
      final s = PipelineAnswerService(
        search: (_) async => found([lift]),
        engine: e,
        isRisk: (_) => false,
        profileContext: () async => profile,
      );
      await s.answer('pożar', ctx).toList();
      profile = 'Domownicy: 1 dziecko.';
      await s.answer('pożar', ctx).toList();
      await s.answer('pożar', const ChatContext(chatId: 'other')).toList();
      expect(e.requests[1].systemPrompt, e.requests[0].systemPrompt);
      expect(e.requests[2].systemPrompt, contains('1 dziecko'));
    });

    test('over budget: older snippet blocks stripped, oldest turns dropped', () async {
      final long = 'To jest zdanie o bezpieczeństwie w domu. ' * 14;
      final big = [for (var i = 0; i < 3; i++) chunk('k$i', long)];
      final e = FakeEngine([for (var i = 0; i < 8; i++) ['Odpowiedź $i. ' * 30]]);
      final s = svc(e, result: found(big));
      for (var i = 0; i < 8; i++) {
        await s.answer('pytanie $i', ctx).toList();
      }
      final last = e.requests.last;
      final size = estimateTokens(last.systemPrompt) +
          last.messages.fold(0, (n, m) => n + estimateTokens(m.content));
      expect(size, lessThanOrEqualTo(kTranscriptBudgetTokens));
      expect(last.messages.first.role, LlmRole.user);
      final withSnippets = last.messages.where((m) => m.content.contains(kSnippetHeader));
      expect(withSnippets.length, 1); // only the new turn
      expect(last.messages.last.content, endsWith('Pytanie: pytanie 7'));
    });

    test('a failed or empty turn is not appended', () async {
      final e = FakeEngine([
        const LlmTimeout(),
        [''],
        ['Ok.'],
      ]);
      final s = svc(e);
      await s.answer('pożar', ctx).toList();
      await s.answer('pożar', ctx).toList();
      expect(s.transcriptOf('c'), isEmpty);
      await s.answer('pożar', ctx).toList();
      expect(s.transcriptOf('c'), hasLength(2));
    });

    test('a cancelled turn is not appended', () async {
      final e = FakeEngine([null]);
      final s = svc(e);
      final sub = s.answer('pożar', ctx).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(s.transcriptOf('c'), isEmpty);
    });
  });

  group('risk', () {
    test('risk question: call first, then model panels; never a form or todo', () async {
      final a = ready(await run(svc(FakeEngine([[good()]]), risk: true)));
      expect(types(a), ['call', 'steps']);
      expect(a.panels.whereType<FormPanel>(), isEmpty);
      expect(a.panels.whereType<TodoPanel>(), isEmpty);
    });

    test('risk + quote fallback: call first', () async {
      final a = ready(await run(svc(FakeEngine([const LlmTimeout()]), risk: true)));
      expect(types(a), ['call', 'quote', 'quote']);
    });

    test('risk with no source and the model down: noSource + call', () async {
      final a = ready(await run(
        svc(FakeEngine([const LlmUnavailable('x')]),
            risk: true, result: const RetrievalResult(decision: RetrievalDecision.offTopic, chunks: [])),
        'pazar',
      ));
      expect(types(a), ['call', 'no_source']);
      expect((a.panels.last as NoSourcePanel).kind, NoSourceKind.noSource);
    });

    test('pipeline error on a risk phrase still shows the call panel', () async {
      final s = PipelineAnswerService(
        search: (_) async => throw StateError('db'),
        engine: FakeEngine([]),
        isRisk: (_) => true,
      );
      final a = ready(await s.answer('pożar', ctx).toList());
      expect(a.panels.first, isA<CallPanel>());
    });

    test('no risk: no call', () async {
      final a = ready(await run(svc(FakeEngine([[good()]]))));
      expect(a.panels.whereType<CallPanel>(), isEmpty);
    });
  });

  test('LlmUnavailable -> quotes with no_ai origin, not a crash', () async {
    final e = FakeEngine([const LlmUnavailable('Model AI jest niedostępny.')]);
    final ev = await run(svc(e));
    final a = ready(ev);
    expect(a.origin, AnswerOrigin.noAi);
    expect(types(a), ['quote', 'quote']);
    expect(e.requests.length, 1);
  });

  test('a model that is still downloading is explained under the quotes', () async {
    final e = FakeEngine([const LlmUnavailable('Model AI nie jest jeszcze pobrany.')]);
    final a = ready(await run(svc(e, modelNote: () => 'Model AI jeszcze się pobiera (46%).')));
    expect(a.origin, AnswerOrigin.noAi);
    expect(a.note, 'Model AI jeszcze się pobiera (46%).');
  });

  test('the timeout note is not replaced by the download note', () async {
    final e = FakeEngine([const LlmTimeout()]);
    final a = ready(await run(svc(e, modelNote: () => 'Model AI jeszcze się pobiera (46%).')));
    expect(a.note, kLlmTimeoutNote);
  });

  test('LlmTimeout and LlmDisabled behave the same', () async {
    for (final err in <LlmException>[const LlmTimeout(), const LlmDisabled(), const LlmError('x')]) {
      final a = ready(await run(svc(FakeEngine([err]))));
      expect(types(a), ['quote', 'quote'], reason: '$err');
    }
  });

  test('only LlmTimeout adds the timeout note', () async {
    final t = ready(await run(svc(FakeEngine([const LlmTimeout()]))));
    expect(t.note, 'Model nie odpowiedział na czas. Pokazuję fragmenty źródeł.');
    final d = ready(await run(svc(FakeEngine([const LlmDisabled()]))));
    expect(d.note, isNull);
  });

  test('fallback shows at most three quotes', () async {
    final many = [for (var i = 0; i < 4; i++) chunk('k$i', 'Tekst $i')];
    final a = ready(await run(svc(FakeEngine([const LlmTimeout()]), result: found(many))));
    expect(types(a), ['quote', 'quote', 'quote']);
  });

  group('cancel', () {
    test('cancelling the subscription cancels the engine and emits nothing more', () async {
      final e = FakeEngine([null]); // hangs
      final got = <AnswerEvent>[];
      final sub = svc(e).answer('pożar', ctx).listen(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(e.requests.length, 1);
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(e.cancelCalls, 1);
      expect(e.streamCancelled, isTrue);
      expect(got.whereType<AnswerReady>(), isEmpty);
      expect(got.whereType<AnswerFailed>(), isEmpty);
    });

    test('cancel during retrieval never calls the model', () async {
      final gate = Completer<RetrievalResult>();
      final e = FakeEngine([
        [good()],
      ]);
      final s = PipelineAnswerService(
        search: (_) => gate.future,
        engine: e,
        isRisk: (_) => false,
      );
      final sub = s.answer('pożar', ctx).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      gate.complete(found([lift]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(e.requests, isEmpty);
    });
  });

  test('retrieval exception becomes AnswerFailed, stream closes', () async {
    final s = PipelineAnswerService(
      search: (_) async => throw StateError('db'),
      engine: FakeEngine([]),
      isRisk: (_) => false,
    );
    final ev = await s.answer('x', ctx).toList();
    expect(ev.last, isA<AnswerFailed>());
  });

  test('profile failure does not break the answer', () async {
    final s = PipelineAnswerService(
      search: (_) async => found([lift]),
      engine: FakeEngine([
        [good()],
      ]),
      isRisk: (_) => false,
      profileContext: () async => throw StateError('x'),
    );
    expect(types(ready(await s.answer('pożar', ctx).toList())), ['steps']);
  });

  group('noAi (per-request "Tryb bez AI")', () {
    test('awaited setting true: model never called, no_ai quotes', () async {
      final e = FakeEngine([
        [good()],
      ]);
      final s = PipelineAnswerService(
        search: (_) async => found([lift]),
        engine: e,
        isRisk: (_) => false,
        noAi: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return true;
        },
      );
      final a = ready(await s.answer('pożar', ctx).toList());
      expect(e.requests, isEmpty);
      expect(a.origin, AnswerOrigin.noAi);
      expect(types(a), ['quote']);
    });

    test('false or failing setting keeps the model', () async {
      for (final f in <Future<bool> Function()>[
        () async => false,
        () async => throw StateError('settings'),
      ]) {
        final s = PipelineAnswerService(
          search: (_) async => found([lift]),
          engine: FakeEngine([
            [good()],
          ]),
          isRisk: (_) => false,
          noAi: f,
        );
        expect(types(ready(await s.answer('pożar', ctx).toList())), ['steps']);
      }
    });
  });
}
