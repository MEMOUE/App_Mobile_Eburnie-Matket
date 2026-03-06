// lib/config/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/accueil/accueil_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/profile_edit_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../services/auth_service.dart';

class AppRouter {
  // Routes publiques (accessibles sans connexion)
  static const _publicPaths = [
    '/accueil',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/annonces',
    '/search',
  ];

  static final GoRouter router = GoRouter(
    initialLocation: '/accueil',
    redirect: (context, state) {
      final isAuth = AuthService().isAuthenticated;
      final path = state.matchedLocation;

      final isAuthScreen = [
        '/login',
        '/register',
        '/forgot-password',
      ].any((p) => path.startsWith(p));

      final isPublic = _publicPaths.any((p) => path.startsWith(p));

      // Connecté sur un écran auth → dashboard
      if (isAuth && isAuthScreen) return '/dashboard';

      // Non connecté sur route protégée → login
      if (!isAuth && !isPublic) return '/login';

      return null;
    },
    routes: [
      // ── Accueil (public) ──────────────────────────────────────────────────
      GoRoute(
        path: '/accueil',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          AccueilScreen(
            onGoToDashboard: () => context.go('/dashboard'),
            onGoToLogin: () => context.go('/login'),
            onGoToRegister: () => context.go('/register'),
            onGoToSearch: () => context.go('/search'),
            onGoToAdDetail: (id) => context.go('/annonces/$id'),
            onGoToCategory: (cat) => cat.isEmpty
                ? context.go('/annonces')
                : context.go('/annonces?category=$cat'),
            onGoToNewAd: () => AuthService().isAuthenticated
                ? context.go('/dashboard/new-ad')
                : context.go('/login'),
          ),
        ),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          LoginScreen(
            onLoginSuccess: () => context.go('/dashboard'),
            onGoToRegister: () => context.go('/register'),
            onGoToForgotPassword: () => context.go('/forgot-password'),
          ),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _slideTransition(
          state,
          RegisterScreen(
            onRegisterSuccess: () => context.go('/login'),
            onGoToLogin: () => context.go('/login'),
          ),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _slideTransition(
          state,
          ForgotPasswordScreen(onGoToLogin: () => context.go('/login')),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return _slideTransition(
            state,
            ResetPasswordScreen(
              token: token,
              onGoToLogin: () => context.go('/login'),
              onGoToForgotPassword: () => context.go('/forgot-password'),
            ),
          );
        },
      ),

      // ── Dashboard (protégé) ───────────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          DashboardScreen(
            onGoToProfile: () => context.go('/dashboard/profile-edit'),
            onGoToMyAds: () => context.go('/my-ads'),
            onGoToNewAd: () => context.go('/dashboard/new-ad'),
            onGoToHome: () => context.go('/accueil'),
            onLogout: () async {
              await AuthService().logout();
              if (context.mounted) context.go('/accueil');
            },
          ),
        ),
        routes: [
          GoRoute(
            path: 'profile-edit',
            pageBuilder: (context, state) => _slideTransition(
              state,
              ProfileEditScreen(
                onSaved: () => context.go('/dashboard'),
                onCancel: () => context.go('/dashboard'),
                onGoToChangePassword: () =>
                    context.go('/dashboard/change-password'),
              ),
            ),
          ),
          GoRoute(
            path: 'change-password',
            pageBuilder: (context, state) =>
                _slideTransition(state, const _ChangePasswordPlaceholder()),
          ),
          GoRoute(
            path: 'new-ad',
            pageBuilder: (context, state) =>
                _slideTransition(state, const _NewAdPlaceholder()),
          ),
        ],
      ),

      // ── Mes annonces ──────────────────────────────────────────────────────
      GoRoute(
        path: '/my-ads',
        pageBuilder: (context, state) =>
            _slideTransition(state, const _MyAdsPlaceholder()),
      ),

      // ── Annonces (public) ─────────────────────────────────────────────────
      GoRoute(
        path: '/annonces',
        pageBuilder: (context, state) {
          final cat = state.uri.queryParameters['category'] ?? '';
          return _slideTransition(state, _AnnoncesPlaceholder(category: cat));
        },
      ),
      GoRoute(
        path: '/annonces/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slideTransition(state, _AdDetailPlaceholder(id: id));
        },
      ),

      // ── Recherche (public) ────────────────────────────────────────────────
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters['q'] ?? '';
          return _slideTransition(state, _SearchPlaceholder(query: q));
        },
      ),
    ],

    // ── 404 ───────────────────────────────────────────────────────────────
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7ED),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'Page introuvable',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => context.go('/accueil'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Retour à l\'accueil',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

  // ── Transitions ───────────────────────────────────────────────────────────

  static CustomTransitionPage _fadeTransition(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, _, c) =>
          FadeTransition(opacity: animation, child: c),
    );
  }

  static CustomTransitionPage _slideTransition(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, _, c) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
        child: c,
      ),
    );
  }
}

// ── Placeholders ──────────────────────────────────────────────────────────────

class _ChangePasswordPlaceholder extends StatelessWidget {
  const _ChangePasswordPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: const Center(child: Text('🔒 À implémenter')),
    );
  }
}

class _NewAdPlaceholder extends StatelessWidget {
  const _NewAdPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle annonce')),
      body: const Center(child: Text('📝 À implémenter')),
    );
  }
}

class _MyAdsPlaceholder extends StatelessWidget {
  const _MyAdsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes annonces')),
      body: const Center(child: Text('📋 À implémenter')),
    );
  }
}

class _AnnoncesPlaceholder extends StatelessWidget {
  final String category;
  const _AnnoncesPlaceholder({this.category = ''});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.isEmpty ? 'Toutes les annonces' : category),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/accueil'),
        ),
      ),
      body: const Center(child: Text('🗂️ Liste des annonces — À implémenter')),
    );
  }
}

class _AdDetailPlaceholder extends StatelessWidget {
  final String id;
  const _AdDetailPlaceholder({required this.id});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Annonce #$id'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/accueil'),
        ),
      ),
      body: Center(child: Text('🔍 Détail annonce $id — À implémenter')),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  final String query;
  const _SearchPlaceholder({this.query = ''});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(query.isEmpty ? 'Recherche' : '"$query"'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/accueil'),
        ),
      ),
      body: Center(child: Text('🔍 Résultats pour "$query" — À implémenter')),
    );
  }
}
