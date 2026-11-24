import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart' show LiteRtLmEngine;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Probe of the on-device model (Gemma 4 E2B, CPU), 2026-11-24.
/// A: one live chat vs. a reopened chat per turn. B: native tool calling.
/// Needs `gemma-4-E2B-it.litertlm` and `bench_corpus.txt` in the app's
/// external files dir. Run (never without --no-uninstall, it wipes the model):
///   flutter test integration_test/tool_probe_test.dart --no-uninstall -d SERIAL
/// `--dart-define=PROBE=A`, `=B` or `=BQ` (B plus the Q12 tool-list check) picks what runs. Prints `PROBE:` lines.
const _probe = String.fromEnvironment('PROBE', defaultValue: 'ABQ');

const _system =
    'Jesteś Bezpiecznikiem — spokojnym asystentem bezpieczeństwa, który działa '
    'w telefonie bez internetu. Pomagasz ludziom w Polsce przygotować się na '
    'sytuacje kryzysowe: awarie prądu, powodzie, pożary, ewakuacje, zagrożenia '
    'militarne i nagłe wypadki. Odpowiadasz po polsku, krótko i konkretnie, '
    'najlepiej w punktach. Najpierw podajesz to, co trzeba zrobić teraz, potem '
    'to, co można zrobić później. Opierasz się na fragmentach poradnika, które '
    'dostajesz w wiadomości użytkownika; jeśli fragment nie odpowiada na '
    'pytanie, mówisz to wprost i podajesz ogólną, bezpieczną radę. Nie '
    'wymyślasz numerów telefonów, adresów ani nazw instytucji. W sytuacji '
    'zagrożenia życia zawsze przypominasz o numerze alarmowym 112. Nie '
    'udzielasz porad medycznych wykraczających poza pierwszą pomoc. Gdy '
    'użytkownik jest zdenerwowany, najpierw go uspokajasz jednym zdaniem. '
    'Nie powtarzasz pytania użytkownika i nie piszesz wstępów. Jeśli czegoś nie '
    'wiesz, mówisz, że nie wiesz. Pamiętasz, o czym była mowa wcześniej w '
    'rozmowie, i odnosisz się do tego, gdy użytkownik o to pyta. Twoje '
    'odpowiedzi mają mieścić się na jednym ekranie telefonu.';

const _questions = [
  'Na podstawie tego fragmentu: co mam zrobić najpierw? Wymień trzy kroki.',
  'Co z tego fragmentu dotyczy rodziny z małym dzieckiem?',
  'Czego według tego fragmentu nie wolno robić?',
  'Przypomnij jednym zdaniem, o co zapytałem w pierwszym pytaniu tej rozmowy.',
];

void _log(String m) => debugPrint('PROBE: t=${DateTime.now().millisecondsSinceEpoch} $m');

String _short(String s, [int n = 200]) {
  final one = s.replaceAll('\n', ' / ');
  return one.length > n ? one.substring(0, n) : one;
}

/// Streams one turn of [chat]; the user message must already be added.
Future<({int? ttft, int total, int chunks, String text, List<FunctionCallResponse> calls})> _turn(
  InferenceChat chat,
) async {
  final sw = Stopwatch()..start();
  int? ttft;
  var chunks = 0;
  final out = StringBuffer();
  final calls = <FunctionCallResponse>[];
  await for (final r in chat.generateChatResponseAsync()) {
    ttft ??= sw.elapsedMilliseconds;
    switch (r) {
      case TextResponse(:final token):
        chunks++;
        out.write(token);
      case FunctionCallResponse():
        calls.add(r);
      case ParallelFunctionCallResponse(calls: final cs):
        calls.addAll(cs);
      case ThinkingResponse():
        break;
    }
  }
  return (ttft: ttft, total: sw.elapsedMilliseconds, chunks: chunks, text: out.toString(), calls: calls);
}

String _metrics(InferenceChat chat) {
  try {
    final m = chat.session.getSessionMetrics();
    return 'm_in=${m.inputTokens} m_out=${m.outputTokens} m_ttft=${m.timeToFirstTokenMs?.toStringAsFixed(0)} '
        'm_tps=${m.tokensPerSecond?.toStringAsFixed(1)}';
  } catch (e) {
    return 'metrics_error=$e';
  }
}

