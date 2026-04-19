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
import '../screens/annonces/create_annonce_screen.dart';
import '../screens/annonces/list_annonce_screen.dart';
import '../screens/annonces/detail_annonce_screen.dart';
import '../screens/annonces/my_ds_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/magasin/list_magasin_screen.dart';
import '../screens/magasin/detail_magasin_screen.dart';
import '../screens/magasin/my_magasin_screen.dart';
import '../screens/magasin/new_magasin_screen.dart';
import '../screens/magasin/list_marche_screen.dart';

class AppRouter {
  static const _publicPaths = [
    '/accueil',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/annonces',
    '/search',
    '/magasins', // public
    '/marches', // public
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

      if (isAuth && isAuthScreen) return '/dashboard';
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
                ? context.go('/create-ad')
                : context.go('/login'),
            onGoToMagasin: (id) => context.push('/magasins/$id'),
            onGoToMagasins: () => context.go('/magasins'),
            onGoToMagasinsByMarche: (marche) =>
                context.go('/magasins?marche=$marche'),
            onGoToMarches: () => context.go('/marches'),
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
            onGoBack: () =>
                context.canPop() ? context.pop() : context.go('/accueil'),
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
            onGoBack: () =>
                context.canPop() ? context.pop() : context.go('/accueil'),
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
            onGoToNewAd: () => context.go('/create-ad'),
            onGoToHome: () => context.go('/accueil'),
            onGoToPremium: () => context.go('/premium'),
            onGoToMyMagasins: () => context.go('/my-magasins'),
            onGoToNewMagasin: () => context.go('/create-magasin'),
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
        ],
      ),

      // ── Premium (protégé) ──────────────────────────────────────────────────
      GoRoute(
        path: '/premium',
        pageBuilder: (context, state) => _slideTransition(
          state,
          PremiumScreen(onBack: () => context.go('/dashboard')),
        ),
      ),

      // ── Mes annonces (protégé) ─────────────────────────────────────────────
      GoRoute(
        path: '/my-ads',
        pageBuilder: (context, state) =>
            _slideTransition(state, const MyAdsScreen()),
      ),

      // ── Créer une annonce (protégé) ────────────────────────────────────────
      GoRoute(
        path: '/create-ad',
        pageBuilder: (context, state) =>
            _slideTransition(state, const CreateAnnonceScreen()),
      ),

      // ── Modifier une annonce (protégé) ─────────────────────────────────────
      GoRoute(
        path: '/edit-ad/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slideTransition(state, CreateAnnonceScreen(adId: id));
        },
      ),

      // ── Liste annonces (public) ────────────────────────────────────────────
      GoRoute(
        path: '/annonces',
        pageBuilder: (context, state) {
          final cat = state.uri.queryParameters['category'];
          final city = state.uri.queryParameters['city'];
          final search = state.uri.queryParameters['search'];
          return _slideTransition(
            state,
            ListAnnonceScreen(
              initialCategory: cat,
              initialCity: city,
              initialSearch: search,
              onGoToLogin: () => context.go('/login'),
              onGoBack: () =>
                  context.canPop() ? context.pop() : context.go('/accueil'),
            ),
          );
        },
      ),

      // ── Détail annonce (public) ────────────────────────────────────────────
      GoRoute(
        path: '/annonces/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slideTransition(
            state,
            DetailAnnonceScreen(
              adId: id,
              onGoToLogin: () => context.go('/login'),
            ),
          );
        },
      ),

      // ── Recherche (public) ─────────────────────────────────────────────────
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters['q'];
          return _slideTransition(
            state,
            ListAnnonceScreen(
              initialSearch: q,
              onGoToLogin: () => context.go('/login'),
              onGoBack: () =>
                  context.canPop() ? context.pop() : context.go('/accueil'),
            ),
          );
        },
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ── MAGASINS ──────────────────────────────────────────────────────────
      // ══════════════════════════════════════════════════════════════════════

      // ── Liste marchés (public) ─────────────────────────────────────────────
      GoRoute(
        path: '/marches',
        pageBuilder: (context, state) =>
            _slideTransition(state, const ListMarcheScreen()),
      ),

      // ── Liste magasins (public) ────────────────────────────────────────────
      GoRoute(
        path: '/magasins',
        pageBuilder: (context, state) {
          final ville = state.uri.queryParameters['ville'];
          final cat = state.uri.queryParameters['categorie'];
          final marche = state.uri.queryParameters['marche'];
          return _slideTransition(
            state,
            ListMagasinScreen(
              initialVille: ville,
              initialCategorie: cat,
              initialMarche: marche,
            ),
          );
        },
      ),

      // ── Détail magasin (public) ────────────────────────────────────────────
      GoRoute(
        path: '/magasins/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return _slideTransition(state, DetailMagasinScreen(magasinId: id));
        },
      ),

      // ── Mes magasins (protégé) ─────────────────────────────────────────────
      GoRoute(
        path: '/my-magasins',
        pageBuilder: (context, state) =>
            _slideTransition(state, const MyMagasinScreen()),
      ),

      // ── Créer un magasin (protégé) ─────────────────────────────────────────
      GoRoute(
        path: '/create-magasin',
        pageBuilder: (context, state) =>
            _slideTransition(state, const NewMagasinScreen()),
      ),

      // ── Modifier un magasin (protégé) ──────────────────────────────────────
      GoRoute(
        path: '/edit-magasin/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return _slideTransition(state, NewMagasinScreen(magasinId: id));
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

class _ChangePasswordPlaceholder extends StatelessWidget {
  const _ChangePasswordPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer le mot de passe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : null,
        ),
      ),
      body: const Center(child: Text('🔒 À implémenter')),
    );
  }
}
