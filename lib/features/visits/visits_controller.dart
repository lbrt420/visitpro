import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/models/property.dart';
import '../../core/models/visit.dart';
import '../../core/providers/in_memory_store_provider.dart';
import '../../core/providers/session_provider.dart';
import '../properties/properties_controller.dart';

final visitsByPropertyProvider =
    FutureProvider.family<List<Visit>, String>((ref, propertyId) async {
  final api = ref.watch(serviceProofApiProvider);
  final session = ref.watch(sessionProvider);
  final store = ref.watch(inMemoryStoreProvider);

  if (api != null && session.token != null) {
    try {
      return api.getVisitsByProperty(
        authToken: session.token!,
        propertyId: propertyId,
      );
    } catch (_) {
      // Fall back to local data to keep MVP usable offline or before backend is ready.
    }
  }
  return store.fetchVisitsByProperty(propertyId);
});

final visitsByShareTokenProvider =
    FutureProvider.family<List<Visit>, String>((ref, token) async {
  final api = ref.watch(serviceProofApiProvider);
  final store = ref.watch(inMemoryStoreProvider);

  if (api != null) {
    try {
      return api.getShareVisits(shareToken: token);
    } catch (_) {
      // Fall back to local data to keep MVP usable offline or before backend is ready.
    }
  }
  return store.fetchVisitsByShareToken(token);
});

class ClientFeedItem {
  const ClientFeedItem({
    required this.property,
    required this.visit,
  });

  final Property property;
  final Visit visit;
}

class ReactionState {
  const ReactionState({
    required this.counts,
    required this.selectedEmoji,
  });

  final Map<String, int> counts;
  final String? selectedEmoji;
}

class FeedReactionsNotifier extends Notifier<Map<String, ReactionState>> {
  @override
  Map<String, ReactionState> build() {
    return const <String, ReactionState>{};
  }

  static const List<String> availableEmojis = <String>[
    '👍',
    '❤️',
    '🔥',
    '👏',
    '😮',
  ];

  ReactionState stateForVisit(String visitId) {
    return state[visitId] ??
        ReactionState(
          counts: <String, int>{
            for (final emoji in availableEmojis) emoji: 0,
          },
          selectedEmoji: null,
        );
  }

  void toggleReaction({
    required String visitId,
    required String emoji,
  }) {
    final current = stateForVisit(visitId);
    final nextCounts = Map<String, int>.from(current.counts);
    final currentSelection = current.selectedEmoji;

    if (currentSelection == emoji) {
      nextCounts[emoji] = ((nextCounts[emoji] ?? 0) - 1).clamp(0, 99999);
      state = {
        ...state,
        visitId: ReactionState(counts: nextCounts, selectedEmoji: null),
      };
      return;
    }

    if (currentSelection != null) {
      nextCounts[currentSelection] =
          ((nextCounts[currentSelection] ?? 0) - 1).clamp(0, 99999);
    }

    nextCounts[emoji] = (nextCounts[emoji] ?? 0) + 1;
    state = {
      ...state,
      visitId: ReactionState(counts: nextCounts, selectedEmoji: emoji),
    };
  }
}

final feedReactionsProvider =
    NotifierProvider<FeedReactionsNotifier, Map<String, ReactionState>>(
  FeedReactionsNotifier.new,
);

final clientFeedProvider = FutureProvider<List<ClientFeedItem>>((ref) async {
  final properties = await ref.watch(propertiesProvider.future);
  final feed = <ClientFeedItem>[];

  for (final property in properties) {
    final visits = await ref.watch(visitsByPropertyProvider(property.id).future);
    for (final visit in visits) {
      feed.add(ClientFeedItem(property: property, visit: visit));
    }
  }

  feed.sort((a, b) => b.visit.createdAt.compareTo(a.visit.createdAt));
  return feed;
});

class VisitsController {
  VisitsController(this.ref);

  final Ref ref;

  Future<void> submitVisit({
    required String propertyId,
    required String workerName,
    required String note,
    required String serviceType,
    required List<String> serviceChecklist,
    required List<XFile> photos,
    required bool sendEmailUpdate,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    final store = ref.read(inMemoryStoreProvider);
    final mappedPhotos = photos
        .map(
          (file) => Photo(
            url: file.path,
            thumbnailUrl: null,
            createdAt: DateTime.now(),
          ),
        )
        .toList();

    if (api != null && token != null) {
      final uploadedPhotos = await _uploadVisitPhotos(
        api: api,
        authToken: token,
        files: photos,
      );
      await api.createVisit(
        authToken: token,
        propertyId: propertyId,
        workerName: workerName,
        note: note,
        serviceType: serviceType,
        serviceChecklist: serviceChecklist,
        photos: uploadedPhotos,
        sendEmailUpdate: sendEmailUpdate,
      );
      ref.invalidate(visitsByPropertyProvider(propertyId));
      ref.invalidate(clientFeedProvider);
      return;
    }

    await store.addVisit(
      propertyId: propertyId,
      workerName: workerName,
      note: note,
      serviceType: serviceType,
      serviceChecklist: serviceChecklist,
      photos: mappedPhotos,
    );
    ref.invalidate(visitsByPropertyProvider(propertyId));
    ref.invalidate(clientFeedProvider);
  }

  Future<void> toggleVisitReaction({
    required String propertyId,
    required String visitId,
    required String emoji,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    final store = ref.read(inMemoryStoreProvider);
    if (api != null && token != null) {
      await api.reactToVisit(
        authToken: token,
        propertyId: propertyId,
        visitId: visitId,
        emoji: emoji,
      );
    } else {
      await store.toggleVisitReaction(
        propertyId: propertyId,
        visitId: visitId,
        emoji: emoji,
      );
    }
    ref.invalidate(visitsByPropertyProvider(propertyId));
    ref.invalidate(clientFeedProvider);
  }

  Future<List<Photo>> _uploadVisitPhotos({
    required ServiceProofApi api,
    required String authToken,
    required List<XFile> files,
  }) async {
    final now = DateTime.now();
    final uploaded = <Photo>[];

    for (final file in files) {
      final sign = await api.signUpload(
        authToken: authToken,
        fileName: file.name,
        contentType: _contentTypeFromFileName(file.name),
      );
      final uploadUrl = (sign['uploadURL'] as String?) ?? '';
      final publicUrl = (sign['publicUrl'] as String?) ?? '';
      if (uploadUrl.isEmpty || publicUrl.isEmpty) {
        throw Exception('Could not get upload URL for visit photo.');
      }

      final bytes = await file.readAsBytes();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        ),
      });
      await Dio().post(uploadUrl, data: form);

      uploaded.add(
        Photo(
          url: publicUrl,
          thumbnailUrl: null,
          createdAt: now,
        ),
      );
    }

    return uploaded;
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
}

final visitsControllerProvider = Provider<VisitsController>((ref) {
  return VisitsController(ref);
});
