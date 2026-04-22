import 'package:flutter/material.dart';

import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class SessionGuard extends StatefulWidget {
  final List<AppRole> allowedRoles;
  final Widget child;

  const SessionGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  final AuthService _auth = AuthService();
  bool _checking = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _validateSession();
  }

  Future<void> _validateSession() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      await _redirectToLogin('Debes iniciar sesión para continuar.');
      return;
    }

    final email = firebaseUser.email!;
    print('[SessionGuard] Validando sesión para $email');

    var usuarioApi = await _auth.getCurrentUser();
    usuarioApi ??= await _auth.fetchUsuarioDesdeApi();

    if (!mounted) return;

    if (usuarioApi == null || usuarioApi.rolId == null) {
      await _redirectToLogin('Tu sesión no es válida. Inicia sesión nuevamente.');
      return;
    }

    final rolActual = roleForRolId(usuarioApi.rolId);
    if (rolActual == null) {
      await _redirectToLogin('Tu rol es desconocido para la aplicación.');
      return;
    }

    print('[SessionGuard] Rol actual $rolActual, permitidos ${widget.allowedRoles}');

    // Lógica flexible: El Gerente (Super Admin ID 1) tiene todos los permisos del Administrador (ID 18)
    bool isAuthorized = widget.allowedRoles.contains(rolActual);
    
    // Si se requiere Admin pero es Manager, también es válido
    if (!isAuthorized && widget.allowedRoles.contains(AppRole.admin) && rolActual == AppRole.manager) {
      isAuthorized = true;
    }

    if (!isAuthorized) {
      await _redirectToRoleHome(
        rolActual,
        'Estás autenticado como ${roleLabel(rolActual)}. No puedes acceder a esta pantalla.',
      );
      return;
    }

    setState(() {
      _authorized = true;
      _checking = false;
    });
  }

  Future<void> _redirectToLogin(String message) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _redirectToRoleHome(AppRole role, String message) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    final route = _homeRouteForRole(role);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  String _homeRouteForRole(AppRole role) {
    switch (role) {
      case AppRole.client:
        return '/main-client';
      case AppRole.barber:
        return '/main-barber';
      case AppRole.manager:
      case AppRole.admin:
        return '/main-admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authorized) {
      return const SizedBox.shrink();
    }

    return widget.child;
  }
}

