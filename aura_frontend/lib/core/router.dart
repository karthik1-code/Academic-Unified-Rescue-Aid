import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/views/onboarding_view.dart';
import 'package:aura_frontend/views/shell_view.dart';
import 'package:aura_frontend/views/dashboard_view.dart';
import 'package:aura_frontend/views/chat_view.dart';
import 'package:aura_frontend/views/calendar_view.dart';
import 'package:aura_frontend/views/syllabus_view.dart';
import 'package:aura_frontend/views/profile_view.dart';

import 'package:aura_frontend/views/auth/login_view.dart';
import 'package:aura_frontend/views/auth/register_view.dart';
import 'package:aura_frontend/views/auth/forgot_password_view.dart';

import 'package:aura_frontend/views/todo_view.dart';
import 'package:aura_frontend/views/exams_view.dart';
import 'package:aura_frontend/views/assignments_view.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: ref.read(authProvider) == null ? '/login' : '/dashboard',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState != null;
      final location = state.matchedLocation;
      
      final isAuthRoute = location == '/login' || 
                          location == '/register' || 
                          location == '/forgot-password';
      
      if (!isLoggedIn && !isAuthRoute && location != '/onboarding') {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterView(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShellView(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardView()),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) => const NoTransitionPage(child: AuraChatView()),
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (context, state) => const NoTransitionPage(child: CalendarView()),
          ),
          GoRoute(
            path: '/syllabus',
            pageBuilder: (context, state) => const NoTransitionPage(child: SyllabusView()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileView()),
          ),
          GoRoute(
            path: '/todo',
            pageBuilder: (context, state) => const NoTransitionPage(child: TodoView()),
          ),
          GoRoute(
            path: '/exams',
            pageBuilder: (context, state) => const NoTransitionPage(child: ExamsView()),
          ),
          GoRoute(
            path: '/assignments',
            pageBuilder: (context, state) => const NoTransitionPage(child: AssignmentsView()),
          ),
        ],
      ),
    ],
  );
});
