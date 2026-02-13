import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/property.dart';
import '../models/service_catalog.dart';
import '../models/visit.dart';
import 'api_client.dart';
import 'endpoints.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_BASE_URL', defaultValue: '');
});

final serviceProofApiProvider = Provider<ServiceProofApi?>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) {
    return null;
  }
  return ServiceProofApi(ApiClient(baseUrl: baseUrl));
});

class ServiceProofApi {
  ServiceProofApi(this._client);

  final ApiClient _client;

  Future<AuthResponse> login({
    String? email,
    String? username,
    required String password,
  }) async {
    final normalizedEmail = email?.trim();
    final normalizedUsername = username?.trim();
    if ((normalizedEmail == null || normalizedEmail.isEmpty) &&
        (normalizedUsername == null || normalizedUsername.isEmpty)) {
      throw Exception('Email or username is required.');
    }

    final response = await _client.post(
      Endpoints.login,
      data: <String, dynamic>{
        if (normalizedEmail != null && normalizedEmail.isNotEmpty)
          'email': normalizedEmail,
        if (normalizedUsername != null && normalizedUsername.isNotEmpty)
          'username': normalizedUsername,
        'password': password,
      },
    );
    return _parseAuthResponse(response.data);
  }

  Future<AuthResponse> signupCompany({
    required String companyName,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Endpoints.signupCompany,
      data: <String, dynamic>{
        'companyName': companyName,
        'email': email,
        'password': password,
      },
    );
    return _parseAuthResponse(response.data);
  }

  Future<void> logout({required String authToken}) async {
    await _client.post(Endpoints.logout, authToken: authToken);
  }

  Future<UserProfile> getMe({required String authToken}) async {
    final response = await _client.get(Endpoints.me, authToken: authToken);
    final map = _asMap(response.data);
    return _parseUserProfile(_asMap(map['user']));
  }

