import 'package:flutter/material.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class SideMenu extends StatelessWidget {
  final bool isClient;
  final bool isBarber;

  const SideMenu({
    super.key,
    this.isClient = false,
    this.isBarber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD8B081).withOpacity(0.5), width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/Manito.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'MANITO BARBERSHOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: const Color(0xFFD8B081).withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () {
              if (isClient) {
                Navigator.pushReplacementNamed(context, '/client_home');
              } else if (isBarber) {
                Navigator.pushReplacementNamed(context, '/barber_home');
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              if (isClient) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/cliente/perfil');
              } else if (isBarber) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/barbero/perfil');
              } else {
                // Por ahora no hay perfil específico para administrador
                Navigator.pop(context);
              }
            },
          ),
          // Opciones solo administrador
          if (!isClient && !isBarber) ...[
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Ventas'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/ventas');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Agendamientos'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/agendamiento');
              },
            ),
          ],
          // Opciones solo cliente
          if (isClient) ...[
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Mis Citas'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.pushReplacementNamed(context, '/cliente/mis-citas');
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('Mis Compras'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.pushReplacementNamed(context, '/cliente/mis-compras');
              },
            ),
          ],
          // Opciones solo barbero
          if (isBarber) ...[
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Mis Citas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/barbero/mis-citas');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments),
              title: const Text('Mis Ventas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/barbero/mis-ventas');
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final auth = AuthService();
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
    );
  }
}
