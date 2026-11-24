// Conversation eval (M0): runs content/tests/conversation_eval.jsonl through the
// public AnswerService (pipelineAnswerServiceProvider) with the host llama-server.
//   BZ_CONV_EVAL=1 BZ_CONV_LABEL=baseline flutter test test/eval/conversation_eval_test.dart
// Env: BZ_CONV_LABEL (default "run"), BZ_EVAL_URL, BZ_CONV_ONLY (comma ids),
// BZ_CONV_PAR (parallel cases, default 2), BZ_CONV_OUT (default ../research/eval).
// Uses only AnswerService / ChatContext / the provider, so it survives pipeline rewrites.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_host.dart';
import 'package:bezpiecznik/czat/llm/llm_provider.dart';
import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/retrieval/retrieval_provider.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';
import 'package:bezpiecznik/ustawienia/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final bool _on = Platform.environment['BZ_CONV_EVAL'] == '1';

const _testProfile = HouseholdProfile(
  members: [Member(ageGroup: AgeGroup.adult), Member(ageGroup: AgeGroup.child)],
  pets: {'dog'},
  home: Home(floor: 0, elevator: false),
);

class _FixedProfile extends ProfileNotifier {
  @override
  Future<HouseholdProfile> build() async => _testProfile;
}

class _FixedSettings extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

String _norm(String s) {
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  var o = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    o = o.replaceAll(from[i], to[i]);
  }
  return o;
}

bool _hit(String text, String spec) {
  final t = _norm(text);
  return spec.split('|').any((a) => t.contains(_norm(a)));
}

void _strings(Object? v, List<String> out, [String? key]) {
  if (v is String) {
    if (!const {'type', 'source_id', 'kind', 'target', 'kit_id', 'card_id'}.contains(key)) out.add(v);
  } else if (v is Map) {
    v.forEach((k, x) => _strings(x, out, k.toString()));
  } else if (v is List) {
    for (final x in v) {
      _strings(x, out, key);
    }
  }
}

String _panelText(AssistantAnswer a, ChatPanel p) {
  if (p is ChatTextPanel) return p.text;
  if (p is QuotePanel) return a.sources[p.sourceId]?.text ?? '';
  final o = <String>[];
  _strings(p.raw, o);
  return o.join('\n');
}

const _openers = ['rozumiem', 'oczywiscie', 'swietne pytanie', 'dobre pytanie', 'jasne,', 'z checia', 'dziekuje za'];
const _greet = ['dzien dobry', 'czesc', 'witaj', 'hej', 'dobry wieczor'];

String? _opener(String question, String answer) {
  final a = _norm(answer.trimLeft());
  for (final o in _openers) {
    if (a.startsWith(o)) return o;
  }
  if (a.startsWith('dzien dobry') && !_greet.any(_norm(question).contains)) return 'dzien dobry';
  return null;
}

