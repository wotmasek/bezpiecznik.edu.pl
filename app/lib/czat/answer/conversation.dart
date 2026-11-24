/// Conversation side of the chat (test on a Pixel 9, 2026-11-23): which
/// sentences are a personal crisis or a follow-up, and the crisis texts. Phrases are matched on
/// [normalizePl] text (lower case, no Polish letters), so "żyć" == "zyc".
library;

import '../../ratunek/detect/normalize.dart';

/// Suicidal thoughts, self-harm, panic. These never go to the guides: the
/// keyword search turned "nie chce mi się żyć" into first aid for a casualty
/// and "atak paniki" into an air-raid evacuation.
const List<String> kCrisisPhrases = [
  'nie chce mi sie zyc',
  'nie chce zyc',
  'nie chce juz zyc',
  'chce umrzec',
  'wolalbym umrzec',
  'wolalabym umrzec',
  'chce sie zabic',
  'zabije sie',
  'zabic sie',
  'samobojstw',
  'samobojcz',
  'odebrac sobie zycie',
  'zrobic sobie krzywde',
  'zrobie sobie krzywde',
  'skrzywdzic siebie',
  'tne sie',
  'ciac sie',
  'okaleczam',
  'samookalecz',
  'nie widze sensu',
  'nie ma sensu zyc',
  'lepiej gdyby mnie nie bylo',
  'atak paniki',
  'napad paniki',
  'atak leku',
  'panikuje',
  'mam panike',
];

/// [text] normalised and padded with spaces, for whole-word `contains`.
String _padded(String text) => ' ${normalizePl(text)} ';

bool _hasAny(String padded, List<String> phrases) =>
    phrases.any((p) => padded.contains(' $p'));

/// A personal crisis: self-harm, suicidal thoughts, panic.
bool isCrisis(String question) => _hasAny(_padded(question), kCrisisPhrases);

/// A follow-up that only makes sense with the previous question
/// ("a ile wody?", "i w nocy?").
bool isFollowUp(String question) =>
    RegExp(r'^(a|i|oraz|to)\s', caseSensitive: false).hasMatch(question.trim());

/// Always shown under a crisis reply, whatever the model wrote.
const String kCrisisHelpLine =
    'Zadzwoń pod 116 123 (telefon zaufania dla dorosłych). Jeśli jesteś w '
    'niebezpieczeństwie, dzwoń pod 112.';

/// Crisis reply when the model is unavailable.
const String kCrisisFallback =
    'Dobrze, że o tym piszesz. Nie musisz radzić sobie z tym w pojedynkę. '
    'Jestem tutaj i możesz pisać dalej.';
