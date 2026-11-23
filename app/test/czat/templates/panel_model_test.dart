import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatPanel.fromJson', () {
    test('steps with items', () {
      final p = ChatPanel.fromJson({
        'type': 'steps',
        'title': 'Teraz',
        'read_aloud': true,
        'items': [
          {'text': 'Krok 1', 'source_id': 'a'},
          {'text': 'Krok 2', 'source_id': 'b'},
        ],
      });
      expect(p, isA<StepsPanel>());
      final s = p as StepsPanel;
      expect(s.title, 'Teraz');
      expect(s.readAloud, isTrue);
      expect(s.items.map((e) => e.text), ['Krok 1', 'Krok 2']);
      expect(s.items.first.sourceId, 'a');
      expect(s.variantOptions, isEmpty);
      expect(s.itemsFor(null), hasLength(2));
    });

    test('steps with variants', () {
      final s = ChatPanel.fromJson({
        'type': 'steps',
        'title': 'RKO',
        'variants': [
          {
            'id': 'adult',
            'label': 'Dorosły',
            'items': [
              {'text': 'A', 'source_id': 'x'},
            ],
          },
          {
            'id': 'child',
            'label': 'Dziecko',
            'items': [
              {'text': 'B', 'source_id': 'x'},
              {'text': 'C', 'source_id': 'x'},
            ],
          },
          {'id': 'broken', 'items': []},
        ],
      }) as StepsPanel;
      expect(s.variantOptions.map((o) => o.id), ['adult', 'child']);
      expect(s.variantOptions.last.label, 'Dziecko');
      expect(s.itemsFor('child'), hasLength(2));
      expect(s.itemsFor('nope').single.text, 'A', reason: 'falls back to the first variant');
    });

    test('legacy checkable bullets parse as todo (kit_id kept)', () {
      final b = ChatPanel.fromJson({
        'type': 'bullets',
        'title': 'Do plecaka',
        'checkable': true,
        'items': [
          {'text': 'Woda', 'source_id': 's', 'kit_id': 'water'},
        ],
      }) as TodoPanel;
      expect(b.items.single.kitId, 'water');
    });

    test('quote needs source_id; title defaults to Źródło', () {
      final q = ChatPanel.fromJson({'type': 'quote', 'source_id': 'p-s1'}) as QuotePanel;
      expect(q.sourceId, 'p-s1');
      expect(q.title, 'Źródło');
      expect(ChatPanel.fromJson({'type': 'quote'}), isA<UnknownPanel>());
    });

    test('no_source kinds', () {
      expect(
        (ChatPanel.fromJson({'type': 'no_source'}) as NoSourcePanel).kind,
        NoSourceKind.noSource,
      );
      expect(
        (ChatPanel.fromJson({'type': 'no_source', 'kind': 'off_topic'}) as NoSourcePanel).kind,
        NoSourceKind.offTopic,
      );
    });

    test('tool and card panels', () {
      expect(ChatPanel.fromJson({'type': 'call'}), isA<CallPanel>());
      final cpr = ChatPanel.fromJson({
        'type': 'cpr',
        'source_id': 'x',
        'variants': [
          {'id': 'adult', 'label': 'Dorosły'},
        ],
      }) as CprPanel;
      expect(cpr.sourceId, 'x');
      expect(cpr.variantOptions.single.id, 'adult');
      expect((ChatPanel.fromJson({'type': 'map', 'target': 'nearest_water'}) as MapPanel).target,
          'nearest_water');
      expect((ChatPanel.fromJson({'type': 'signal'}) as SignalPanel).modes,
          ['sound', 'flashlight', 'screen']);
      expect((ChatPanel.fromJson({'type': 'signal', 'modes': ['sound']}) as SignalPanel).modes,
          ['sound']);
      final a = ChatPanel.fromJson({
        'type': 'animation',
        'caption': 'Dłonie',
        'source_id': 's',
        'variants': {'adult': 'a1'},
      }) as AnimationPanel;
      expect(a.variants, {'adult': 'a1'});
      expect(a.caption, 'Dłonie');
    });

    test('unknown type is UnknownPanel and keeps its raw json', () {
      final p = ChatPanel.fromJson({'type': 'hologram', 'x': 1});
      expect(p, isA<UnknownPanel>());
      expect(p.type, 'hologram');
      expect(p.raw['x'], 1);
    });

    test('malformed input never throws', () {
      for (final bad in <Object?>[
        null,
        42,
        'steps',
        [],
        {},
        {'type': 5},
        {'type': 'steps'},
        {'type': 'steps', 'items': 'nope'},
        {'type': 'steps', 'items': [1, null, {'text': ''}, {'source_id': 'x'}]},
        {'type': 'steps', 'variants': 'x'},
        {'type': 'bullets', 'items': []},
        {'type': 'signal', 'modes': 'sound'},
        {'type': 'cpr', 'variants': [1, {'label': 'x'}]},
      ]) {
        expect(() => ChatPanel.fromJson(bad), returnsNormally, reason: '$bad');
      }
      expect(ChatPanel.fromJson({'type': 'steps', 'items': [1, null]}), isA<UnknownPanel>());
      expect(ChatPanel.fromJson({'type': 'bullets', 'items': []}), isA<UnknownPanel>());
    });

    test('items without text are dropped, the rest kept', () {
      final s = ChatPanel.fromJson({
        'type': 'steps',
        'title': 't',
        'items': [
          {'text': '  '},
          {'text': 'ok', 'source_id': 'x'},
          'junk',
        ],
      }) as StepsPanel;
      expect(s.items.single.text, 'ok');
    });
  });

  group('SourceRecord', () {
    const json = {
      'source_id': 'poradnik-2025-s14-f3',
      'doc_id': 'poradnik',
      'doc_title': 'Poradnik bezpieczeństwa',
      'doc_short': 'Poradnik bezp.',
      'publisher': 'RCB, MON, MSWiA',
      'issued': '2025',
      'page_label': '14',
      'pdf_page': 16,
      'pdf_file': 'poradnik/poradnik.pdf',
      'text': 'Fragment.',
      'rects': [
        [0.1, 0.2, 0.3, 0.4],
        [1, 2, 3],
        'x',
      ],
    };

    test('chip text is "▸ {doc_short}, s. {page_label}"', () {
      final r = SourceRecord.tryParse(json)!;
      expect(r.chipLabel, '▸ Poradnik bezp., s. 14');
      expect(r.semanticLabel, 'Źródło: Poradnik bezpieczeństwa, strona 14. Otwórz.');
      expect(r.pdfPage, 16);
      expect(r.rects, [
        [0.1, 0.2, 0.3, 0.4],
      ], reason: 'malformed rects are dropped');
    });

    test('text falls back to "original"; missing id fails', () {
      expect(SourceRecord.tryParse({'source_id': 'a', 'original': 'O'})!.text, 'O');
      expect(SourceRecord.tryParse({'doc_short': 'x'}), isNull);
      expect(SourceRecord.tryParse('x'), isNull);
      expect(SourceRecord.tryParse({'doc_short': 'x'}, fallbackId: 'k')!.sourceId, 'k');
    });

    test('toJson round-trips', () {
      final r = SourceRecord.tryParse(json)!;
      expect(SourceRecord.tryParse(r.toJson()), r);
    });
  });

  group('AssistantAnswer', () {
    test('parses panels, sources (map and list), verify, card_id, origin', () {
      final src = {'source_id': 'a', 'doc_short': 'D', 'page_label': '1'};
      final a = AssistantAnswer.fromJson({
        'origin': 'rescue_card',
        'card_id': 'rko',
        'verify': true,
        'selected_variant': 'child',
        'panels': [
          {'type': 'call'},
          {'type': 'zzz'},
        ],
        'sources': {'a': src},
      });
      expect(a.origin, AnswerOrigin.rescueCard);
      expect(a.cardId, 'rko');
      expect(a.verify, isTrue);
      expect(a.selectedVariant, 'child');
      expect(a.panels, hasLength(2));
      expect(a.visiblePanels, hasLength(1));
      expect(a.source('a')!.docShort, 'D');
      expect(a.source('missing'), isNull);

      final fromList = AssistantAnswer.fromJson({
        'panels': [],
        'sources': [src],
      });
      expect(fromList.sources.keys, ['a']);
      expect(fromList.origin, AnswerOrigin.ai, reason: 'default origin');
    });

    test('garbage gives an empty answer', () {
      expect(AssistantAnswer.fromJson(null).panels, isEmpty);
      expect(AssistantAnswer.fromJson({'panels': 3, 'sources': 'x'}).panels, isEmpty);
    });

    test('withDone / selected variant survive toJson -> fromJson', () {
      var a = AssistantAnswer.fromJson({
        'panels': [
          {
            'type': 'steps',
            'title': 't',
            'items': [
              {'text': 'a'},
            ],
          },
        ],
      });
      a = a.withDone(0, 'adult', 1, true).withDone(0, 'adult', 0, true).withDone(0, 'adult', 0, false);
      a = a.copyWith(selectedVariant: 'infant');
      final back = AssistantAnswer.fromJson(jsonDecode(jsonEncode(a.toJson())));
      expect(back.doneFor(0, 'adult'), {1});
      expect(back.doneFor(0, 'child'), isEmpty);
      expect(back.selectedVariant, 'infant');
      expect(back.panels.single, isA<StepsPanel>());
    });
  });

  group('fixtures', () {
    final dir = Directory('test/fixtures/templates');

    test('every fixture file parses into at least one known panel (except unknown_ignored)', () {
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final a = AssistantAnswer.fromJson(jsonDecode(f.readAsStringSync()));
        expect(a.visiblePanels, isNotEmpty, reason: f.path);
      }
    });

    test('unknown_ignored keeps the unknown panel out of visiblePanels', () {
      final a = AssistantAnswer.fromJson(
        jsonDecode(File('test/fixtures/templates/unknown_ignored.json').readAsStringSync()),
      );
      expect(a.panels, hasLength(2));
      expect(a.visiblePanels.single, isA<StepsPanel>());
    });

    test('Dart constants are a copy of the JSON files (regenerate with gen_fixtures.py)', () {
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      expect(templateFixtures.keys.toSet(), {
        for (final f in files) f.uri.pathSegments.last.replaceFirst('.json', ''),
      });
      for (final e in templateFixtures.entries) {
        final file = File('test/fixtures/templates/${e.key}.json');
        expect(jsonDecode(e.value), jsonDecode(file.readAsStringSync()), reason: e.key);
      }
    });
  });
}
