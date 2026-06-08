import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/app_role.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        await firebaseUser.getIdToken(true);
      } catch (_) {
        await _authService.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
    }

    final usuario = await _authService.getCurrentUser();
    if (!mounted) return;

    final role = roleForRolId(usuario?.rolId);
    final route = _homeRouteForRole(role ?? AppRole.client);
    Navigator.pushReplacementNamed(context, route);
  }

  String _homeRouteForRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return '/main-admin';
      case AppRole.barber:
        return '/main-barber';
      case AppRole.manager:
        return '/main-admin';
      case AppRole.client:
        return '/main-client';
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );
  }
}