Future<Map<String, Object?>> _runCase(AnswerService svc, Map<String, dynamic> c) async {
  final turns = (c['turns'] as List).cast<String>();
  final inc = (c['must_include'] as List).cast<String>();
  final exc = (c['must_not_include'] as List).cast<String>();
  final target = c['max_tokens_target'] as int;
  final history = <ChatTurn>[];
  String? prev;
  final rows = <Map<String, Object?>>[];
  for (var i = 0; i < turns.length; i++) {
    final q = turns[i];
    final sw = Stopwatch()..start();
    AssistantAnswer? ans;
    String? err;
    try {
      final events = await svc
          .answer(q, ChatContext(chatId: 'conv-${c['id']}', previousQuestion: prev, history: List.of(history)))
          .toList()
          .timeout(const Duration(minutes: 4));
      for (final e in events) {
        if (e is AnswerReady) ans = e.answer;
        if (e is AnswerFailed) err = e.message;
      }
      err ??= ans == null ? 'no answer' : null;
    } catch (e) {
      err = '$e';
    }
    sw.stop();
    final panels = ans?.panels ?? const <ChatPanel>[];
    final text = err != null && ans == null ? err : panels.map((p) => _panelText(ans!, p)).where((s) => s.isNotEmpty).join('\n');
    final last = i == turns.length - 1;
    final canned = panels.any((p) => p is NoSourcePanel) || _norm(text).contains('nie wiem. moje zrodla');
    final missing = last ? [for (final s in inc) if (!_hit(text, s)) s] : <String>[];
    final banned = [for (final s in exc) if (_hit(text, s)) s];
    final opener = _opener(q, text);
    final nSrc = ans?.sources.length ?? 0;
    final es = c['expect_sources'];
    final srcBad = last && ((es == true && nSrc == 0) || (es == false && nSrc > 0));
    final tokens = (text.length * 0.31).round();
    final cannedBad = canned && c['expect_no_canned_refusal'] == true;
    rows.add({
      'case': c['id'],
      'category': c['category'],
      'turn': i,
      'question': q,
      'answer': text,
      'panel_types': [for (final p in panels) p.type],
      'sources': nSrc,
      'latency_ms': sw.elapsedMilliseconds,
      'tokens': tokens,
      'over_target': tokens > target,
      'banned_opener': opener,
      'canned_refusal': canned,
      'missing_include': missing,
      'banned_hit': banned,
      'call_panel': panels.any((p) => p is CallPanel),
      'sources_mismatch': srcBad,
      'error': err,
      'pass': err == null && !cannedBad && missing.isEmpty && banned.isEmpty && opener == null && !srcBad,
    });
    final chat = panels.any((p) => p is ChatTextPanel);
    history
      ..add((user: true, text: q, chat: false))
      ..add((user: false, text: text, chat: chat));
    if (history.length > 6) history.removeRange(0, history.length - 6);
    prev = q;
  }
  return {'rows': rows};
}

