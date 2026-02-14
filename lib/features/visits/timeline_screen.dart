import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/property.dart';
import '../../core/models/visit.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/async_state_view.dart';
import '../properties/properties_controller.dart';
import 'visits_controller.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({
    super.key,
    required this.propertyId,
    this.shareToken,
    this.isClientView = false,
    this.initialVisitId,
  });

  final String propertyId;
  final String? shareToken;
  final bool isClientView;
  final String? initialVisitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final visits = isClientView
        ? ref.watch(visitsByShareTokenProvider(shareToken ?? ''))
        : ref.watch(visitsByPropertyProvider(propertyId));
    final properties = ref.watch(propertiesProvider);
    final currentRole = ref.watch(sessionProvider).role;
    final canCreateVisit = !isClientView && currentRole != UserRole.client;
    final title = _resolveTitle(
      l10n,
      properties.when(
        data: (items) => items,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
    final currentProperty = _resolveProperty(
      properties.when(
        data: (items) => items,
        loading: () => null,
        error: (_, __) => null,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncStateView<List<Visit>>(
        value: visits,
        onRetry: () {
          if (isClientView) {
            ref.invalidate(visitsByShareTokenProvider(shareToken ?? ''));
          } else {
            ref.invalidate(visitsByPropertyProvider(propertyId));
          }
        },
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyTimelineState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        if ((currentProperty?.companyLogoUrl ?? '').startsWith(
                          'http',
                        ))
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                currentProperty!.companyLogoUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.business_outlined,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          l10n.visitsCount(items.length),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final visit = items[index - 1];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_note_outlined, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${visit.workerName} • ${_formatDate(context, visit.createdAt)}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.note,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(visit.note.isEmpty ? l10n.noNoteAdded : visit.note),
                      const SizedBox(height: 12),
                      Text(
                        l10n.visitServiceTypeLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.serviceTypeLabel(visit.serviceType)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.serviceChecklistTitle,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      if (visit.serviceChecklist.isEmpty)
                        Text(l10n.noCompletedServiceChecklistItems)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visit.serviceChecklist
                              .map(
                                (item) => _checkChip(
                                  l10n.serviceChecklistItemLabel(item),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.photos,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      if (visit.photos.isEmpty)
                        Text(l10n.noPhotos)
                      else
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, photoIndex) {
                              final photo = visit.photos[photoIndex];
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _openPhotoPreview(
                                  context: context,
                                  photo: photo,
                                ),
                                child: Container(
                                  width: 92,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: photo.url.startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            photo.thumbnailUrl ?? photo.url,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        )
                                      : const Icon(Icons.photo),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemCount: visit.photos.length,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canCreateVisit
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/properties/$propertyId/new-visit'),
              icon: const Icon(Icons.add_a_photo),
              label: Text(l10n.newVisit),
            )
          : null,
    );
  }

  String _resolveTitle(AppLocalizations l10n, List<Property>? properties) {
    if (isClientView) {
      return l10n.clientTimeline;
    }
    final property = _resolveProperty(properties);
    return property == null
        ? l10n.timeline
        : l10n.propertyTimelineTitle(property.name);
  }

  Property? _resolveProperty(List<Property>? properties) {
    return properties?.cast<Property?>().firstWhere(
      (item) => item?.id == propertyId,
      orElse: () => null,
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final material = MaterialLocalizations.of(context);
    final use24h = MediaQuery.of(context).alwaysUse24HourFormat;
    final datePart = material.formatMediumDate(date);
    final timePart = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: use24h,
    );
    return '$datePart $timePart';
  }

  Widget _checkChip(String label) {
    return Chip(avatar: Icon(Icons.check_circle, size: 16), label: Text(label));
  }

  Future<void> _openPhotoPreview({
    required BuildContext context,
    required Photo photo,
  }) async {
    if (!photo.url.startsWith('http')) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(photo.url, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyTimelineState extends StatelessWidget {
  const _EmptyTimelineState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_toggle_off, size: 48),
            const SizedBox(height: 12),
            Text(
              l10n.noVisitsYet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(l10n.visitsWillAppearHere, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