  Future<UserProfile> updateProfile({
    required String authToken,
    String? username,
    String? avatarUrl,
  }) async {
    final response = await _client.patch(
      Endpoints.profile,
      authToken: authToken,
      data: <String, dynamic>{
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );
    final map = _asMap(response.data);
    return _parseUserProfile(_asMap(map['user']));
  }

  Future<void> changePassword({
    required String authToken,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _client.post(
      Endpoints.changePassword,
      authToken: authToken,
      data: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> registerPushToken({
    required String authToken,
    required String token,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }
    await _client.post(
      Endpoints.notificationsToken,
      authToken: authToken,
      data: <String, dynamic>{'token': normalizedToken},
    );
  }

  Future<void> unregisterPushToken({
    required String authToken,
    required String token,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }
    await _client.delete(
      Endpoints.notificationsToken,
      authToken: authToken,
      data: <String, dynamic>{'token': normalizedToken},
    );
  }

  Future<List<Property>> getProperties({required String authToken}) async {
    final response = await _client.get(
      Endpoints.properties,
      authToken: authToken,
    );
    final items = _asList(response.data, fallbackKey: 'properties');
    return items.map(Property.fromJson).toList();
  }

  Future<Property> createProperty({
    required String authToken,
    required String name,
    required String address,
    String? clientEmail,
  }) async {
    final response = await _client.post(
      Endpoints.properties,
      authToken: authToken,
      data: <String, dynamic>{
        'name': name,
        'address': address,
        if (clientEmail != null && clientEmail.trim().isNotEmpty)
          'clientEmail': clientEmail.trim(),
      },
    );
    return Property.fromJson(_asMap(response.data));
  }

  Future<void> inviteWorker({
    required String authToken,
    required String propertyId,
    required String email,
  }) async {
    await _client.post(
      Endpoints.inviteWorker(propertyId),
      authToken: authToken,
      data: <String, dynamic>{'email': email},
    );
  }

  Future<void> inviteClient({
    required String authToken,
    required String propertyId,
    required String email,
  }) async {
    await _client.post(
      Endpoints.inviteClient(propertyId),
      authToken: authToken,
      data: <String, dynamic>{'email': email},
    );
  }

  Future<void> removeClientFromProperty({
    required String authToken,
    required String propertyId,
    required String clientUserId,
  }) async {
    await _client.delete(
      Endpoints.removeClientFromProperty(propertyId, clientUserId),
      authToken: authToken,
    );
  }

  Future<List<Visit>> getVisitsByProperty({
    required String authToken,
    required String propertyId,
  }) async {
    final response = await _client.get(
      Endpoints.visitsByProperty(propertyId),
      authToken: authToken,
    );
    final items = _asList(response.data, fallbackKey: 'visits');
    return items.map(Visit.fromJson).toList();
  }

  Future<void> createVisit({
    required String authToken,
    required String propertyId,
    required String workerName,
    required String note,
    required String serviceType,
    required List<String> serviceChecklist,
    required List<Photo> photos,
    required bool sendEmailUpdate,
  }) async {
    await _client.post(
      Endpoints.visitsByProperty(propertyId),
      authToken: authToken,
      data: <String, dynamic>{
        'workerName': workerName,
        'note': note,
        'serviceType': serviceType,
        'serviceChecklist': serviceChecklist,
        'photos': photos.map((photo) => photo.toJson()).toList(),
        'sendEmailUpdate': sendEmailUpdate,
      },
    );
  }

  Future<Visit> reactToVisit({
    required String authToken,
    required String propertyId,
    required String visitId,
    required String emoji,
  }) async {
    final response = await _client.post(
      Endpoints.visitReactions(propertyId, visitId),
      authToken: authToken,
      data: <String, dynamic>{
        'emoji': emoji,
      },
    );
    return Visit.fromJson(_asMap(response.data));
  }

  Future<Map<String, dynamic>> signUpload({
    required String authToken,
    required String fileName,
    required String contentType,
  }) async {
    final response = await _client.post(
      Endpoints.uploadsSign,
      authToken: authToken,
      data: <String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
      },
    );
    return _asMap(response.data);
  }

  Future<List<Visit>> getShareVisits({required String shareToken}) async {
    final response = await _client.get(Endpoints.shareVisits(shareToken));
    final items = _asList(response.data, fallbackKey: 'visits');
    return items.map(Visit.fromJson).toList();
  }

  Future<CompanyInfo> getCompanyMe({required String authToken}) async {
    final response = await _client.get(Endpoints.companyMe, authToken: authToken);
    final map = _asMap(response.data);
    final companyMap = _asMap(map['company']);
    return CompanyInfo(
      id: (companyMap['id'] as String?)?.trim() ?? '',
      name: (companyMap['name'] as String?)?.trim() ?? '',
      address: (companyMap['address'] as String?)?.trim() ?? '',
      orgNumber: (companyMap['orgNumber'] as String?)?.trim() ?? '',
      taxId: (companyMap['taxId'] as String?)?.trim() ?? '',
      logoUrl: (companyMap['logoUrl'] as String?)?.trim() ?? '',
      billingPlan: (companyMap['billingPlan'] as String?)?.trim() ?? '',
      billingCycle: (companyMap['billingCycle'] as String?)?.trim() ?? 'yearly',
      subscriptionStatus: (companyMap['subscriptionStatus'] as String?)?.trim() ?? 'inactive',
      propertiesLimit: companyMap['propertiesLimit'] is num
          ? (companyMap['propertiesLimit'] as num).toInt()
          : null,
      propertiesUsed: (companyMap['propertiesUsed'] as num?)?.toInt() ?? 0,
      propertiesRemaining: companyMap['propertiesRemaining'] is num
          ? (companyMap['propertiesRemaining'] as num).toInt()
          : null,
      canCreateProperty: (companyMap['canCreateProperty'] as bool?) ?? true,
      servicesOffered: ((companyMap['servicesOffered'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => '$item')
              .where((item) => serviceTypeIds.contains(item)))
          .toList(),
    );
  }

  Future<void> updateCompany({
    required String authToken,
    String? name,
    String? address,
    String? orgNumber,
    String? taxId,
    String? logoUrl,
    List<String>? servicesOffered,
  }) async {
    if (name == null &&
        address == null &&
        orgNumber == null &&
        taxId == null &&
        logoUrl == null &&
        servicesOffered == null) {
      return;
    }
    await _client.patch(
      Endpoints.company,
      authToken: authToken,
      data: <String, dynamic>{
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (orgNumber != null) 'orgNumber': orgNumber,
        if (taxId != null) 'taxId': taxId,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (servicesOffered != null) 'servicesOffered': servicesOffered,
      },
    );
  }

  Future<List<CompanyTeamMember>> getCompanyTeam({required String authToken}) async {
    final response = await _client.get(Endpoints.companyTeam, authToken: authToken);
    final items = _asList(response.data, fallbackKey: 'members');
    return items
        .map(
          (item) => CompanyTeamMember(
            id: (item['id'] as String?)?.trim() ?? '',
            name: (item['name'] as String?)?.trim() ?? '',
            email: (item['email'] as String?)?.trim() ?? '',
            role: (item['role'] as String?)?.trim() ?? '',
            companyAccessLevel: _companyAccessLevelFromRaw(
              (item['companyAccessLevel'] as String?)?.trim() ?? '',
            ),
          ),
        )
        .toList();
  }

  Future<void> updateCompanyTeamAccessLevel({
    required String authToken,
    required String userId,
    required CompanyAccessLevel accessLevel,
  }) async {
    await _client.patch(
      Endpoints.companyTeamAccessLevel(userId),
      authToken: authToken,
      data: <String, dynamic>{'accessLevel': accessLevel.name},
    );
  }

  Future<BillingStartTrialResult> startOnboardingTrial({
    required String authToken,
    required String plan,
    required String clientRange,
    required String billingCycle,
    required String returnUrl,
  }) async {
    final response = await _client.post(
      Endpoints.companyBillingStartTrial,
      authToken: authToken,
      data: <String, dynamic>{
        'plan': plan,
        'clientRange': clientRange,
        'billingCycle': billingCycle,
        'returnUrl': returnUrl,
      },
    );
    final map = _asMap(response.data);
    return BillingStartTrialResult(
      status: (map['status'] as String?) ?? 'active',
      checkoutUrl: (map['checkoutUrl'] as String?) ?? '',
      sessionId: (map['sessionId'] as String?) ?? '',
    );
  }

  Future<BillingConfirmCheckoutResult> confirmOnboardingCheckout({
    required String authToken,
    required String sessionId,
  }) async {
    final response = await _client.post(
      Endpoints.companyBillingConfirmCheckout,
      authToken: authToken,
      data: <String, dynamic>{'sessionId': sessionId},
    );
    final map = _asMap(response.data);
    return BillingConfirmCheckoutResult(
      status: (map['status'] as String?) ?? 'active',
      billingPlan: (map['billingPlan'] as String?) ?? '',
      billingCycle: (map['billingCycle'] as String?) ?? 'yearly',
    );
  }

  Future<String> createBillingPortalSession({
    required String authToken,
    required String returnUrl,
  }) async {
    final response = await _client.post(
      Endpoints.companyBillingPortalSession,
      authToken: authToken,
      data: <String, dynamic>{'returnUrl': returnUrl},
    );
    final map = _asMap(response.data);
    return (map['url'] as String?)?.trim() ?? '';
  }

  Future<void> removeCompanyTeamMember({
    required String authToken,
    required String userId,
  }) async {
    await _client.delete(
      Endpoints.companyTeamMember(userId),
      authToken: authToken,
    );
  }

  Future<void> inviteCompanyWorker({
    required String authToken,
    required String email,
    String? name,
  }) async {
    try {
      await _client.post(
        Endpoints.companyTeamInviteWorker,
        authToken: authToken,
        data: <String, dynamic>{
          'email': email,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
    } catch (error) {
      throw Exception(_apiErrorMessage(error));
    }
  }

  List<Map<String, dynamic>> _asList(
    dynamic data, {
    required String fallbackKey,
  }) {
    if (data is List) {
      return data
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList();
    }
    if (data is Map) {
      final value = data['data'] ?? data[fallbackKey];
      if (value is List) {
        return value
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => item.map((key, value) => MapEntry('$key', value)))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map<dynamic, dynamic>) {
      return data.map((key, value) => MapEntry('$key', value));
    }
    throw Exception('Invalid server response.');
  }

  String _apiErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = (data['error'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      } else if (data is Map<dynamic, dynamic>) {
        final normalized = data.map((key, value) => MapEntry('$key', value));
        final message = (normalized['error'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }
    final fallback = error.toString().replaceAll('Exception: ', '').trim();
    return fallback.isEmpty ? 'Something went wrong.' : fallback;
  }

  AuthResponse _parseAuthResponse(dynamic data) {
    final map = _asMap(data);
    final token = map['token'] as String? ?? map['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Login response missing token.');
    }

    final userMap = _asMap(map['user']);
    final roleRaw = (userMap['role'] as String? ?? '').trim().toLowerCase();
    final role = switch (roleRaw) {
      'owner' => ApiUserRole.owner,
      'worker' => ApiUserRole.worker,
      'client' => ApiUserRole.client,
      _ => ApiUserRole.worker,
    };

    return AuthResponse(
      userId: (userMap['id'] as String?)?.trim() ?? '',
      token: token,
      role: role,
      name: (userMap['name'] as String?)?.trim().isNotEmpty == true
          ? (userMap['name'] as String).trim()
          : ((userMap['email'] as String?)?.trim() ?? 'User'),
      companyAccessLevel: _companyAccessLevelFromRaw(
        (userMap['companyAccessLevel'] as String?)?.trim() ?? '',
      ),
    );
  }

  UserProfile _parseUserProfile(Map<String, dynamic> userMap) {
    final roleRaw = (userMap['role'] as String? ?? '').trim().toLowerCase();
    final role = switch (roleRaw) {
      'owner' => ApiUserRole.owner,
      'worker' => ApiUserRole.worker,
      'client' => ApiUserRole.client,
      _ => ApiUserRole.worker,
    };
    return UserProfile(
      id: (userMap['id'] as String?)?.trim() ?? '',
      role: role,
      name: (userMap['name'] as String?)?.trim() ?? '',
      email: (userMap['email'] as String?)?.trim() ?? '',
      username: (userMap['username'] as String?)?.trim() ?? '',
      avatarUrl: (userMap['avatarUrl'] as String?)?.trim() ?? '',
    );
  }

  CompanyAccessLevel _companyAccessLevelFromRaw(String raw) {
    final normalized = raw.toLowerCase();
    return switch (normalized) {
      'owner' => CompanyAccessLevel.owner,
      'admin' => CompanyAccessLevel.admin,
      _ => CompanyAccessLevel.member,
    };
  }
}

enum ApiUserRole { owner, worker, client }

enum CompanyAccessLevel { owner, admin, member }

class AuthResponse {
  const AuthResponse({
    required this.userId,
    required this.token,
    required this.role,
    required this.name,
    required this.companyAccessLevel,
  });

  final String userId;
  final String token;
  final ApiUserRole role;
  final String name;
  final CompanyAccessLevel companyAccessLevel;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.username,
    required this.avatarUrl,
  });

  final String id;
  final ApiUserRole role;
  final String name;
  final String email;
  final String username;
  final String avatarUrl;
}

class CompanyInfo {
  const CompanyInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.orgNumber,
    required this.taxId,
    required this.logoUrl,
    required this.billingPlan,
    required this.billingCycle,
    required this.subscriptionStatus,
    required this.propertiesLimit,
    required this.propertiesUsed,
    required this.propertiesRemaining,
    required this.canCreateProperty,
    required this.servicesOffered,
  });

  final String id;
  final String name;
  final String address;
  final String orgNumber;
  final String taxId;
  final String logoUrl;
  final String billingPlan;
  final String billingCycle;
  final String subscriptionStatus;
  final int? propertiesLimit;
  final int propertiesUsed;
  final int? propertiesRemaining;
  final bool canCreateProperty;
  final List<String> servicesOffered;
}

class BillingStartTrialResult {
  const BillingStartTrialResult({
    required this.status,
    required this.checkoutUrl,
    required this.sessionId,
  });

  final String status;
  final String checkoutUrl;
  final String sessionId;
}

class BillingConfirmCheckoutResult {
  const BillingConfirmCheckoutResult({
    required this.status,
    required this.billingPlan,
    required this.billingCycle,
  });

  final String status;
  final String billingPlan;
  final String billingCycle;
}

class CompanyTeamMember {
  const CompanyTeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.companyAccessLevel,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final CompanyAccessLevel companyAccessLevel;
}
