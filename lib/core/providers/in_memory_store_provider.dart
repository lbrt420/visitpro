import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/property.dart';
import '../models/service_catalog.dart';
import '../models/visit.dart';

class InMemoryStore {
  InMemoryStore()
      : _properties = [
          const Property(
            id: 'p1',
            name: 'Sunset Villa',
            address: '12 Ocean View Rd',
            clientShareToken: 'sunset-villa-token',
            companyLogoUrl: '',
            assignedClientAccounts: <AssignedClientAccount>[
              AssignedClientAccount(
                id: 'c1',
                name: 'Sunset Client',
                email: 'client.sunset@example.com',
                username: 'Sunset',
                avatarUrl: null,
              ),
            ],
          ),
          const Property(
            id: 'p2',
            name: 'Maple Residence',
            address: '88 Maple St',
            clientShareToken: 'maple-residence-token',
            companyLogoUrl: '',
            assignedClientAccounts: <AssignedClientAccount>[
              AssignedClientAccount(
                id: 'c2',
                name: 'Maple Client',
                email: 'client.maple@example.com',
                username: 'Maple',
                avatarUrl: null,
              ),
            ],
          ),
        ],
        _visitsByPropertyId = {
          'p1': [
            Visit(
              id: 'v1',
              propertyId: 'p1',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
              createdByUserId: 'w1',
              workerName: 'Alex',
              workerAvatarUrl: null,
              note: 'Pool and patio cleaned. Water level adjusted.',
              serviceType: 'pool_cleaning',
              serviceChecklist: const <String>[
                'pool_filter_cleaned',
                'pool_chemicals_added',
                'pool_vacuumed',
                'pool_water_level_checked',
              ],
              photos: [
                Photo(
                  url: 'https://picsum.photos/seed/pool-1/800/600',
                  thumbnailUrl: 'https://picsum.photos/seed/pool-1/200/150',
                  createdAt: DateTime.now()
                      .subtract(const Duration(days: 1, hours: 1)),
                ),
              ],
            ),
          ],
          'p2': [],
        };

  final List<Property> _properties;
  final Map<String, List<Visit>> _visitsByPropertyId;

  Future<List<Property>> fetchProperties() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return List<Property>.from(_properties);
  }

  Future<Property> createProperty({
    required String name,
    required String address,
    String? clientEmail,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final id = 'p${DateTime.now().millisecondsSinceEpoch}';
    final initialAssigned = (clientEmail != null && clientEmail.trim().isNotEmpty)
        ? <AssignedClientAccount>[
            AssignedClientAccount(
              id: 'c${DateTime.now().millisecondsSinceEpoch}',
              name: clientEmail.split('@').first,
              email: clientEmail,
              username: clientEmail.split('@').first,
              avatarUrl: null,
            ),
          ]
        : const <AssignedClientAccount>[];
    final property = Property(
      id: id,
      name: name,
      address: address,
      clientShareToken: 'share-$id',
      companyLogoUrl: '',
      assignedClientAccounts: initialAssigned,
    );
    _properties.insert(
      0,
      property,
    );
    _visitsByPropertyId[id] = [];
    return property;
  }

  Future<void> inviteWorker({
    required String propertyId,
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> inviteClient({
    required String propertyId,
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final propertyIndex = _properties.indexWhere((item) => item.id == propertyId);
    if (propertyIndex < 0) {
      return;
    }
    final target = _properties[propertyIndex];
    final exists = target.assignedClientAccounts.any(
      (item) => item.email.toLowerCase() == email.toLowerCase(),
    );
    if (exists) {
      return;
    }
    final nextAssigned = <AssignedClientAccount>[
      ...target.assignedClientAccounts,
      AssignedClientAccount(
        id: 'c${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email,
        username: email.split('@').first,
        avatarUrl: null,
      ),
    ];
    _properties[propertyIndex] = Property(
      id: target.id,
      name: target.name,
      address: target.address,
      clientShareToken: target.clientShareToken,
      companyLogoUrl: target.companyLogoUrl,
      assignedClientAccounts: nextAssigned,
    );
  }

  Future<void> removeClientFromProperty({
    required String propertyId,
    required String clientUserId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final propertyIndex = _properties.indexWhere((item) => item.id == propertyId);
    if (propertyIndex < 0) {
      return;
    }
    final target = _properties[propertyIndex];
    final nextAssigned = target.assignedClientAccounts
        .where((item) => item.id != clientUserId)
        .toList();
    _properties[propertyIndex] = Property(
      id: target.id,
      name: target.name,
      address: target.address,
      clientShareToken: target.clientShareToken,
      companyLogoUrl: target.companyLogoUrl,
      assignedClientAccounts: nextAssigned,
    );
  }

  Future<List<Visit>> fetchVisitsByProperty(String propertyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return List<Visit>.from(_visitsByPropertyId[propertyId] ?? []);
  }

  Future<List<Visit>> fetchVisitsByShareToken(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final property = _properties.cast<Property?>().firstWhere(
          (item) => item?.clientShareToken == token,
          orElse: () => null,
        );
    if (property == null) {
      throw Exception('Invalid share link.');
    }
    return fetchVisitsByProperty(property.id);
  }

  Future<void> addVisit({
    required String propertyId,
    required String workerName,
    required String note,
    required String serviceType,
    required List<String> serviceChecklist,
    required List<Photo> photos,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final nextVisit = Visit(
      id: 'v${DateTime.now().millisecondsSinceEpoch}',
      propertyId: propertyId,
      createdAt: DateTime.now(),
      createdByUserId: 'local-user',
      workerName: workerName,
      workerAvatarUrl: null,
      note: note,
      serviceType: serviceTypeIds.contains(serviceType) ? serviceType : 'other',
      serviceChecklist: serviceChecklist,
      photos: photos,
    );
    final visits = _visitsByPropertyId[propertyId] ?? [];
    _visitsByPropertyId[propertyId] = [nextVisit, ...visits];
  }

  Future<void> toggleVisitReaction({
    required String propertyId,
    required String visitId,
    required String emoji,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final visits = _visitsByPropertyId[propertyId];
    if (visits == null) {
      return;
    }
    final index = visits.indexWhere((item) => item.id == visitId);
    if (index < 0) {
      return;
    }
    final target = visits[index];
    final current = target.userReaction;
    final nextCounts = Map<String, int>.from(target.reactionCounts);
    String? nextUserReaction;

    if (current == emoji) {
      nextCounts[emoji] = ((nextCounts[emoji] ?? 0) - 1).clamp(0, 99999);
      if (nextCounts[emoji] == 0) {
        nextCounts.remove(emoji);
      }
      nextUserReaction = null;
    } else {
      if (current != null && current.isNotEmpty) {
        nextCounts[current] = ((nextCounts[current] ?? 0) - 1).clamp(0, 99999);
        if (nextCounts[current] == 0) {
          nextCounts.remove(current);
        }
      }
      nextCounts[emoji] = (nextCounts[emoji] ?? 0) + 1;
      nextUserReaction = emoji;
    }

    visits[index] = Visit(
      id: target.id,
      propertyId: target.propertyId,
      createdAt: target.createdAt,
      createdByUserId: target.createdByUserId,
      workerName: target.workerName,
      workerAvatarUrl: target.workerAvatarUrl,
      note: target.note,
      serviceType: target.serviceType,
      serviceChecklist: target.serviceChecklist,
      reactionCounts: nextCounts,
      userReaction: nextUserReaction,
      photos: target.photos,
    );
  }
}

final inMemoryStoreProvider = Provider<InMemoryStore>((ref) {
  return InMemoryStore();
});
