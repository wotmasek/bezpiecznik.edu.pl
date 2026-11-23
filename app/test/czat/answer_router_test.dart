import 'dart:io';

import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_provider.dart';
import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/retrieval/retrieval_provider.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/ustawienia/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'answer/fakes.dart';

/// Production wiring of `answerServiceProvider` (rescue card -> map intent
/// -> pipeline) with the real KB and a fake model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(FakeEngine engine) {
    final kb = KbDatabase(sqlite3.open('assets/generated/kb.sqlite', mode: OpenMode.readOnly));
    final stop = parseStopwords(File('assets/kb/stopwords.txt').readAsStringSync());
    final c = ProviderContainer(
      overrides: [
        retrieverProvider.overrideWith((ref) async => Retriever(kb, stopwords: stop)),
        llmEngineProvider.overrideWithValue(engine),
        profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
        settingsStoreProvider.overrideWithValue(SettingsStore.inMemory()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<AnswerEvent> last(ProviderContainer c, String q) async {
    final events = await c
        .read(answerServiceProvider)
        .answer(q, const ChatContext(chatId: 't'))
        .toList()
        .timeout(const Duration(seconds: 10));
    return events.last;
  }

  test('risk phrase -> rescue card, model not called', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'dziecko nie oddycha');
    expect(e, isA<AnswerReady>());
    expect((e as AnswerReady).answer.origin, AnswerOrigin.rescueCard);
    expect(engine.requests, isEmpty);
  });

  test('shelter intent -> map panel, model not called', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'gdzie jest najbliższy schron');
    expect((e as AnswerReady).answer.panels.single, isA<MapPanel>());
    expect(engine.requests, isEmpty);
  });

  test('Ewakuacja quick action -> backpack bullets + shelter map, no model', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'Ewakuacja');
    final panels = (e as AnswerReady).answer.panels;
    expect(panels.first, isA<BulletsPanel>());
    expect(panels.last, isA<MapPanel>());
    expect(engine.requests, isEmpty);
  });

  test('Alarm / schron quick action reaches the pipeline and gets the map', () async {
    final engine = FakeEngine([['{"panels":[]}']]);
    final e = await last(container(engine), 'Alarm / schron');
    final panels = (e as AnswerReady).answer.panels;
    expect(panels.last, isA<MapPanel>());
    expect(engine.requests, isNotEmpty);
  });

  test('off-topic -> one small-talk request; empty reply -> refusal', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'przepis na pierogi');
    expect((e as AnswerReady).answer.origin, AnswerOrigin.refusal);
    expect(engine.requests.single.systemPrompt, kChatSystemPrompt);
  });

  test('pipeline provider exists for KB questions', () async {
    final c = container(FakeEngine([]));
    expect(c.read(pipelineAnswerServiceProvider), isNotNull);
  });

  test('risk phrase + place -> map answer with call first', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'pożar, gdzie uciekać');
    final panels = (e as AnswerReady).answer.panels;
    expect(panels.first, isA<CallPanel>());
    expect(panels.whereType<MapPanel>(), hasLength(1));
    expect(engine.requests, isEmpty);
  });

  test('plecak -> todo list, model not called', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'co spakować do plecaka ewakuacyjnego');
    final answer = (e as AnswerReady).answer;
    expect(answer.origin, AnswerOrigin.rules);
    expect(answer.panels.single, isA<TodoPanel>());
    expect(engine.requests, isEmpty);
  });

  test('risk phrase + plecak -> call first', () async {
    final engine = FakeEngine([]);
    final e = await last(container(engine), 'pożar, co spakować do plecaka');
    final panels = (e as AnswerReady).answer.panels;
    expect(panels.first, isA<CallPanel>());
    expect(panels.whereType<BulletsPanel>(), hasLength(1));
  });

  test('schron still goes to the map, not the kit', () async {
    final e = await last(container(FakeEngine([])), 'gdzie jest najbliższy schron');
    expect((e as AnswerReady).answer.panels.single, isA<MapPanel>());
  });
}
