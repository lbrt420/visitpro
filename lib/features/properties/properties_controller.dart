import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/models/property.dart';
import '../../core/providers/in_memory_store_provider.dart';
import '../../core/providers/session_provider.dart';

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final api = ref.watch(serviceProofApiProvider);
  final session = ref.watch(sessionProvider);
  final store = ref.watch(inMemoryStoreProvider);

  if (api != null && session.token != null) {
    try {
      final items = await api.getProperties(authToken: session.token!);
      return _filterPropertiesForSession(items, session);
    } catch (_) {
      // Fall back to local data to keep MVP usable offline or before backend is ready.
    }
  }
  final items = await store.fetchProperties();
  return _filterPropertiesForSession(items, session);
});

class PropertiesController {
  PropertiesController(this.ref);

  final Ref ref;

  bool _shouldFallbackToLocal(Object error) {
    if (error is DioException) {
      if (error.response != null) {
        // Backend responded: preserve server-side business rules.
        return false;
      }
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.unknown;
    }
    return true;
  }

  Exception _asUserFacingException(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final apiError = (responseData['error'] as String?)?.trim();
        if (apiError != null && apiError.isNotEmpty) {
          return Exception(apiError);
        }
      }
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return Exception(message.isEmpty ? 'Something went wrong.' : message);
  }

  Future<Property> createProperty({
    required String name,
    required String address,
    String? clientEmail,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    final store = ref.read(inMemoryStoreProvider);

    if (api != null && token != null) {
      try {
        final created = await api.createProperty(
          authToken: token,
          name: name,
          address: address,
          clientEmail: clientEmail,
        );
        ref.invalidate(propertiesProvider);
        return created;
      } catch (error) {
        if (!_shouldFallbackToLocal(error)) {
          throw _asUserFacingException(error);
        }
        // Fall back to local writes when API is unavailable.
      }
    }

    final created = await store.createProperty(
      name: name,
      address: address,
      clientEmail: clientEmail,
    );
    ref.invalidate(propertiesProvider);
    return created;
  }

  Future<void> inviteWorker({
    required String propertyId,
    required String email,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    final store = ref.read(inMemoryStoreProvider);

    if (api != null && token != null) {
      try {
        await api.inviteWorker(
          authToken: token,
          propertyId: propertyId,
          email: email,
        );
        return;
      } catch (_) {
        // Fall back to local writes when API is unavailable.
      }
    }

    await store.inviteWorker(propertyId: propertyId, email: email);
  }

  Future<void> inviteClient({
    required String propertyId,
    required String email,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    final store = ref.read(inMemoryStoreProvider);

    if (api != null && token != null) {
      try {
        await api.inviteClient(
          authToken: token,
          propertyId: propertyId,
          email: email,
        );
        return;
      } catch (error) {
        if (!_shouldFallbackToLocal(error)) {
          throw _asUserFacingException(error);
        }
        // Fall back to local writes when API is unavailable.
      }
    }

    await store.inviteClient(propertyId: propertyId, email: email);
  }

  Future<void> removeClientFromProperty({
    required String propertyId,
    required String clientUserId,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    final store = ref.read(inMemoryStoreProvider);

    if (api != null && token != null) {
      try {
        await api.removeClientFromProperty(
          authToken: token,
          propertyId: propertyId,
          clientUserId: clientUserId,
        );
        ref.invalidate(propertiesProvider);
        return;
      } catch (_) {
        // Fall back to local writes when API is unavailable.
      }
    }

    await store.removeClientFromProperty(
      propertyId: propertyId,
      clientUserId: clientUserId,
    );
    ref.invalidate(propertiesProvider);
  }
}

final propertiesControllerProvider = Provider<PropertiesController>((ref) {
  return PropertiesController(ref);
});

List<Property> _filterPropertiesForSession(
  List<Property> items,
  SessionState session,
) {
  if (session.role != UserRole.client) {
    return items;
  }
  if (session.assignedPropertyIds.isEmpty) {
    return items;
  }
  return items
      .where((item) => session.assignedPropertyIds.contains(item.id))
      .toList();
}
