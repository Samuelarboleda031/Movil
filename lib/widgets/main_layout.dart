import 'package:flutter/material.dart';
import '../models/app_role.dart';
import '../screens/home_screen.dart';
import '../screens/agendamientos_screen.dart';
import '../screens/ventas_screen.dart';
import '../screens/servicios_gestion_screen.dart';
import '../screens/client_home_screen.dart';
import '../screens/client_agendamientos_screen.dart';
import '../screens/mis_compras_screen.dart';
import '../screens/client_profile_screen.dart';
import '../screens/barber_home_screen.dart';
import '../screens/barber_agendamientos_screen.dart';
import '../screens/barber_ventas_screen.dart';
import '../screens/barber_profile_screen.dart';

class MainLayout extends StatefulWidget {
  final AppRole role;
  const MainLayout({super.key, required this.role});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  List<Widget> _getScreens() {
    switch (widget.role) {
      case AppRole.manager:
      case AppRole.admin:
        return [
          const HomeScreen(),
          const AgendamientosScreen(),
          const VentasScreen(),
          const ServiciosGestionScreen(),
        ];
      case AppRole.barber:
        return [
          const BarberHomeScreen(),
          const BarberAgendamientosScreen(),
          const BarberVentasScreen(),
          const BarberProfileScreen(),
        ];
      case AppRole.client:
        return [
          const ClientHomeScreen(),
          const ClientAgendamientosScreen(),
          const MisComprasScreen(),
          const ClientProfileScreen(),
        ];
    }
  }

  List<BottomNavigationBarItem> _getNavBarItems() {
    switch (widget.role) {
      case AppRole.manager:
      case AppRole.admin:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Ventas'),
          BottomNavigationBarItem(icon: Icon(Icons.content_cut), label: 'Servicios'),
        ];
      case AppRole.barber:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Mis Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Mis Ventas'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ];
      case AppRole.client:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Mis Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Mis Compras'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _getScreens();
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF111111),
          selectedItemColor: const Color(0xFFD8B081),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: _getNavBarItems(),
        ),
      ),
    );
  }
}
