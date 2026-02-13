import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/service_proof_api.dart';
import '../notifications/push_notifications_service.dart';

enum UserRole { owner, worker, client }

const _sessionTokenKey = 'session_token';
const _sessionUserIdKey = 'session_user_id';
const _sessionUserNameKey = 'session_user_name';
const _sessionRoleKey = 'session_role';
const _sessionCompanyAccessLevelKey = 'session_company_access_level';
const _sessionAssignedPropertiesKey = 'session_assigned_properties';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

class SessionState {
  const SessionState({
    required this.isAuthenticated,
    this.role,
    this.companyAccessLevel,
    this.userId,
    this.userName,
    this.token,
    this.assignedPropertyIds = const <String>[],
  });

  final bool isAuthenticated;
  final UserRole? role;
  final CompanyAccessLevel? companyAccessLevel;
  final String? userId;
  final String? userName;
  final String? token;
  final List<String> assignedPropertyIds;

  factory SessionState.loggedOut() {
    return const SessionState(isAuthenticated: false);
  }

  SessionState copyWith({
    bool? isAuthenticated,
    UserRole? role,
    CompanyAccessLevel? companyAccessLevel,
    String? userId,
    String? userName,
    String? token,
    List<String>? assignedPropertyIds,
    bool clearRole = false,
    bool clearCompanyAccessLevel = false,
    bool clearUserId = false,
    bool clearUserName = false,
    bool clearToken = false,
    bool clearAssignedPropertyIds = false,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: clearRole ? null : (role ?? this.role),
      companyAccessLevel: clearCompanyAccessLevel
          ? null
          : (companyAccessLevel ?? this.companyAccessLevel),
      userId: clearUserId ? null : (userId ?? this.userId),
      userName: clearUserName ? null : (userName ?? this.userName),
      token: clearToken ? null : (token ?? this.token),
      assignedPropertyIds: clearAssignedPropertyIds
          ? const <String>[]
          : (assignedPropertyIds ?? this.assignedPropertyIds),
    );
  }
}

class _ClientAccount {
  const _ClientAccount({
    required this.email,
    required this.username,
    required this.password,
    required this.displayName,
    required this.assignedPropertyIds,
  });

  final String email;
  final String username;
  final String password;
  final String displayName;
  final List<String> assignedPropertyIds;
}

