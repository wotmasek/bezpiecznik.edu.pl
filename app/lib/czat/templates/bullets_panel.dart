import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'md_blocks.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// `bullets`: an optional heading and a bulleted list, as plain text (no
/// card). A footnote `[n]` ends each run of items citing the same page.
class BulletsPanelView extends StatelessWidget {
  const BulletsPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final (title, items) = switch (scope.panel) {
      BulletsPanel(:final title, :final items) => (title, items),
      _ => ('', const <PanelItem>[]),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[MdHeading(title), SizedBox(height: t.space2)],
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : t.space1),
            child: MdListItem(
              marker: '•',
              child: MdItemText(
                text: items[i].text,
                footnote: footnoteAfter(scope.footnotes, scope.answer, items, i),
                onFootnote: scope.onShowSources,
              ),
            ),
          ),
      ],
    );
  }
}
