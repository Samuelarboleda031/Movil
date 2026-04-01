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
import '../screens/agendamiento_form_screen.dart';
import '../screens/venta_form_screen.dart';
import '../screens/servicio_form_screen.dart';
import '../screens/client_agendamiento_form_screen.dart';
import '../screens/barber_agendamiento_form_screen.dart';

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
    
    // Configuración del FAB según el rol y la pantalla actual
    Widget? floatingActionButton;
    if (_currentIndex == 1 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      // Agendamientos Admin
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendamientoFormScreen())).then((_) => setState(() {})),
        child: const Icon(Icons.add),
      );
    } else if (_currentIndex == 2 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      // Ventas Admin
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VentaFormScreen())).then((_) => setState(() {})),
        child: const Icon(Icons.add),
      );
    } else if (_currentIndex == 3 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      // Servicios Admin
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServicioFormScreen())).then((_) => setState(() {})),
        child: const Icon(Icons.add),
      );
    } else if (_currentIndex == 1 && widget.role == AppRole.client) {
      // Agendamiento para Clientes
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientAgendamientoFormScreen())).then((_) => setState(() {})),
        child: const Icon(Icons.add),
      );
    } else if (_currentIndex == 1 && widget.role == AppRole.barber) {
      // Agendamiento para Barberos
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BarberAgendamientoFormScreen())).then((_) => setState(() {})),
        child: const Icon(Icons.add),
      );
    }

    final List<BottomNavigationBarItem> items = _getNavBarItems();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFF111111),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, items[0].icon, items[0].label!),
            _buildNavItem(1, items[1].icon, items[1].label!),
            const SizedBox(width: 40), // Espacio para el FAB
            _buildNavItem(2, items[2].icon, items[2].label!),
            _buildNavItem(3, items[3].icon, items[3].label!),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, Widget icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              color: isSelected ? const Color(0xFFD8B081) : Colors.grey,
              size: 24,
            ),
            child: icon,
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFD8B081) : Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
