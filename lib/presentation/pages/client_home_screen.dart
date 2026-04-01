import 'package:flutter/material.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;

    return SessionGuard(
      requiredRole: AppRole.client,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Cuenta'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Bienvenido, Cliente',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (user != null && user.email != null)
                Text(
                  user.email!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 32),
              const Text(
                'Módulo de agendamiento deshabilitado',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'El sistema de citas no está disponible actualmente.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
