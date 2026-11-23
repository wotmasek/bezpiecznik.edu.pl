import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ratunek/ui/rescue_answer.dart';
import 'answer/pipeline_answer_service.dart';
import 'intent/kit_answer.dart';
import 'intent/map_answer.dart';
import 'ui/answer_service.dart';

/// Production answer order (spec ekran-1-czat.md, zakres-mvp.md):
/// 1. risk phrase → rescue card, no model (< 1 s);
/// 2. shelter / where-to-go / hospital intent → `map` template, no model;
/// 3. "plecak / co spakować" → `todo` list from the PSP list, no model;
/// 4. everything else → the sourced answer pipeline (retrieval + model).
class RoutedAnswerService implements AnswerService {
  RoutedAnswerService({
    required this.rescue,
    required this.map,
    required this.pipeline,
    this.kit,
  });

  final Future<RescueAnswerService> Function() rescue;
  final MapAnswerService map;
  final KitAnswerService? kit;
  final AnswerService pipeline;

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) async* {
    // A broken card bundle must not block the whole chat: fall through to the
    // pipeline, which adds `call` for risk phrases on its own.
    RescueAnswerService? cards;
    try {
      cards = await rescue();
    } on Object catch (e) {
      debugPrint('Rescue cards unavailable: $e');
    }
    final card = await cards?.tryAnswer(question);
    if (card != null) {
      yield AnswerReady(card);
      return;
    }
    final mapAnswer = await map.tryAnswer(question);
    if (mapAnswer != null) {
      // Risk phrase + place ("pożar, gdzie uciekać") still gets `call` first
      // (szablony-czatu.md, rule 2).
      final risky = cards?.isRisk(question) ?? false;
      yield AnswerReady(risky ? RescueAnswerService.withCallFirst(mapAnswer) : mapAnswer);
      return;
    }
    final kitAnswer = await kit?.tryAnswer(question);
    if (kitAnswer != null) {
      final risky = cards?.isRisk(question) ?? false;
      yield AnswerReady(risky ? RescueAnswerService.withCallFirst(kitAnswer) : kitAnswer);
      return;
    }
    yield* pipeline.answer(question, ctx);
  }
}

/// Wired as the default of `answerServiceProvider`.
final routedAnswerServiceProvider = Provider<AnswerService>(
  (ref) => RoutedAnswerService(
    rescue: () => ref.read(rescueAnswerServiceProvider.future),
    map: ref.watch(mapAnswerServiceProvider),
    kit: ref.watch(kitAnswerServiceProvider),
    pipeline: ref.watch(pipelineAnswerServiceProvider),
  ),
);
