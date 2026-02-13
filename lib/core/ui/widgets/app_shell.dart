import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isClient = session.role == UserRole.client;
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
            padding: const EdgeInsets.symmetric(horizontal: capsuleHorizontalPadding),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
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
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.75),
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
              }),
            ),
          ),
        ),
      ),
    );
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

bool _matchesTabRoute({
  required String currentPath,
  required String tabRoute,
}) {
  if (tabRoute == '/properties') {
    return currentPath == '/properties' || currentPath.startsWith('/properties/');
  }
  if (tabRoute == '/account') {
    return currentPath == '/account' || currentPath == '/profile';
  }
  if (tabRoute == '/profile') {
    return currentPath == '/profile' || currentPath == '/account';
  }
  return currentPath == tabRoute;
}
