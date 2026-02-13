import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/property.dart';
import '../../core/models/visit.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/app_brand_header.dart';
import '../../core/ui/widgets/async_state_view.dart';
import '../company/company_screen.dart';
import '../visits/client_feed_screen.dart';
import '../visits/visits_controller.dart';
import 'properties_controller.dart';

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.role == UserRole.client) {
      return const ClientFeedScreen();
    }

    final properties = ref.watch(propertiesProvider);
    final companyInfo = ref.watch(companyInfoProvider).value;
    final isOwner = session.role == UserRole.owner;
    final canCreateProperty = isOwner && (companyInfo?.canCreateProperty ?? true);
    final remaining = companyInfo?.propertiesRemaining;
    final showNearLimitBanner = isOwner && remaining != null && remaining > 0 && remaining <= 2;

    return Scaffold(
      body: AsyncStateView<List<Property>>(
          value: properties,
          onRetry: () => ref.invalidate(propertiesProvider),
          data: (items) {
            if (items.isEmpty) {
              return Column(
                children: [
                  _PropertiesPageHeader(
                    isOwner: isOwner,
                    canCreateProperty: canCreateProperty,
                    showNearLimitBanner: showNearLimitBanner,
                    propertiesRemaining: remaining,
                    propertiesCount: items.length,
                    onCreateProperty: () => context.go('/properties/new'),
                    onOpenSubscription: () => context.go('/company?tab=3'),
                  ),
                  Expanded(
                    child: _EmptyPropertiesState(
                      isOwner: isOwner,
                      onCreateProperty: () => context.go('/properties/new'),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PropertiesPageHeader(
                    isOwner: isOwner,
                    canCreateProperty: canCreateProperty,
                    showNearLimitBanner: showNearLimitBanner,
                    propertiesRemaining: remaining,
                    propertiesCount: items.length,
                    onCreateProperty: () => context.go('/properties/new'),
                    onOpenSubscription: () => context.go('/company?tab=3'),
                    inPaddedList: true,
                  );
                }
                final item = items[index - 1];
                return _PropertyListItem(
                  item: item,
                  isOwner: isOwner,
                  onNewVisit: () => context.go('/properties/${item.id}/new-visit'),
                  onViewTimeline: () => context.go('/properties/${item.id}/timeline'),
                  onInviteClient: () => _showInviteClientDialog(
                    context: context,
                    ref: ref,
                    propertyId: item.id,
                  ),
                );
              },
            );
          },
        ),
    );
  }

  Future<void> _showInviteClientDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String propertyId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? inlineError;
    bool submitting = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.inviteClient),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.emailLabel),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return l10n.emailRequiredError;
                        }
                        return null;
                      },
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          inlineError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            inlineError = null;
                          });
                          try {
                            await ref.read(propertiesControllerProvider).inviteClient(
                                  propertyId: propertyId,
                                  email: emailController.text.trim(),
                                );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop(true);
                          } catch (error) {
                            final message = error.toString().replaceFirst('Exception: ', '').trim();
                            setDialogState(() {
                              submitting = false;
                              inlineError =
                                  message.isEmpty ? l10n.somethingWentWrong : message;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.sendInvite),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.clientInviteSent),
      ),
    );
  }

}

class _PropertyListItem extends StatefulWidget {
  const _PropertyListItem({
    required this.item,
    required this.isOwner,
    required this.onNewVisit,
    required this.onViewTimeline,
    required this.onInviteClient,
  });

  final Property item;
  final bool isOwner;
  final VoidCallback onNewVisit;
  final VoidCallback onViewTimeline;
  final VoidCallback onInviteClient;

  @override
  State<_PropertyListItem> createState() => _PropertyListItemState();
}

