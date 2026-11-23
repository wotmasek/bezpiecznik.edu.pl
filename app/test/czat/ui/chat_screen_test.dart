import 'dart:async';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/czat/templates/md_blocks.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/chat_screen.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_session.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_view.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/cpr/cpr_fakes.dart';

Future<ProviderContainer> pumpChat(
  WidgetTester tester,
  AnswerService service,
) async {
  final store = ChatStore.inMemory();
  final container = ProviderContainer(
    overrides: [
      answerServiceProvider.overrideWithValue(service),
      chatStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildBzTheme(), home: const ChatScreen()),
    ),
  );
  return container;
}

void main() {
  testWidgets('empty state: heading, 4 quick actions, note, composer hint', (
    tester,
  ) async {
    await pumpChat(tester, FakeAnswerService());
    expect(find.text('Co się dzieje?'), findsOneWidget);
    for (final l in [
      'Ktoś nie oddycha',
      'Brak prądu',
      'Alarm / schron',
      'Ewakuacja',
    ]) {
      expect(find.text(l), findsOneWidget);
    }
    expect(
      find.text('Działa bez internetu. Nie zastępuje 112.'),
      findsOneWidget,
    );
    expect(find.text('Opisz sytuację…'), findsOneWidget);
    expect(find.byKey(const Key('composer-stop')), findsNothing);
  });

  testWidgets('quick action tiles are at least 64 dp high', (tester) async {
    await pumpChat(tester, FakeAnswerService());
    for (final l in [
      'Ktoś nie oddycha',
      'Brak prądu',
      'Alarm / schron',
      'Ewakuacja',
    ]) {
      final tile = find
          .ancestor(of: find.text(l), matching: find.byType(Container))
          .first;
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(64));
    }
  });

  testWidgets(
    'tapping a quick action sends its label and hides the empty state',
    (tester) async {
      final service = FakeAnswerService();
      await pumpChat(tester, service);
      await tester.tap(find.text('Brak prądu'));
      await tester.pump();
      expect(service.questions, ['Brak prądu']);
      expect(find.text('Co się dzieje?'), findsNothing);
      expect(find.byKey(const Key('user-bubble')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'typing and sending shows a right-aligned bubble, then panels with a footnote',
    (tester) async {
      final service = FakeAnswerService();
      await pumpChat(tester, service);
      await tester.enterText(
        find.byKey(const Key('composer-field')),
        'Jak przechować insulinę?',
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.questions, ['Jak przechować insulinę?']);
      final bubble = find.byKey(const Key('user-bubble'));
      expect(bubble, findsOneWidget);
      expect(
        tester.getTopRight(bubble).dx,
        greaterThan(
          tester.view.physicalSize.width / tester.view.devicePixelRatio - 40,
        ),
      );
      expect(find.textContaining('Przykładowy krok pierwszy', findRichText: true), findsOneWidget);
      expect(find.byType(FootnoteMark), findsWidgets);
      // The input is cleared after sending.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composer-field')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('after sending, the composer no longer has focus', (
    tester,
  ) async {
    await pumpChat(tester, FakeAnswerService());
    await tester.tap(find.byKey(const Key('composer-field')));
    await tester.enterText(find.byKey(const Key('composer-field')), 'Pytanie');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isFalse);
    // Typing still works after tapping the field again.
    await tester.tap(find.byKey(const Key('composer-field')));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('send is disabled for empty or whitespace-only input', (
    tester,
  ) async {
    final service = FakeAnswerService();
    await pumpChat(tester, service);
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.enterText(find.byKey(const Key('composer-field')), '   ');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    expect(service.questions, isEmpty);
  });

  testWidgets('composer: hit targets are at least 48 dp', (tester) async {
    await pumpChat(
      tester,
      FakeAnswerService(
        script: (q, c) => StreamController<AnswerEvent>().stream,
      ),
    );
    await tester.enterText(find.byKey(const Key('composer-field')), 'x');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    for (final k in ['composer-send', 'composer-stop']) {
      final s = tester.getSize(find.byKey(Key(k)));
      expect(s.width, greaterThanOrEqualTo(48), reason: k);
      expect(s.height, greaterThanOrEqualTo(48), reason: k);
    }
  });

  testWidgets(
    'while generating: thinking skeleton, Stop and Send; Stop interrupts',
    (tester) async {
      final stream = StreamController<AnswerEvent>();
      final service = FakeAnswerService(script: (q, c) => stream.stream);
      final container = await pumpChat(tester, service);
      await tester.enterText(
        find.byKey(const Key('composer-field')),
        'Pytanie',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();

      expect(find.text('Szukam w źródłach…'), findsOneWidget);
      expect(find.byKey(const Key('composer-stop')), findsOneWidget);
      expect(find.byKey(const Key('composer-send')), findsOneWidget);
      // Stop is left of the field, Send right of it.
      expect(
        tester.getCenter(find.byKey(const Key('composer-stop'))).dx,
        lessThan(tester.getCenter(find.byKey(const Key('composer-field'))).dx),
      );

      stream.add(const AnswerThinking(ThinkingPhase.composing));
      stream.add(const AnswerPartialText('Wstępny tekst'));
      await tester.pump();
      expect(find.text('Układam odpowiedź…'), findsOneWidget);
      expect(find.text('Wstępny tekst'), findsOneWidget);

      await tester.tap(find.byKey(const Key('composer-stop')));
      await tester.pump();
      expect(find.text('Przerwano.'), findsOneWidget);
      expect(find.byKey(const Key('composer-stop')), findsNothing);
      expect(container.read(chatControllerProvider).generating, isFalse);
    },
  );

  testWidgets('sending during generation interrupts the running answer', (
    tester,
  ) async {
    final streams = <StreamController<AnswerEvent>>[];
    final service = FakeAnswerService(
      script: (q, c) {
        final s = StreamController<AnswerEvent>();
        streams.add(s);
        return s.stream;
      },
    );
    await pumpChat(tester, service);
    await tester.enterText(find.byKey(const Key('composer-field')), 'Pierwsze');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('composer-field')), 'Drugie');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();

    expect(service.questions, ['Pierwsze', 'Drugie']);
    expect(find.text('Przerwano.'), findsOneWidget);
    expect(find.text('Szukam w źródłach…'), findsOneWidget);
  });

  testWidgets('refusal answer renders NoSource text', (tester) async {
    await pumpChat(tester, const EchoQuoteAnswerService());
    await tester.tap(find.text('Ewakuacja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining('Nie wiem. Moje źródła tego nie opisują.'),
      findsOneWidget,
    );
    expect(find.textContaining('112'), findsNothing);
  });

  testWidgets(
    'pinned CPR host sits above the composer, no overflow at 360 dp / 1.5x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = Rig();
      final store = ChatStore.inMemory();
      final container = ProviderContainer(
        overrides: [
          answerServiceProvider.overrideWithValue(FakeAnswerService()),
          chatStoreProvider.overrideWithValue(store),
          cprSessionProvider.overrideWithValue(rig.session),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildBzTheme(),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ChatScreen(),
          ),
        ),
      );
      expect(find.byType(CprPinned), findsNothing);
      rig.session.start(rkoConfig(), 'adult');
      await tester.pump();
      expect(find.byType(CprPinned), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.byType(CprPinned)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy),
      );
      rig.session.stop();
      await tester.pump();
      expect(find.byType(CprPinned), findsNothing);
    },
  );

  testWidgets('new answer scrolls its start just below the island band', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = FakeAnswerService(
      script: (q, c) async* {
        yield const AnswerThinking();
        yield AnswerReady(
          AssistantAnswer.fromJson({
            'origin': 'ai',
            'panels': [
              {
                'type': 'steps',
                'title': 'Teraz $q',
                'items': [
                  for (var i = 0; i < 25; i++)
                    {'text': 'Krok $q-$i', 'source_id': 'fake-s1-f1'},
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
          }),
        );
      },
    );
    await pumpChat(tester, service);
    for (final q in ['A', 'B', 'C']) {
      await tester.enterText(find.byKey(const Key('composer-field')), q);
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }
    // Island band: 48 dp inset + 48 dp island + space2 (no status bar here).
    final bandBottom = 48 + 48 + BzTokens.dark.space2;
    final top = tester.getTopLeft(find.text('Teraz C')).dy;
    expect(
      top,
      greaterThanOrEqualTo(bandBottom - 0.5),
      reason: 'header under island',
    );
    // And it is the start of the answer, not stranded far below.
    expect(top, lessThan(bandBottom + 60));
  });

  testWidgets(
    'inserted assistant answer scrolls to its start below the island',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AssistantAnswer longAnswer(String title, int n) =>
          AssistantAnswer.fromJson({
            'origin': 'ai',
            'panels': [
              {
                'type': 'steps',
                'title': title,
                'items': [
                  for (var i = 0; i < n; i++)
                    {'text': 'Krok $title-$i', 'source_id': 'fake-s1-f1'},
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
      final service = FakeAnswerService(
        script: (q, c) async* {
          yield const AnswerThinking();
          yield AnswerReady(longAnswer('Stara', 25));
        },
      );
      final container = await pumpChat(tester, service);
      await tester.enterText(find.byKey(const Key('composer-field')), 'A');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      container
          .read(chatControllerProvider.notifier)
          .insertAssistantAnswer(longAnswer('Wstawka', 25));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final bandBottom = 48 + 48 + BzTokens.dark.space2;
      await tester.pump(const Duration(milliseconds: 500));
      final top = tester.getTopLeft(find.text('Wstawka')).dy;
      expect(top, greaterThanOrEqualTo(bandBottom - 0.5));
      expect(top, lessThan(bandBottom + 60));
    },
  );

  testWidgets('delayed 2nd tall answer lands at its start; no pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = FakeAnswerService(
      script: (q, c) async* {
        yield const AnswerThinking();
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        yield AnswerReady(
          AssistantAnswer.fromJson({
            'origin': 'ai',
            'panels': [
              {
                'type': 'steps',
                'title': 'Teraz $q',
                'items': [
                  for (var i = 0; i < 25; i++)
                    {'text': 'Krok $q-$i', 'source_id': 'fake-s1-f1'},
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
          }),
        );
      },
    );
    await pumpChat(tester, service);
    for (final q in ['A', 'B']) {
      await tester.enterText(find.byKey(const Key('composer-field')), q);
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }
    final bandBottom = 48 + 48 + BzTokens.dark.space2;
    final top = tester.getTopLeft(find.text('Teraz B')).dy;
    expect(top, greaterThanOrEqualTo(bandBottom - 0.5));
    expect(top, lessThan(bandBottom + 60));
    expect(find.byKey(const Key('jump-to-answer')), findsNothing);
  });

  testWidgets(
    'answer finishing before an inserted card scrolls to its own start',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AssistantAnswer tall(String title) => AssistantAnswer.fromJson({
        'origin': 'ai',
        'panels': [
          {
            'type': 'steps',
            'title': title,
            'items': [
              for (var i = 0; i < 25; i++)
                {'text': 'Krok $title-$i', 'source_id': 'fake-s1-f1'},
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
      final gate = Completer<void>();
      final service = FakeAnswerService(
        script: (q, c) async* {
          yield const AnswerThinking();
          await gate.future;
          yield AnswerReady(tall('Odpowiedz'));
        },
      );
      final container = await pumpChat(tester, service);
      await tester.enterText(find.byKey(const Key('composer-field')), 'A');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // [user, thinking] + inserted card while still generating.
      container
          .read(chatControllerProvider.notifier)
          .insertAssistantAnswer(tall('Wstawka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final bandBottom = 48 + 48 + BzTokens.dark.space2;
      final top = tester.getTopLeft(find.text('Odpowiedz')).dy;
      expect(top, greaterThanOrEqualTo(bandBottom - 0.5));
      expect(top, lessThan(bandBottom + 60));
    },
  );
}
