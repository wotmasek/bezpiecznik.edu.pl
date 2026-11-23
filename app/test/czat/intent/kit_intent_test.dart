import 'package:bezpiecznik/czat/intent/kit_answer.dart';
import 'package:bezpiecznik/czat/intent/kit_intent.dart';
import 'package:bezpiecznik/czat/intent/shelter_intent.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const positives = [
    'plecak',
    'plecak ewakuacyjny',
    'Co spakować do plecaka?',
    'co spakowac do plecaka ewakuacyjnego',
    'co powinno być w plecaku ewakuacyjnym',
    'jak przygotować plecak ewakuacyjny',
    'lista rzeczy do plecaka',
    'plecka ewakuacyjny',
    'co zabrać na ewakuację',
    'co zapakować na wypadek ewakuacji',
    'zestaw ewakuacyjny',
    'plecak awaryjny',
    'jakie dokumenty spakować do plecaka',
  ];
  const negatives = [
    'gdzie schron',
    'gdzie jest najbliższy schron',
    'dziecko nie oddycha',
    'jak zatamować krwawienie',
    'jak zrobić RKO',
    'co spakować na wakacje',
    'plecak szkolny',
    'gdzie kupić plecak',
    'dlaczego warto mieć plecak',
    'placek z jabłkami',
    'przepis na pierogi',
    'jakie dokumenty zabrac przy ewakuacji',
    'Jakie dokumenty zabrać przy ewakuacji?',
    '',
  ];

  test('positives', () {
    for (final q in positives) {
      expect(detectKitIntent(q), isTrue, reason: q);
    }
  });

  test('negatives (first aid, shelter, off-topic)', () {
    for (final q in negatives) {
      expect(detectKitIntent(q), isFalse, reason: q);
    }
  });

  test('shelter phrases are not kit phrases and vice versa', () {
    expect(detectShelterIntent('co spakować do plecaka'), isNull);
  });

  test('answer: checkable bullets "Do plecaka", rules, PSP sources', () async {
    final a = await KitAnswerService().tryAnswer('co spakować do plecaka');
    expect(a, isNotNull);
    expect(a!.origin, AnswerOrigin.rules);
    expect(a.intent, 'kit');
    expect(a.verify, isTrue);
    final p = a.panels.single as TodoPanel;
    expect(p.title, 'Do plecaka');
    expect(p.title.length, lessThanOrEqualTo(30));
    expect(p.items.length, 46);
    expect(p.items.map((i) => i.kitId).toSet().length, 46);
    for (final i in p.items) {
      final s = a.source(i.sourceId);
      expect(s, isNotNull, reason: i.text);
      expect(s!.docId, 'psp-plecak-ewakuacyjny-lista');
      expect(s.pageLabel, '2');
      expect(i.kitId, isNotEmpty);
    }
    expect(p.items.map((i) => i.text), contains('Opaski zaciskowe – 10 szt.'));
    expect(p.items.map((i) => i.text), contains('Półmaska filtrująca FFP3'));
  });

  test('no intent -> null', () async {
    expect(await KitAnswerService().tryAnswer('gdzie schron'), isNull);
  });

  test('answer survives storage round-trip', () async {
    final a = (await KitAnswerService().tryAnswer('plecak'))!;
    final b = AssistantAnswer.fromJson(a.toJson());
    expect((b.panels.single as BulletsPanel).items.length, 46);
    expect(b.intent, 'kit');
  });
}
