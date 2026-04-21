import 'package:flutter/material.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/widgets/dashboard_ganancias_widget.dart';

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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.content_cut, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Bienvenido, Barbero', style: Theme.of(context).textTheme.titleLarge),
              if (user != null && user.email != null)
                Text(user.email!, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              
              const SizedBox(height: 32),

              const Text(
                'Desde este panel puedes gestionar tus citas y consultar tus ventas.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


