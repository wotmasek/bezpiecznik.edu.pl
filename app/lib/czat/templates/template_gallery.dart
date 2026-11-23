import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'form_panel.dart';
import 'panel_model.dart';
import 'template_fixtures.dart';
import 'template_renderer.dart';

/// Debug route path of [TemplateGalleryScreen] (the coordinator registers it).
const templateGalleryRoutePath = '/gallery/templates';

/// Renders every template fixture (`template_fixtures.dart`, a copy of
/// `test/fixtures/templates/*.json`) through [TemplateRenderer].
class TemplateGalleryScreen extends StatelessWidget {
  const TemplateGalleryScreen({super.key, this.fixtures = templateFixtures});

  final Map<String, String> fixtures;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Scaffold(
      backgroundColor: t.bg000,
      // A form's "Wyślij" shows the message instead of sending it to the chat.
      body: ProviderScope(
        overrides: [
          formSenderProvider.overrideWithValue(
            (text) =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(text))),
          ),
        ],
        child: ListView(
          padding: EdgeInsets.fromLTRB(t.space4, 96, t.space4, t.space6),
          children: [
            Text('Szablony czatu', style: t.title),
            SizedBox(height: t.space4),
            for (final e in fixtures.entries) ...[
              Text(e.key, style: t.caption.copyWith(color: t.ink300)),
              SizedBox(height: t.space2),
              _FixtureView(
                key: ValueKey('fixture-${e.key}'),
                answer: AssistantAnswer.fromJson(jsonDecode(e.value)),
              ),
              SizedBox(height: t.space5),
            ],
          ],
        ),
      ),
    );
  }
}

class _FixtureView extends StatefulWidget {
  const _FixtureView({super.key, required this.answer});

  final AssistantAnswer answer;

  @override
  State<_FixtureView> createState() => _FixtureViewState();
}

class _FixtureViewState extends State<_FixtureView> {
  late AssistantAnswer _answer = widget.answer;

  @override
  Widget build(BuildContext context) {
    return TemplateRenderer(
      answer: _answer,
      onChanged: (a) => setState(() => _answer = a),
    );
  }
}