Future<void> _experimentA(InferenceModel model, String corpus, double perChar) async {
  final sliceChars = (500 / perChar).round();
  final users = [
    for (var i = 0; i < 4; i++)
      'Fragment poradnika:\n${corpus.substring(i * 3 * sliceChars, i * 3 * sliceChars + sliceChars)}'
          '\n\nPytanie: ${_questions[i]}',
  ];
  final texts = <String>[];

  // Variant 1: one chat, only the new user message per turn.
  {
    final chat = await model.openChat(temperature: 0, systemInstruction: _system, maxOutputTokens: 160);
    for (var i = 0; i < 4; i++) {
      await chat.addQuery(Message.text(text: users[i], isUser: true));
      final r = await _turn(chat);
      texts.add(r.text);
      _log('A live turn=${i + 1} user_chars=${users[i].length} ttft_ms=${r.ttft} total_ms=${r.total} '
          'chunks=${r.chunks} ${_metrics(chat)} answer=${_short(r.text)}');
    }
    await chat.close();
  }

  // Variant 2: a new chat per turn, the whole history flattened into one message.
  final history = <String>[];
  for (var i = 0; i < 4; i++) {
    final prompt = [
      if (history.isNotEmpty) 'Dotychczasowa rozmowa:\n${history.join('\n\n')}\n\nNowa wiadomość użytkownika:',
      users[i],
    ].join('\n');
    final chat = await model.openChat(temperature: 0, systemInstruction: _system, maxOutputTokens: 160);
    await chat.addQuery(Message.text(text: prompt, isUser: true));
    final r = await _turn(chat);
    texts.add(r.text);
    _log('A reopen turn=${i + 1} prompt_chars=${prompt.length} ttft_ms=${r.ttft} total_ms=${r.total} '
        'chunks=${r.chunks} ${_metrics(chat)} answer=${_short(r.text)}');
    history
      ..add('Użytkownik: ${users[i]}')
      ..add('Asystent: ${r.text}');
    await chat.close();
  }

  // Seeding: can a fresh chat start from earlier turns, assistant ones included?
  {
    final chat = await model.openChat(temperature: 0, systemInstruction: _system, maxOutputTokens: 80);
    final sw = Stopwatch()..start();
    await chat.clearHistory(replayHistory: [
      const Message(text: 'Zapamiętaj: kod do skrytki w piwnicy to ZIELONY-47.', isUser: true),
      const Message(text: 'Zapamiętałem. Kod do skrytki w piwnicy to ZIELONY-47.', isUser: false),
    ]);
    final replayMs = sw.elapsedMilliseconds;
    await chat.addQuery(const Message(text: 'Jaki kod do skrytki podałem wcześniej?', isUser: true));
    final r = await _turn(chat);
    _log('A seed replay_ms=$replayMs ttft_ms=${r.ttft} total_ms=${r.total} ${_metrics(chat)} '
        'history_len=${chat.fullHistory.length} recalled=${r.text.contains('ZIELONY-47')} answer=${_short(r.text)}');
    await chat.close();
  }

  // Exact output token counts, after the chats are closed.
  final s = await model.openSession(temperature: 0, maxOutputTokens: 8);
  final userTok = [for (final u in users) await s.sizeInTokens(u)];
  _log('A tokens system=${await s.sizeInTokens(_system)} user_turns=$userTok '
      'out_live=${[for (final t in texts.take(4)) await s.sizeInTokens(t)]} '
      'out_reopen=${[for (final t in texts.skip(4)) await s.sizeInTokens(t)]}');
  await s.close();
}

const _tools = [
  Tool(
    name: 'get_profile',
    description: 'Odczytuje dane z profilu użytkownika: domownicy, leki, zwierzęta albo dom.',
    parameters: {
      'type': 'object',
      'properties': {
        'section': {
          'type': 'string',
          'enum': ['domownicy', 'leki', 'zwierzeta', 'dom'],
          'description': 'Która część profilu.',
        },
      },
      'required': ['section'],
    },
  ),
  Tool(
    name: 'map_find_place',
    description: 'Znajduje na mapie offline miejsce i prowadzi do niego, np. dom, schron, szpital.',
    parameters: {
      'type': 'object',
      'properties': {
        'what': {'type': 'string', 'description': 'Czego szukać, np. "dom", "schron", "szpital".'},
      },
      'required': ['what'],
    },
  ),
  Tool(
    name: 'show_form',
    description: 'Pokazuje użytkownikowi krótki formularz z pytaniami, gdy trzeba zebrać od niego informacje.',
    parameters: {
      'type': 'object',
      'properties': {
        'questions': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Pytania do użytkownika.',
        },
      },
      'required': ['questions'],
    },
  ),
];

const _cases = <(String, String)>[
  ('Ile osób mieszka ze mną?', 'get_profile'),
  ('Jakie leki biorę na stałe?', 'get_profile'),
  ('Czy mam w domu jakieś zwierzęta, o których trzeba pamiętać przy ewakuacji?', 'get_profile'),
  ('Jaki jest mój adres zamieszkania?', 'get_profile'),
  ('Gdzie jest najbliższy schron?', 'map_find_place'),
  ('Zaprowadź mnie do domu', 'map_find_place'),
  ('Jak dojść do najbliższego szpitala?', 'map_find_place'),
  ('Pokaż mi na mapie, gdzie mogę się schronić', 'map_find_place'),
  ('Pomóż mi przygotować plan, ale nie wiem od czego zacząć', 'show_form'),
  ('Chcę zrobić plan ewakuacji rodziny, zadawaj mi pytania', 'show_form'),
  ('Przygotuj ze mną listę rzeczy do plecaka ewakuacyjnego dopasowaną do mnie', 'show_form'),
  ('Jak zatamować krwawienie?', 'none'),
  ('Dzięki', 'none'),
  ('Co zrobić, gdy zabraknie prądu na kilka dni?', 'none'),
  ('Ile wody na osobę trzeba mieć w zapasie?', 'none'),
  ('Cześć, kim jesteś?', 'none'),
];

