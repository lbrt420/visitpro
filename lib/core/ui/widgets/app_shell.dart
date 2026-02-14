import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_localizations.dart';
import '../../providers/session_provider.dart';
import '../../../features/properties/properties_controller.dart';
import '../../../features/visits/visits_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final isClient = session.role == UserRole.client;
    final clientFeed = isClient
        ? ref.watch(clientFeedProvider)
        : const AsyncValue<List<ClientFeedItem>>.data(<ClientFeedItem>[]);
    final readVisitIds = ref.watch(clientNotificationsReadProvider);
    final notificationItems = clientFeed.asData?.value ?? const <ClientFeedItem>[];
    final unreadNotifications = notificationItems
        .where((item) => !readVisitIds.contains(item.visit.id))
        .length;
    final currentPath = GoRouterState.of(context).uri.path;
    final tabs = isClient
        ? const <_ShellTabItem>[
            _ShellTabItem(
              route: '/home',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
            ),
            _ShellTabItem(
              route: '/properties',
              icon: Icons.home_work_outlined,
              selectedIcon: Icons.home_work,
            ),
            _ShellTabItem(
              route: '/profile',
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
            ),
          ]
        : const <_ShellTabItem>[
            _ShellTabItem(
              route: '/home',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
            ),
            _ShellTabItem(
              route: '/properties',
              icon: Icons.home_work_outlined,
              selectedIcon: Icons.home_work,
            ),
            _ShellTabItem(
              route: '/company',
              icon: Icons.apartment_outlined,
              selectedIcon: Icons.apartment,
            ),
            _ShellTabItem(
              route: '/account',
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
            ),
          ];
    final selectedIndex = tabs.indexWhere(
      (tab) => _matchesTabRoute(currentPath: currentPath, tabRoute: tab.route),
    );
    final effectiveSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    const tabSlotWidth = 50.0;
    const capsuleHorizontalPadding = 0.0;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Align(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 44,
            padding: const EdgeInsets.symmetric(
              horizontal: capsuleHorizontalPadding,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(tabs.length, (index) {
                final tab = tabs[index];
                final selected = index == effectiveSelectedIndex;
                final colorScheme = Theme.of(context).colorScheme;
                return SizedBox(
                  width: tabSlotWidth,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.go(tab.route),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: selected ? tabSlotWidth : 34,
                          height: selected ? 44 : 30,
                          decoration: selected
                              ? BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(999),
                                )
                              : null,
                          alignment: Alignment.center,
                          child: Icon(
                            selected ? tab.selectedIcon : tab.icon,
                            size: selected ? 20 : 19,
                            color: selected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
                ..add(
                  _NotificationBellButton(
                    unreadCount: unreadNotifications,
                    onTap: () async {
                      final rootContext = context;
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: false,
                        builder: (context) {
                          return _NotificationsSheet(
                            l10n: l10n,
                            feed: clientFeed,
                            readVisitIds: readVisitIds,
                            onNotificationTap: (sheetContext, entry) {
                              ref
                                  .read(clientNotificationsReadProvider.notifier)
                                  .markRead(entry.visit.id);
                              ref
                                  .read(pendingVisitFocusProvider.notifier)
                                  .focusVisit(entry.visit.id);
                              ref.invalidate(propertiesProvider);
                              ref.invalidate(visitsByPropertyProvider);
                              ref.invalidate(clientFeedProvider);
                              Navigator.of(sheetContext).pop();
                              rootContext.go('/home?visitId=${entry.visit.id}');
                            },
                            onMarkAllAsRead: (items) {
                              ref
                                  .read(clientNotificationsReadProvider.notifier)
                                  .markAllRead(items.map((item) => item.visit.id));
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -7,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.l10n,
    required this.feed,
    required this.readVisitIds,
    required this.onNotificationTap,
    required this.onMarkAllAsRead,
  });

  final AppLocalizations l10n;
  final AsyncValue<List<ClientFeedItem>> feed;
  final Set<String> readVisitIds;
  final void Function(BuildContext sheetContext, ClientFeedItem item) onNotificationTap;
  final void Function(List<ClientFeedItem> items) onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.notifications,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: feed.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Text(l10n.somethingWentWrong),
                data: (items) {
                  final latest = items.take(30).toList();
                  final unreadCount = latest
                      .where((item) => !readVisitIds.contains(item.visit.id))
                      .length;
                  if (latest.isEmpty) {
                    return Center(child: Text(l10n.noNotificationsYet));
                  }
                  return Column(
                    children: [
                      if (unreadCount > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => onMarkAllAsRead(latest),
                            icon: const Icon(Icons.done_all, size: 18),
                            label: Text(l10n.markAllAsRead),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: latest.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = latest[index];
                            final message = l10n.newVisitAtProperty(entry.property.name);
                            final isRead = readVisitIds.contains(entry.visit.id);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                              onTap: () => onNotificationTap(context, entry),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.notifications_active_outlined,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                message,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(_formatDate(context, entry.visit.createdAt)),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
}

class _ShellTabItem {
  const _ShellTabItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
}

bool _matchesTabRoute({required String currentPath, required String tabRoute}) {
  if (tabRoute == '/properties') {
    return currentPath == '/properties' ||
        currentPath.startsWith('/properties/');
  }
  if (tabRoute == '/account') {
    return currentPath == '/account' || currentPath == '/profile';
  }
  if (tabRoute == '/profile') {
    return currentPath == '/profile' || currentPath == '/account';
  }
  return currentPath == tabRoute;
}
