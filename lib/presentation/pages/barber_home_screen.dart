import 'package:flutter/material.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';

class BarberHomeScreen extends StatelessWidget {
  const BarberHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;

    return SessionGuard(
      requiredRole: AppRole.barber,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Barbero'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.content_cut, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Bienvenido, Barbero',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (user != null && user.email != null)
                Text(
                  user.email!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 32),
              const Text(
                'Desde este panel puedes gestionar tus citas y consultar tus ventas.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


