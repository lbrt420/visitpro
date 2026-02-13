import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/app_localizations.dart';
import 'core/providers/locale_provider.dart';
import 'core/ui/theme.dart';
import 'router.dart';

class ServiceProofApp extends ConsumerWidget {
  const ServiceProofApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final localeOverride = ref.watch(localeOverrideProvider);
    return MaterialApp.router(
      title: AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      routerConfig: router,
      locale: localeOverride,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, _) {
        if (locale != null && locale.languageCode.toLowerCase() == 'es') {
          return const Locale('es');
        }
        return const Locale('en');
      },
    );
  }
}
