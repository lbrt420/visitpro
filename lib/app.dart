import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/app_localizations.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/session_provider.dart';
import 'core/notifications/push_notifications_service.dart';
import 'core/ui/theme.dart';
import 'features/properties/properties_controller.dart';
import 'features/visits/visits_controller.dart';
import 'router.dart';

class ServiceProofApp extends ConsumerStatefulWidget {
  const ServiceProofApp({super.key});

  @override
  ConsumerState<ServiceProofApp> createState() => _ServiceProofAppState();
}

class _ServiceProofAppState extends ConsumerState<ServiceProofApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationsService.instance.setOnForegroundMessage(_handlePushEvent);
    PushNotificationsService.instance.setOnNotificationOpened(_handlePushEvent);
  }

  @override
  void dispose() {
    PushNotificationsService.instance.setOnForegroundMessage(null);
    PushNotificationsService.instance.setOnNotificationOpened(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFeedData();
    }
  }

  Future<void> _handlePushEvent(RemoteMessage message) async {
    _refreshFeedData();
    final visitId = (message.data['visitId'] ?? '').toString().trim();
    if (visitId.isEmpty) {
      return;
    }
    ref.read(routerProvider).go('/home?visitId=$visitId');
  }

  void _refreshFeedData() {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      return;
    }
    ref.invalidate(propertiesProvider);
    ref.invalidate(visitsByPropertyProvider);
    ref.invalidate(clientFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
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