// `--dart-define=TOOL_HINT=true` adds one sentence that says what the tools reach.
const _toolHint = bool.fromEnvironment('TOOL_HINT');
const _toolSystem =
    'Jesteś Bezpiecznikiem — asystentem bezpieczeństwa w telefonie bez internetu. '
    'Odpowiadasz po polsku, krótko. Używaj narzędzi tylko wtedy, gdy są potrzebne.'
    '${_toolHint ? ' Masz dostęp do profilu użytkownika (adres, domownicy, leki, zwierzęta), '
        'do mapy offline z lokalizacją telefonu i schronami oraz do formularza, którym '
        'zbierasz odpowiedzi użytkownika, gdy czegoś o nim nie wiesz.' : ''}';

Future<void> _experimentB(InferenceModel model) async {
  var correct = 0;
  _log('B tool_hint=$_toolHint');
  for (final (prompt, expected) in _cases) {
    final chat = await model.openChat(
      temperature: 0,
      tools: _tools,
      supportsFunctionCalls: true,
      modelType: ModelType.gemma4,
      systemInstruction: _toolSystem,
      maxOutputTokens: 200,
    );
    await chat.addQuery(Message.text(text: prompt, isUser: true));
    String outcome;
    try {
      final r = await _turn(chat);
      final got = r.calls.isNotEmpty ? r.calls.first.name : 'none';
      final described = r.calls.isEmpty && _tools.any((t) => r.text.contains(t.name));
      outcome = r.calls.isNotEmpty
          ? 'tool ${[for (final c in r.calls) '${c.name}${c.args}']}'
          : described
              ? 'described'
              : 'text';
      final ok = got == expected && !described;
      if (ok) correct++;
      _log('B expected=$expected ok=$ok outcome=$outcome ttft_ms=${r.ttft} total_ms=${r.total} '
          '${_metrics(chat)} prompt="$prompt" text=${_short(r.text, 160)}');
    } catch (e) {
      _log('B expected=$expected ok=false outcome=ERROR $e prompt="$prompt"');
    }
    await chat.close();
  }
  _log('B accuracy=$correct/${_cases.length}');
  if (!_probe.contains('Q')) return;

  // Q12: can the tool list change inside one open chat?
  final tools = <Tool>[_tools.first];
  final chat = await model.openChat(
    temperature: 0,
    tools: tools,
    supportsFunctionCalls: true,
    modelType: ModelType.gemma4,
    systemInstruction: _toolSystem,
    maxOutputTokens: 200,
  );
  try {
    chat.tools.add(_tools[1]);
    _log('Q12 chat.tools.add succeeded len=${chat.tools.length}');
  } catch (e) {
    _log('Q12 chat.tools.add threw ${e.runtimeType}');
  }
  tools.add(_tools[1]);
  _log('Q12 after mutating the passed list chat.tools=${[for (final t in chat.tools) t.name]}');
  for (final step in ['same_session', 'after_clearHistory']) {
    if (step == 'after_clearHistory') await chat.clearHistory();
    await chat.addQuery(const Message(text: 'Zaprowadź mnie do domu', isUser: true));
    final r = await _turn(chat);
    _log('Q12 $step calls=${[for (final c in r.calls) '${c.name}${c.args}']} text=${_short(r.text, 160)}');
  }
  await chat.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tool probe', (tester) async {
    final dir = (await getExternalStorageDirectory())!.path;
    final corpus = await File(p.join(dir, 'bench_corpus.txt')).readAsString();
    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(p.join(dir, 'gemma-4-E2B-it.litertlm')).install();
    final sw = Stopwatch()..start();
    final model = await FlutterEdgeAi.getActiveModel(maxTokens: 4096, preferredBackend: PreferredBackend.cpu);
    final warm = await model.openSession(temperature: 0, maxOutputTokens: 8);
    final perChar = (await warm.sizeInTokens(corpus.substring(0, 8000))) / 8000;
    await warm.close();
    _log('load_ms=${sw.elapsedMilliseconds} tokens_per_char=${perChar.toStringAsFixed(3)} probe=$_probe');
    try {
      if (_probe.contains('A')) await _experimentA(model, corpus, perChar);
      if (_probe.contains('B')) await _experimentB(model);
    } catch (e, st) {
      _log('ERROR $e\n$st');
    } finally {
      await model.close();
    }
    _log('done');
  }, timeout: const Timeout(Duration(minutes: 35)));
}