const _fakeClientAccounts = <_ClientAccount>[
  _ClientAccount(
    email: 'client.sunset@example.com',
    username: 'client.sunset',
    password: 'client123',
    displayName: 'Sunset Client',
    assignedPropertyIds: <String>['p1'],
  ),
  _ClientAccount(
    email: 'client.maple@example.com',
    username: 'client.maple',
    password: 'client123',
    displayName: 'Maple Client',
    assignedPropertyIds: <String>['p2'],
  ),
];

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) {
      return SessionState.loggedOut();
    }

    final token = prefs.getString(_sessionTokenKey);
    final userId = prefs.getString(_sessionUserIdKey);
    final userName = prefs.getString(_sessionUserNameKey);
    final roleValue = prefs.getString(_sessionRoleKey);
    final companyAccessValue = prefs.getString(_sessionCompanyAccessLevelKey);
    final assignedPropertyIds =
        prefs.getStringList(_sessionAssignedPropertiesKey) ?? const <String>[];
    final role = _roleFromStored(roleValue);
    final storedCompanyAccessLevel = _companyAccessLevelFromStored(companyAccessValue);
    final companyAccessLevel = role == UserRole.owner
        ? CompanyAccessLevel.owner
        : (storedCompanyAccessLevel ?? CompanyAccessLevel.member);

    if (token == null || userName == null || role == null) {
      return SessionState.loggedOut();
    }

    return SessionState(
      isAuthenticated: true,
      role: role,
      companyAccessLevel: companyAccessLevel,
      userId: userId,
      userName: userName,
      token: token,
      assignedPropertyIds: assignedPropertyIds,
    );
  }

  Future<void> loginCompanyFake({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('Email and password are required.');
    }

    final api = ref.read(serviceProofApiProvider);
    if (api != null) {
      final response = await api.login(email: email, password: password);
      final nextState = SessionState(
        isAuthenticated: true,
        role: _mapApiRole(response.role),
        companyAccessLevel: response.companyAccessLevel,
        userId: response.userId,
        userName: response.name,
        token: response.token,
      );
      state = nextState;
      await _persistSession(nextState);
      await _syncPushToken(nextState);
      return;
    }

    final fallback = SessionState(
      isAuthenticated: true,
      role: UserRole.owner,
      companyAccessLevel: CompanyAccessLevel.owner,
      userName: _displayNameFromEmail(email),
      token: 'fake-company-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    state = fallback;
    await _persistSession(fallback);
  }

  Future<void> signupCompanyFake({
    required String companyName,
    required String email,
    required String password,
  }) async {
    if (companyName.trim().isEmpty) {
      throw Exception('Company name is required.');
    }
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('Email and password are required.');
    }

    final api = ref.read(serviceProofApiProvider);
    if (api != null) {
      final response = await api.signupCompany(
        companyName: companyName.trim(),
        email: email,
        password: password,
      );
      final nextState = SessionState(
        isAuthenticated: true,
        role: _mapApiRole(response.role),
        companyAccessLevel: response.companyAccessLevel,
        userId: response.userId,
        userName: response.name,
        token: response.token,
      );
      state = nextState;
      await _persistSession(nextState);
      await _syncPushToken(nextState);
      return;
    }

    final fallback = SessionState(
      isAuthenticated: true,
      role: UserRole.owner,
      companyAccessLevel: CompanyAccessLevel.owner,
      userName: companyName.trim(),
      token: 'fake-company-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    state = fallback;
    await _persistSession(fallback);
  }

  Future<void> loginClientFake({
    required String email,
    required String password,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    if (api != null) {
      final response = await api.login(email: email, password: password);
      final nextState = SessionState(
        isAuthenticated: true,
        role: _mapApiRole(response.role),
        companyAccessLevel: response.companyAccessLevel,
        userId: response.userId,
        userName: response.name,
        token: response.token,
      );
      state = nextState;
      await _persistSession(nextState);
      await _syncPushToken(nextState);
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final account = _fakeClientAccounts.cast<_ClientAccount?>().firstWhere(
      (item) =>
          item?.email.toLowerCase() == normalizedEmail &&
          item?.password == normalizedPassword,
      orElse: () => null,
    );

    if (account == null) {
      throw Exception('Invalid username or password.');
    }

    final fallback = SessionState(
      isAuthenticated: true,
      role: UserRole.client,
      companyAccessLevel: CompanyAccessLevel.member,
      userName: account.displayName,
      token: 'fake-client-token-${DateTime.now().millisecondsSinceEpoch}',
      assignedPropertyIds: account.assignedPropertyIds,
    );
    state = fallback;
    await _persistSession(fallback);
  }

  Future<void> loginFake({
    required String userName,
    required UserRole role,
  }) async {
    final nextState = SessionState(
      isAuthenticated: true,
      role: role,
      companyAccessLevel: role == UserRole.owner
          ? CompanyAccessLevel.owner
          : CompanyAccessLevel.member,
      userName: userName,
      token: 'fake-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    state = nextState;
    await _persistSession(nextState);
  }

  Future<void> logout() async {
    final token = state.token;
    final api = ref.read(serviceProofApiProvider);
    if (api != null && token != null && token.isNotEmpty) {
      try {
        await PushNotificationsService.instance.unregisterCurrentToken(
          api: api,
          authToken: token,
        );
      } catch (_) {
        // Continue logout even if unregistering push token fails.
      }
      try {
        await api.logout(authToken: token);
      } catch (_) {
        // Continue local logout even if backend logout fails.
      }
    }

    PushNotificationsService.instance.setOnTokenRefresh(null);
    state = SessionState.loggedOut();
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      await prefs.remove(_sessionTokenKey);
      await prefs.remove(_sessionUserIdKey);
      await prefs.remove(_sessionUserNameKey);
      await prefs.remove(_sessionRoleKey);
      await prefs.remove(_sessionCompanyAccessLevelKey);
      await prefs.remove(_sessionAssignedPropertiesKey);
    }
  }

  Future<void> updateDisplayName(String userName) async {
    state = state.copyWith(userName: userName);
    await _persistSession(state);
  }

  Future<void> _persistSession(SessionState session) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      await prefs.setString(_sessionTokenKey, session.token ?? '');
      await prefs.setString(_sessionUserIdKey, session.userId ?? '');
      await prefs.setString(_sessionUserNameKey, session.userName ?? '');
      if (session.role != null) {
        await prefs.setString(_sessionRoleKey, session.role!.name);
      }
      if (session.companyAccessLevel != null) {
        await prefs.setString(
          _sessionCompanyAccessLevelKey,
          session.companyAccessLevel!.name,
        );
      }
      await prefs.setStringList(
        _sessionAssignedPropertiesKey,
        session.assignedPropertyIds,
      );
    }
  }

  Future<void> _syncPushToken(SessionState session) async {
    final token = session.token;
    final api = ref.read(serviceProofApiProvider);
    if (api == null || token == null || token.isEmpty) {
      return;
    }

    try {
      await PushNotificationsService.instance.registerCurrentToken(
        api: api,
        authToken: token,
      );
    } catch (_) {
      // Push registration is best-effort and should not block login.
    }

    PushNotificationsService.instance.setOnTokenRefresh((String refreshedToken) async {
      final currentSession = state;
      final currentApi = ref.read(serviceProofApiProvider);
      final currentAuthToken = currentSession.token;
      if (currentApi == null || currentAuthToken == null || currentAuthToken.isEmpty) {
        return;
      }
      await currentApi.registerPushToken(authToken: currentAuthToken, token: refreshedToken);
    });
  }

  String _displayNameFromEmail(String email) {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      return trimmed;
    }
    return trimmed.split('@').first;
  }

  UserRole? _roleFromStored(String? value) {
    if (value == null) {
      return null;
    }
    for (final role in UserRole.values) {
      if (role.name == value) {
        return role;
      }
    }
    return null;
  }

  UserRole _mapApiRole(ApiUserRole role) {
    return switch (role) {
      ApiUserRole.owner => UserRole.owner,
      ApiUserRole.worker => UserRole.worker,
      ApiUserRole.client => UserRole.client,
    };
  }

  CompanyAccessLevel? _companyAccessLevelFromStored(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final level in CompanyAccessLevel.values) {
      if (level.name == value) {
        return level;
      }
    }
    return null;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
