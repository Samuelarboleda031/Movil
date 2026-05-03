import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_bloc.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_event.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_bloc.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_event.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';

import 'package:parte_movil/presentation/pages/home_screen.dart';
import 'package:parte_movil/presentation/pages/agendamientos_screen.dart';
import 'package:parte_movil/presentation/pages/ventas_screen.dart';
import 'package:parte_movil/presentation/pages/servicios_gestion_screen.dart';
import 'package:parte_movil/presentation/pages/productos_gestion_screen.dart';
import 'package:parte_movil/presentation/pages/mis_compras_screen.dart';
import 'package:parte_movil/presentation/pages/profile_screen.dart';
import 'package:parte_movil/presentation/pages/agendamiento_form_screen.dart';
import 'package:parte_movil/presentation/pages/venta_form_screen.dart';
import 'package:parte_movil/presentation/pages/servicio_form_screen.dart';
import 'package:parte_movil/presentation/pages/producto_form_screen.dart';
import 'package:parte_movil/presentation/pages/horarios_gestion_screen.dart';
import 'package:parte_movil/presentation/pages/horario_form_screen.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_bloc.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_event.dart';
import 'package:parte_movil/data/datasources/horario_barbero_service.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class MainLayout extends StatefulWidget {
  final AppRole role;
  const MainLayout({super.key, required this.role});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  List<Widget> _getScreens() {
    switch (widget.role) {
      case AppRole.manager:
      case AppRole.admin:
        return [
          HomeScreen(role: widget.role),
          BlocProvider(
            create: (context) => AgendamientosBloc(
              agendamientoService: AgendamientoService(),
              emailJsService: EmailJsService(),
              authService: AuthService(),
              userContextService: UserContextService(),
            )..add(const LoadAgendamientosRequested(page: 1, estaSemana: false)),
            child: AgendamientosScreen(role: widget.role),
          ),


          BlocProvider(
            create: (context) => VentasBloc(
              ventaService: VentaService(),
              clienteService: ClienteService(),
              barberoService: BarberoService(),
              authService: AuthService(),
            )..add(const LoadVentasRequested(page: 1)),
            child: VentasScreen(role: widget.role),
          ),
          const ServiciosGestionScreen(),
          const ProductosGestionScreen(),
          BlocProvider(
            create: (context) => HorariosBloc(
              horarioService: HorarioBarberoService(),
              barberoService: BarberoService(),
              authService: AuthService(),
              userContextService: UserContextService(),
              role: widget.role,
            )..add(LoadHorariosRequested()),
            child: HorariosGestionScreen(role: widget.role),
          ),
        ];

      case AppRole.barber:
        return [
          HomeScreen(role: widget.role),
          BlocProvider(
            create: (context) => AgendamientosBloc(
              agendamientoService: AgendamientoService(),
              emailJsService: EmailJsService(),
              authService: AuthService(),
              userContextService: UserContextService(),
            )..add(const LoadAgendamientosRequested(page: 1, estaSemana: false)),
            child: AgendamientosScreen(role: widget.role), // Reutilizamos aquí
          ),
          BlocProvider(
            create: (context) => VentasBloc(
              ventaService: VentaService(),
              clienteService: ClienteService(),
              barberoService: BarberoService(),
              authService: AuthService(),
            )..add(const LoadVentasRequested(page: 1)),
            child: VentasScreen(role: widget.role), // Reutilizamos aquí
          ),
          BlocProvider(
            create: (context) => HorariosBloc(
              horarioService: HorarioBarberoService(),
              barberoService: BarberoService(),
              authService: AuthService(),
              userContextService: UserContextService(),
              role: widget.role,
            )..add(LoadHorariosRequested()),
            child: HorariosGestionScreen(role: widget.role),
          ),
          ProfileScreen(role: widget.role),
        ];
      case AppRole.client:
        return [
          HomeScreen(role: widget.role),
          BlocProvider(
            create: (context) => AgendamientosBloc(
              agendamientoService: AgendamientoService(),
              emailJsService: EmailJsService(),
              authService: AuthService(),
              userContextService: UserContextService(),
            )..add(const LoadAgendamientosRequested(page: 1, estaSemana: false)),
            child: AgendamientosScreen(role: widget.role), // Reutilizamos aquí
          ),
          const MisComprasScreen(),
          ProfileScreen(role: widget.role),
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
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Productos'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Horarios'),
        ];
      case AppRole.barber:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Mis Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Mis Ventas'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Horarios'),
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
    final goldGradient = const LinearGradient(
      colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (_currentIndex == 1 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendamientoFormScreen())).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 2 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VentaFormScreen())).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 3 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServicioFormScreen())).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 4 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductoFormScreen())).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 5 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider(create: (_) => HorariosBloc(horarioService: HorarioBarberoService(), barberoService: BarberoService(), authService: AuthService(), userContextService: UserContextService(), role: widget.role), child: HorarioFormScreen(role: widget.role)))).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 1 && widget.role == AppRole.client) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AgendamientoFormScreen(role: widget.role))).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 1 && widget.role == AppRole.barber) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AgendamientoFormScreen(role: widget.role))).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    } else if (_currentIndex == 3 && widget.role == AppRole.barber) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider(create: (_) => HorariosBloc(horarioService: HorarioBarberoService(), barberoService: BarberoService(), authService: AuthService(), userContextService: UserContextService(), role: widget.role), child: HorarioFormScreen(role: widget.role)))).then((_) => setState(() {})),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: goldGradient, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Color(0xFF111111)),
        ),
      );
    }

    final List<BottomNavigationBarItem> items = _getNavBarItems();

    List<Widget> _buildBottomNavRow(List<BottomNavigationBarItem> items) {
      return items.asMap().entries.map((entry) => Expanded(child: _buildNavItem(entry.key, entry.value.icon, entry.value.label!))).toList();
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: _buildBottomNavRow(items),
          ),
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