void main() {
  test('conversation eval', () async {
    final label = Platform.environment['BZ_CONV_LABEL'] ?? 'run';
    final only = (Platform.environment['BZ_CONV_ONLY'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
    final par = int.tryParse(Platform.environment['BZ_CONV_PAR'] ?? '') ?? 2;
    final url = Platform.environment['BZ_EVAL_URL'] ?? 'http://127.0.0.1:8080';
    final cases = [
      for (final l in File('../content/tests/conversation_eval.jsonl').readAsLinesSync())
        if (l.trim().isNotEmpty) jsonDecode(l) as Map<String, dynamic>,
    ].where((c) => only.isEmpty || only.contains(c['id'])).toList();

    final kb = KbDatabase(sqlite3.open('assets/generated/kb.sqlite', mode: OpenMode.readOnly));
    final retriever = Retriever(kb, stopwords: parseStopwords(File('assets/kb/stopwords.txt').readAsStringSync()));
    final risk = RiskDetector(
      risk: jsonDecode(File('assets/phrases/risk.json').readAsStringSync()) as Map<String, dynamic>,
      cardsIndex: jsonDecode(File('assets/phrases/cards_index.json').readAsStringSync()) as Map<String, dynamic>,
    );
    final container = ProviderContainer(overrides: [
      llmEngineProvider.overrideWith((ref) {
        final e = HostLlmEngine(baseUrl: url);
        ref.onDispose(e.dispose);
        return e;
      }),
      retrieverProvider.overrideWith((ref) async => retriever),
      answerRiskDetectorProvider.overrideWith((ref) async => risk),
      profileProvider.overrideWith(_FixedProfile.new),
      settingsProvider.overrideWith(_FixedSettings.new),
    ]);
    final svc = container.read(pipelineAnswerServiceProvider);

    final all = <Map<String, Object?>>[];
    var next = 0;
    Future<void> worker() async {
      while (next < cases.length) {
        final c = cases[next++];
        final r = await _runCase(svc, c);
        final rows = (r['rows'] as List).cast<Map<String, Object?>>();
        all.addAll(rows);
        stdout.writeln('${c['id']} ${rows.every((x) => x['pass'] == true) ? 'PASS' : 'FAIL'} '
            '${rows.map((x) => '${x['latency_ms']}ms/${x['tokens']}t').join(' ')}');
      }
    }

    await Future.wait([for (var i = 0; i < par; i++) worker()]);
    all.sort((a, b) {
      final k = (a['case'] as String).compareTo(b['case'] as String);
      return k != 0 ? k : (a['turn'] as int).compareTo(b['turn'] as int);
    });
    final out = Directory(Platform.environment['BZ_CONV_OUT'] ?? '../research/eval')..createSync(recursive: true);
    File('${out.path}/$label.jsonl').writeAsStringSync(all.map(jsonEncode).map((s) => '$s\n').join());
    File('${out.path}/$label.md').writeAsStringSync(_markdown(label, all));
    kb.close();
    container.dispose();
  }, skip: _on ? false : 'set BZ_CONV_EVAL=1', timeout: const Timeout(Duration(minutes: 90)));
}

int _median(List<int> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  return s[s.length ~/ 2];
}

String _markdown(String label, List<Map<String, Object?>> rows) {
  final cats = <String, List<Map<String, Object?>>>{};
  for (final r in rows) {
    cats.putIfAbsent(r['category'] as String, () => []).add(r);
  }
  // A case passes when all its turns pass.
  bool casePass(Iterable<Map<String, Object?>> rs) => rs.every((r) => r['pass'] == true);
  final b = StringBuffer('# Conversation eval: $label\n\n')
    ..writeln('| category | cases | pass | turns | median tokens | median ms | canned refusals | banned openers | missing must_include | banned hits | over target |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  void line(String name, List<Map<String, Object?>> rs) {
    final byCase = <String, List<Map<String, Object?>>>{};
    for (final r in rs) {
      byCase.putIfAbsent(r['case'] as String, () => []).add(r);
    }
    final pass = byCase.values.where(casePass).length;
    b.writeln('| $name | ${byCase.length} | $pass/${byCase.length} (${(100 * pass / byCase.length).round()}%) | ${rs.length} '
        '| ${_median([for (final r in rs) r['tokens'] as int])} | ${_median([for (final r in rs) r['latency_ms'] as int])} '
        '| ${rs.where((r) => r['canned_refusal'] == true).length} '
        '| ${rs.where((r) => r['banned_opener'] != null).length} '
        '| ${rs.where((r) => (r['missing_include'] as List).isNotEmpty).length} '
        '| ${rs.where((r) => (r['banned_hit'] as List).isNotEmpty).length} '
        '| ${rs.where((r) => r['over_target'] == true).length} |');
  }
  cats.forEach(line);
  line('**ALL**', rows);

  // Worst: score by number of problems, then tokens.
  int score(Map<String, Object?> r) =>
      (r['pass'] == true ? 0 : 1) * 10 +
      (r['canned_refusal'] == true ? 3 : 0) +
      (r['banned_opener'] != null ? 1 : 0) +
      (r['missing_include'] as List).length * 2 +
      (r['banned_hit'] as List).length * 2 +
      (r['error'] != null ? 5 : 0) +
      (r['sources_mismatch'] == true ? 1 : 0);
  final worst = [...rows]..sort((a, b) => score(b).compareTo(score(a)));
  b.writeln('\n## Worst 10 answers\n');
  for (final r in worst.take(10)) {
    b.writeln('### ${r['case']} turn ${r['turn']} (${r['category']}), score ${score(r)}\n');
    b.writeln('- question: ${r['question']}');
    b.writeln('- panels: ${r['panel_types']}, sources ${r['sources']}, ${r['latency_ms']} ms, ~${r['tokens']} tokens');
    b.writeln('- canned: ${r['canned_refusal']}, opener: ${r['banned_opener']}, missing: ${r['missing_include']}, banned: ${r['banned_hit']}, error: ${r['error']}');
    b.writeln('\n```text\n${(r['answer'] as String).trim()}\n```\n');
  }
  return b.toString();
}
