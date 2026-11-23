import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../templates/panel_model.dart';
import 'kit_intent.dart';

const String kKitAssetPath = 'assets/phrases/kit_psp.json';

/// Intent id stored on the answer (`AssistantAnswer.intent`).
const String kKitIntent = 'kit';

/// Answers "plecak / co spakować" with a `todo` panel
/// ("Do plecaka") from the PSP checklist, origin `rules`, no model
/// (ekran-1-czat.md, step 3). Items come only from `kit_psp.json`, generated
/// from the knowledge chunks of `psp-plecak-ewakuacyjny-lista` (page 2).
/// Household-specific additions are not added: the source has none.
class KitAnswerService {
  KitAnswerService([this._bundle]);

  final AssetBundle? _bundle;
  Future<Map<String, Object?>>? _data;

  Future<Map<String, Object?>> _load() => _data ??= () async {
    final raw = await (_bundle ?? rootBundle).loadString(kKitAssetPath);
    return Map<String, Object?>.from(jsonDecode(raw) as Map);
  }();

  /// Null when [question] carries no kit intent (or the asset is broken).
  Future<AssistantAnswer?> tryAnswer(String question) async {
    if (!detectKitIntent(question)) return null;
    try {
      final answer = build(await _load());
      if (!isEvacuationQuickAction(question)) return answer;
      return answer.copyWith(
        panels: [
          ...answer.panels,
          const MapPanel(
            target: 'nearest_shelter',
            raw: {'type': 'map', 'target': 'nearest_shelter'},
          ),
        ],
      );
    } on Object {
      _data = null;
      return null;
    }
  }

  /// Builds the answer from the decoded asset (exposed for tests).
  AssistantAnswer build(Map<String, Object?> data) {
    final items = data['items'] as List;
    final panel = {
      'type': 'todo',
      'title': data['title'] ?? 'Do plecaka',
      'items': items,
    };
    final used = {for (final i in items) (i as Map)['source_id']};
    final sources = [
      for (final s in data['sources'] as List)
        if (used.contains((s as Map)['source_id'])) s,
    ];
    return AssistantAnswer.fromJson({
      'origin': AnswerOrigin.rules.json,
      'verify': data['verify'] == true,
      'intent': kKitIntent,
      'panels': [panel],
      'sources': sources,
    });
  }
}

final kitAnswerServiceProvider = Provider<KitAnswerService>(
  (ref) => KitAnswerService(),
);
