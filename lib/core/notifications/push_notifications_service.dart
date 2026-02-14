import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/service_proof_api.dart';

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  bool _initialized = false;
  Future<void> Function(String token)? _onTokenRefresh;
  Future<void> Function(RemoteMessage message)? _onForegroundMessage;
  Future<void> Function(RemoteMessage message)? _onNotificationOpened;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _notificationOpenSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  RemoteMessage? _pendingInitialMessage;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _requestPermission();

    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? 'No title';
      final body = message.notification?.body ?? 'No body';
      debugPrint('Push received in foreground: $title - $body');
      final callback = _onForegroundMessage;
      if (callback == null) {
        return;
      }
      try {
        await callback(message);
      } catch (_) {
        // Best-effort UI refresh callback.
      }
    });

    _notificationOpenSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final callback = _onNotificationOpened;
      if (callback == null) {
        return;
      }
      try {
        await callback(message);
      } catch (_) {
        // Best-effort UI refresh callback.
      }
    });

    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        final callback = _onTokenRefresh;
        if (callback == null) {
          return;
        }
        try {
          await callback(token);
        } catch (_) {
          // Best-effort refresh sync. App behavior should continue.
        }
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _pendingInitialMessage = initialMessage;
      final callback = _onNotificationOpened;
      if (callback != null) {
        _pendingInitialMessage = null;
        try {
          await callback(initialMessage);
        } catch (_) {
          // Best-effort UI refresh callback.
        }
      }
    }

    _initialized = true;
  }

  void setOnTokenRefresh(Future<void> Function(String token)? callback) {
    _onTokenRefresh = callback;
  }

  void setOnForegroundMessage(
    Future<void> Function(RemoteMessage message)? callback,
  ) {
    _onForegroundMessage = callback;
  }

  void setOnNotificationOpened(
    Future<void> Function(RemoteMessage message)? callback,
  ) {
    _onNotificationOpened = callback;
    final pendingMessage = _pendingInitialMessage;
    if (pendingMessage == null || callback == null) {
      return;
    }
    _pendingInitialMessage = null;
    callback(pendingMessage).catchError((_) {
      // Best-effort UI refresh callback.
    });
  }

  Future<String?> getCurrentToken() async {
    await _requestPermission();
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> registerCurrentToken({
    required ServiceProofApi api,
    required String authToken,
  }) async {
    final token = await getCurrentToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await api.registerPushToken(authToken: authToken, token: token);
  }

  Future<void> unregisterCurrentToken({
    required ServiceProofApi api,
    required String authToken,
  }) async {
    final token = await getCurrentToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await api.unregisterPushToken(authToken: authToken, token: token);
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? 'No title';
  debugPrint('Push received in background: $title');
}