class _PropertyListItemState extends State<_PropertyListItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.address,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: widget.onNewVisit,
                  child: Text(l10n.newVisit),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: widget.onViewTimeline,
                  child: Text(l10n.viewTimeline),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? l10n.showLess : l10n.showMore),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              _LatestVisitsPreview(propertyId: item.id),
              const SizedBox(height: 8),
              Text(
                l10n.assignedAccountsTitle,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              if (item.assignedClientAccounts.isEmpty)
                Text(
                  l10n.noOtherAssignedAccounts,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Column(
                  children: item.assignedClientAccounts
                      .map(
                        (account) {
                          final avatarUrl = account.avatarUrl ?? '';
                          final hasAvatar = avatarUrl.startsWith('http');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                                  child: hasAvatar
                                      ? null
                                      : Text(
                                          _nameFallback(account),
                                          style: Theme.of(context).textTheme.labelSmall,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _displayClientName(account),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                      .toList(),
                ),
              if (widget.isOwner) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.manageAccess,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: widget.onInviteClient,
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.inviteClient),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertiesPageHeader extends StatelessWidget {
  const _PropertiesPageHeader({
    required this.isOwner,
    required this.canCreateProperty,
    required this.showNearLimitBanner,
    required this.propertiesRemaining,
    required this.propertiesCount,
    required this.onCreateProperty,
    required this.onOpenSubscription,
    this.inPaddedList = false,
  });

  final bool isOwner;
  final bool canCreateProperty;
  final bool showNearLimitBanner;
  final int? propertiesRemaining;
  final int propertiesCount;
  final VoidCallback onCreateProperty;
  final VoidCallback onOpenSubscription;
  final bool inPaddedList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = inPaddedList ? 4.0 : 16.0;
    return Column(
      children: [
        AppBrandHeader(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 10),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.properties} ($propertiesCount)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: canCreateProperty ? onCreateProperty : null,
                  icon: const Icon(Icons.add_business),
                  label: Text(l10n.createProperty),
                ),
            ],
          ),
        ),
        if (showNearLimitBanner && propertiesRemaining != null)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.propertiesLimitAlmostReached(propertiesRemaining!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: onOpenSubscription,
                    child: Text(l10n.upgradeNow),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
String _fallbackDisplayNameFromEmail(String email) {
  final local = email.trim().split('@').first;
  if (local.isEmpty) {
    return 'Client';
  }
  return local[0].toUpperCase() + local.substring(1);
}

String _displayClientName(AssignedClientAccount account) {
  final username = (account.username ?? '').trim();
  if (username.isNotEmpty) {
    return username;
  }
  final name = account.name.trim();
  if (name.isNotEmpty) {
    return name;
  }
  return _fallbackDisplayNameFromEmail(account.email);
}

String _nameFallback(AssignedClientAccount account) {
  final source = _displayClientName(account);
  return source.substring(0, 1).toUpperCase();
}

class _LatestVisitsPreview extends ConsumerWidget {
  const _LatestVisitsPreview({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final visitsValue = ref.watch(visitsByPropertyProvider(propertyId));
    return visitsValue.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final sorted = <Visit>[...items]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latest = sorted.take(1).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lastVisit,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (latest.isEmpty)
              Text(
                l10n.noVisitsYet,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...latest.map(
                (visit) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_formatVisitDate(context, visit.createdAt)} • ${visit.workerName}: ${visit.note.isEmpty ? l10n.noNoteAdded : visit.note}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatVisitDate(BuildContext context, DateTime date) {
    final material = MaterialLocalizations.of(context);
    final use24h = MediaQuery.of(context).alwaysUse24HourFormat;
    final datePart = material.formatShortDate(date);
    final timePart = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: use24h,
    );
    return '$datePart $timePart';
  }
}

class _EmptyPropertiesState extends StatelessWidget {
  const _EmptyPropertiesState({
    required this.isOwner,
    required this.onCreateProperty,
  });

  final bool isOwner;
  final VoidCallback onCreateProperty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_work_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              l10n.noPropertiesYet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isOwner
                  ? l10n.ownerEmptyPropertiesHelp
                  : l10n.workerEmptyPropertiesHelp,
              textAlign: TextAlign.center,
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateProperty,
                icon: const Icon(Icons.add_business),
                label: Text(l10n.createProperty),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

