import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_bloc.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_event.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MANITO BARBERSHOP'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text('¿Estás seguro de que deseas salir?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Salir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                 if (confirm == true) {
                   if (context.mounted) {
                     context.read<AuthBloc>().add(LogoutRequested());
                     Navigator.pushReplacementNamed(context, '/');
                   }
                 }

              },
            ),
          ],
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Bienvenido${user != null ? ': ${user.email}' : ''}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/ventas'),
              child: const Text('Ir a Ventas'),
            ),
          ]),
        ),
      ),
    );
  }
}
