import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/documents_sheet.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/cases/presentation/case_flow_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/catalog/presentation/discipline_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/leaderboard/presentation/leaderboard_page.dart';
import '../features/lesson/presentation/lesson_page.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/practice/presentation/practice_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/education/presentation/education_page.dart';
import '../features/education/presentation/university_search_page.dart';
import '../features/learning/data/learning_models.dart';
import '../features/quiz/presentation/quiz_flow_page.dart';
import '../features/settings/presentation/change_password_page.dart';
import '../features/settings/presentation/delete_account_page.dart';
import '../features/settings/presentation/sessions_page.dart';
import 'routes.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Куда пустить при текущем состоянии входа; null — оставить как есть.
String? authRedirect(AuthState auth, String location) {
  final isPublic = Routes.public.contains(location);
  return switch (auth) {
    AuthRestoring() => location == Routes.splash ? null : Routes.splash,
    SignedOut() => isPublic ? null : Routes.welcome,
    AwaitingVerification() => location == Routes.verify ? null : Routes.verify,
    SignedIn() => isPublic || location == Routes.splash || location == Routes.verify ? Routes.home : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);

  GoRoute page(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (_, s) => build(s));

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (_, state) => authRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.welcome,
        builder: (context, _) =>
            OnboardingScreen(onStart: () => context.push(Routes.register), onLogin: () => context.push(Routes.login)),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, _) => LoginScreen(
          onBack: () => context.go(Routes.welcome),
          onForgot: () => context.push(Routes.forgot),
          onRegister: () => context.go(Routes.register),
        ),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, _) => RegisterScreen(
          onBack: () => context.go(Routes.welcome),
          onLogin: () => context.go(Routes.login),
          onDocuments: () => showDocumentsSheet(context),
        ),
      ),
      GoRoute(
        path: Routes.forgot,
        builder: (context, _) => ForgotPasswordScreen(
          onBack: context.pop,
          onDone: () {
            context.go(Routes.login);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Пароль изменён. Войдите с новым паролем.')));
          },
        ),
      ),
      GoRoute(path: Routes.verify, builder: (_, _) => const VerifyEmailPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          tab: AppTab.values[shell.currentIndex],
          onTab: (t) => shell.goBranch(t.index, initialLocation: t.index == shell.currentIndex),
          child: shell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.catalog,
                builder: (_, _) => const CatalogPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => DisciplinePage(id: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.practice, builder: (_, _) => const PracticePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.leaderboard, builder: (_, _) => const LeaderboardPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfilePage())],
          ),
        ],
      ),
      page('/lesson/:id', (s) => LessonPage(id: s.pathParameters['id']!)),
      page('/quiz/:quizId', (s) => QuizFlowPage(id: s.pathParameters['quizId']!)),
      page('/training/:slug', (s) => QuizFlowPage(mode: QuizMode.training, id: s.pathParameters['slug']!)),
      page('/mistakes/:slug', (s) => QuizFlowPage(mode: QuizMode.mistakes, id: s.pathParameters['slug']!)),
      page('/case/:id', (s) => CaseFlowPage(id: s.pathParameters['id']!)),
      page(Routes.progress, (_) => const ProgressPage()),
      page(Routes.sessions, (_) => const SessionsPage()),
      page(Routes.password, (_) => const ChangePasswordPage()),
      page(Routes.deleteAccount, (_) => const DeleteAccountPage()),
      page(Routes.education, (_) => const EducationPage()),
      page(Routes.universitySearch, (_) => const UniversitySearchPage()),
    ],
  );
});
