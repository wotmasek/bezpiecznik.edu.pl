import 'package:material_ui/material_ui.dart';

import 'bz_theme.dart';

/// Design-system choice chip (`.bz-chip`): 40 dp tall stadium, 1 px
/// `line-150` border, `ink-100` label; on = `action` fill.
class BzChip extends StatelessWidget {
  const BzChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final fg = selected ? bz.onAction : bz.ink100;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? bz.action : const Color(0x00000000),
        shape: StadiumBorder(
          side: BorderSide(color: selected ? bz.action : bz.line150),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: height,
              maxHeight: height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
