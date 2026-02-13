import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/app_localizations.dart';
import '../../providers/locale_provider.dart';

class LanguageDebugTile extends ConsumerWidget {
  const LanguageDebugTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final forceSpanish = ref.watch(forceSpanishDebugProvider);

    return Card(
      child: SwitchListTile(
        title: Text(l10n.forceSpanishDebug),
        subtitle: Text(l10n.forceSpanishDebugHelp),
        value: forceSpanish,
        onChanged: (value) {
          ref.read(forceSpanishDebugProvider.notifier).setEnabled(value);
        },
      ),
    );
  }
}
