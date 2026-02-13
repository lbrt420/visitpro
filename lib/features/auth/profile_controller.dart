import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/session_provider.dart';

final myProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final api = ref.watch(serviceProofApiProvider);
  final token = ref.watch(sessionProvider).token;
  if (api == null || token == null || token.isEmpty) {
    return null;
  }
  return api.getMe(authToken: token);
});

class ProfileController {
  ProfileController(this.ref);

  final Ref ref;

  Future<UserProfile> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception(_l10n().apiNotConfigured);
    }
    UserProfile profile;
    try {
      profile = await api.updateProfile(
        authToken: token,
        username: username,
        avatarUrl: avatarUrl,
      );
    } catch (error) {
      throw Exception(_friendlyErrorMessage(error));
    }
    await ref.read(sessionProvider.notifier).updateDisplayName(
          profile.username.isEmpty ? profile.name : profile.username,
        );
    ref.invalidate(myProfileProvider);
    return profile;
  }

  Future<UserProfile> uploadAvatar({
    required XFile file,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception(_l10n().apiNotConfigured);
    }

    Map<String, dynamic> signResult;
    try {
      signResult = await api.signUpload(
        authToken: token,
        fileName: file.name,
        contentType: _contentTypeFromFileName(file.name),
      );
    } catch (error) {
      throw Exception(_friendlyErrorMessage(error));
    }
    final uploadURL = (signResult['uploadURL'] as String?) ?? '';
    if (uploadURL.isEmpty) {
      throw Exception(_l10n().uploadUrlMissing);
    }

    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
      ),
    });
    try {
      await Dio().post(uploadURL, data: form);
    } catch (error) {
      throw Exception(_friendlyErrorMessage(error));
    }

    final publicUrl = (signResult['publicUrl'] as String?) ?? '';
    if (publicUrl.isEmpty) {
      throw Exception(_l10n().uploadPublicUrlUnavailable);
    }

    return updateProfile(avatarUrl: publicUrl);
  }

  String _contentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  String _friendlyErrorMessage(Object error) {
    final l10n = _l10n();
    if (error is DioException) {
      final data = error.response?.data;
      final statusCode = error.response?.statusCode;
      if (data is Map<String, dynamic>) {
        final apiError = data['error'] as String?;
        final cloudflareStatus = data['cloudflareStatus']?.toString();
        if (apiError != null && apiError.trim().isNotEmpty) {
          final mapped = _mapBackendErrorMessage(
            apiError,
            l10n,
            statusCode: statusCode,
          );
          if (mapped != null) {
            if (cloudflareStatus != null && mapped != l10n.uploadNotConfigured) {
              return '$mapped (Cloudflare status: $cloudflareStatus)';
            }
            return mapped;
          }
          if (cloudflareStatus != null) {
            return '$apiError (Cloudflare status: $cloudflareStatus)';
          }
          return apiError;
        }
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return l10n.networkFailureRetry;
      }
      if (statusCode == 401) {
        return l10n.sessionExpiredSignInAgain;
      }
      return l10n.somethingWentWrong;
    }
    final message = error.toString().replaceAll('Exception: ', '').trim();
    if (message.isEmpty) {
      return l10n.somethingWentWrong;
    }
    final mapped = _mapBackendErrorMessage(message, l10n);
    return mapped ?? message;
  }

  AppLocalizations _l10n() {
    final localeOverride = ref.read(localeOverrideProvider);
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final locale = localeOverride ?? _supportedLocaleFor(platformLocale);
    return AppLocalizations(locale);
  }

  Locale _supportedLocaleFor(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'es') {
      return const Locale('es');
    }
    return const Locale('en');
  }

  String? _mapBackendErrorMessage(
    String apiError,
    AppLocalizations l10n, {
    int? statusCode,
  }) {
    final normalized = apiError.trim().toLowerCase();

    if (normalized.contains('old password is incorrect')) {
      return l10n.oldPasswordIncorrect;
    }
    if (normalized.contains('username already exists')) {
      return l10n.usernameAlreadyExists;
    }
    if (normalized.contains('username cannot be empty')) {
      return l10n.firstNameRequired;
    }
    if (normalized.contains('oldpassword and newpassword are required') ||
        normalized.contains('email or username and password are required')) {
      return l10n.errorRequiredFields;
    }
    if (normalized.contains('new password must be at least 8 characters')) {
      return l10n.newPasswordMinLength;
    }
    if (normalized.contains('cloudflare images is not configured')) {
      return l10n.uploadNotConfigured;
    }
    if (normalized.contains('user not found')) {
      return l10n.userNotFound;
    }
    if (normalized.contains('unauthorized') || statusCode == 401) {
      return l10n.sessionExpiredSignInAgain;
    }

    return null;
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception(_l10n().apiNotConfigured);
    }
    try {
      await api.changePassword(
        authToken: token,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } catch (error) {
      throw Exception(_friendlyErrorMessage(error));
    }
  }
}

final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref);
});
