import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/company_onboarding_provider.dart';
import 'core/providers/session_provider.dart';
import 'core/ui/widgets/app_shell.dart';
import 'features/auth/account_screen.dart';
import 'features/auth/client_profile_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/company/company_screen.dart';
import 'features/onboarding/company_onboarding_screen.dart';
import 'features/properties/client_properties_screen.dart';
import 'features/properties/properties_screen.dart';
import 'features/properties/property_form_screen.dart';
import 'features/visits/client_feed_screen.dart';
import 'features/visits/timeline_screen.dart';
import 'features/visits/new_visit_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(
    sessionProvider.select((session) => session.isAuthenticated),
  );
  final role = ref.watch(sessionProvider.select((session) => session.role));
  final onboardingGate = ref.watch(
    companyOnboardingProvider.select(
      (state) => (
        shouldForceRoute: state.shouldForceRoute,
        needsOnboarding: state.needsOnboarding,
        subscriptionCompleted: state.subscriptionCompleted,
      ),
    ),
  );
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/onboarding/company',
        builder: (context, state) => const CompanyOnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const ClientFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/properties',
                builder: (context, state) {
                  if (role == UserRole.client) {
                    return const ClientPropertiesScreen();
                  }
                  return const PropertiesScreen();
                },
              ),
              GoRoute(
                path: '/properties/new',
                builder: (context, state) => const PropertyFormScreen(),
              ),
              GoRoute(
                path: '/properties/:propertyId/timeline',
                builder: (context, state) {
                  final propertyId = state.pathParameters['propertyId'] ?? '';
                  return TimelineScreen(propertyId: propertyId);
                },
              ),
              GoRoute(
                path: '/properties/:propertyId/new-visit',
                builder: (context, state) {
                  final propertyId = state.pathParameters['propertyId'] ?? '';
                  return NewVisitScreen(propertyId: propertyId);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/company',
                builder: (context, state) {
                  if (role == UserRole.client) {
                    return const ClientPropertiesScreen();
                  }
                  final tabRaw = state.uri.queryParameters['tab'] ?? '0';
                  final tabIndex = int.tryParse(tabRaw) ?? 0;
                  return CompanyScreen(initialTab: tabIndex);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) {
                  if (role == UserRole.client) {
                    return const ClientProfileScreen();
                  }
                  return const AccountScreen();
                },
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) {
                  if (role == UserRole.client) {
                    return const ClientProfileScreen();
                  }
                  return const AccountScreen();
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/share/:token/visits',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return TimelineScreen(
            propertyId: '',
            shareToken: token,
            isClientView: true,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      final isLoginRoute = state.uri.path == '/login';
      final isClientRoute = state.uri.path.startsWith('/share/');
      final isOnboardingRoute = path == '/onboarding/company';

      if (isClientRoute) {
        return null;
      }
      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (!isLoggedIn && isOnboardingRoute) {
        return '/login';
      }
      if (isLoggedIn &&
          role != UserRole.client &&
          onboardingGate.shouldForceRoute &&
          !isOnboardingRoute) {
        return '/onboarding/company';
      }
      if (isLoggedIn &&
          isOnboardingRoute &&
          (role == UserRole.client ||
              !onboardingGate.needsOnboarding ||
              onboardingGate.subscriptionCompleted)) {
        return '/home';
      }
      if (isLoggedIn && isLoginRoute) {
        return '/home';
      }
      if (isLoggedIn && role == UserRole.client && path == '/account') {
        return '/properties';
      }
      if (isLoggedIn && role == UserRole.client && path == '/company') {
        return '/properties';
      }
      if (isLoggedIn && role != UserRole.client && path == '/profile') {
        return '/account';
      }
      return null;
    },
  );
});
