import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../wspolne/shell/sos_button.dart'
    show UriLauncher, defaultSosLauncher;
import '../../../wspolne/theme/bz_buttons.dart';
import '../template_registry.dart';

export '../../../alarm/panel/call_panel.dart' show call112Label;

/// Label of the pinned chat call button.
const String callButtonLabel = 'Zadzwoń 112';

/// Opens `tel:` / `sms:` links. The default is `url_launcher`; tests and the
/// shell override it. Dialling and sending always need the user's tap.
final callLauncherProvider = Provider<UriLauncher>((ref) => defaultSosLauncher);

/// `call` template: one full-width "Zadzwoń 112". The chat screen pins it
/// above the composer for a risk conversation; it dials only on a tap.
class CallPanelView extends ConsumerWidget {
  const CallPanelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => BzButton(
    key: const Key('call-112'),
    label: callButtonLabel,
    icon: LucideIcons.phone,
    variant: BzButtonVariant.sos,
    size: BzButtonSize.xl,
    fullWidth: true,
    onPressed: () =>
        ref.read(callLauncherProvider)(Uri(scheme: 'tel', path: '112')),
  );
}

/// Registers the real `call` template (replaces the placeholder).
void registerCallTemplate(TemplateRegistry r) =>
    r.register('call', (context, scope) => const CallPanelView());
