/// Conversation side of the chat (test on a Pixel 9, 2026-11-23): which
/// sentences are talk rather than a question for the guides, which are a
/// personal crisis, and the reply prompt. Phrases are matched on
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

/// Talk about the assistant, thanks, greetings, the user's own profile:
/// always a conversational reply, whatever words the guides share with it.
const List<String> _talkPhrases = [
  'kim jestes',
  'czym jestes',
  'co potrafisz',
  'co umiesz',
  'jak sie czujesz',
  'jak sie masz',
  'jak myslisz',
  'na moim miejscu',
  'o mnie',
  'mieszka ze mna',
  'mieszkaja ze mna',
  'moj profil',
  'moim profilu',
  'jakie leki biore',
];

/// Greetings, thanks, feelings and relationships: a conversational reply
/// unless the sentence also asks how to do something ([_askWords]), e.g.
/// "cześć, jak zatamować krwawienie?" still goes to the guides.
const List<String> _feelingPhrases = [
  'dzieki',
  'dziekuje',
  'czesc',
  'hej',
  'dzien dobry',
  'dobry wieczor',
  'dobranoc',
  'smutn',
  'samotn',
  'boje sie',
  'martwie sie',
  'stresuj',
  'zestresowan',
  'zdenerwowan',
  'place',
  'placze',
  'poklocil',
  'klotni',
  'klocimy',
  'tesknie',
  'jestem zmeczon',
  'nie moge spac',
  'nie moge zasnac',
  'przykro mi',
  'jest mi zle',
  'jest mi ciezko',
  'mama',
  'mamy',
  'mamie',
  'tata',
  'taty',
  'zona',
  'maz',
  'dziewczyn',
  'chlopak',
  'przyjaciel',
  'rodzice',
  'rodzicami',
];

const List<String> _askWords = [
  'jak ',
  'co robic',
  'co zrobic',
  'co mam zrobic',
  'gdzie',
  'ile ',
  'co spakowac',
  'co przygotowac',
  'czy mam',
  'czy moge',
];

/// [text] normalised and padded with spaces, for whole-word `contains`.
String _padded(String text) => ' ${normalizePl(text)} ';

bool _hasAny(String padded, List<String> phrases) =>
    phrases.any((p) => padded.contains(' $p'));

/// A personal crisis: self-harm, suicidal thoughts, panic.
bool isCrisis(String question) => _hasAny(_padded(question), kCrisisPhrases);

/// A sentence for a conversational reply rather than a search in the guides.
bool isTalk(String question) {
  final q = _padded(question);
  if (_hasAny(q, _talkPhrases)) return true;
  return _hasAny(q, _feelingPhrases) && !_hasAny(q, _askWords);
}

/// A follow-up that only makes sense with the previous question
/// ("a ile wody?", "i w nocy?").
bool isFollowUp(String question) =>
    RegExp(r'^(a|i|oraz|to)\s', caseSensitive: false).hasMatch(question.trim());

/// System prompt of the conversational reply. The profile is appended by
/// [chatSystemPrompt].
const String kChatSystemPrompt =
    'Jesteś Bezpiecznikiem, spokojnym i życzliwym towarzyszem w aplikacji o '
    'bezpieczeństwie. Aplikacja ma poradniki (RKO, krwawienie, pożar, brak '
    'prądu, alarm, ewakuacja, plecak), mapę schronów i przycisk SOS.\n'
    'Rozmawiaj po polsku, naturalnie, 2–4 zdania. Najpierw wysłuchaj: powiedz '
    'własnymi słowami, co rozmówca przeżywa albo o co pyta. Potem zadaj jedno '
    'krótkie pytanie albo zaproponuj jeden zwykły, mały krok. Nawiązuj do tego, '
    'co padło wcześniej w rozmowie.\n'
    'Jesteś programem: nie wymyślaj swoich uczuć, wspomnień ani upodobań. '
    'Zapytany o siebie, powiedz krótko, czym jesteś i w czym pomagasz.\n'
    'O rozmówcy wiesz tylko to, co napisał, i to, co jest w profilu domu '
    'poniżej. Czego tam nie ma, tego nie wiesz; można to dopisać w profilu.\n'
    'Nie podawaj porad medycznych, dawek, liczb ani instrukcji ratunkowych. '
    'Zaproponuj, żeby zapytał w czacie o konkretną sytuację, a w nagłym '
    'wypadku zadzwonił pod 112. Nie używaj emotikonów.\n'
    'Jeśli ktoś pisze o zagrożeniu, przemocy, myślach o śmierci albo o '
    'zrobieniu sobie krzywdy: okaż troskę, napisz, że nie jest z tym sam, i '
    'poproś, żeby zadzwonił pod 116 123 (telefon zaufania dla dorosłych) '
    'albo pod 112, jeśli jest w niebezpieczeństwie.';

/// Added for a [isCrisis] sentence.
const String kCrisisPromptNote =
    '\nTa osoba może być teraz w kryzysie. Odpowiedz ciepło, bez oceniania, '
    '3–4 zdania. Zapytaj, czy jest teraz bezpieczna. Podaj 116 123 i 112.';

/// Always shown under a crisis reply, whatever the model wrote.
const String kCrisisHelpLine =
    'Zadzwoń pod 116 123 (telefon zaufania dla dorosłych). Jeśli jesteś w '
    'niebezpieczeństwie, dzwoń pod 112.';

/// Crisis reply when the model is unavailable.
const String kCrisisFallback =
    'Dobrze, że o tym piszesz. Nie jesteś z tym sam. Jestem tutaj i możesz '
    'pisać dalej.';

String chatSystemPrompt({String profile = '', bool crisis = false}) {
  final b = StringBuffer(kChatSystemPrompt);
  if (crisis) b.write(kCrisisPromptNote);
  b.write(
    profile.trim().isEmpty
        ? '\nProfil domu: pusty.'
        : '\nProfil domu: ${profile.trim()}',
  );
  return b.toString();
}

/// Characters of one past turn in the prompt (context is 2048 tokens).
const int kHistoryTurnChars = 240;

/// [text] cut to [kHistoryTurnChars] at a word end.
String clipTurn(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= kHistoryTurnChars) return t;
  final cut = t.lastIndexOf(' ', kHistoryTurnChars);
  return '${t.substring(0, cut > 0 ? cut : kHistoryTurnChars)}…';
}
