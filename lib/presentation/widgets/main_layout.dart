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
import 'package:parte_movil/data/models/cliente.dart';

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
  late final HorariosBloc _horariosBloc;
  late final VentasBloc _ventasBloc;
  List<Widget>? _screens;
  final _userContextService = UserContextService();

  // ── Campos requeridos para agendar ────────────────────────────────────────
  static const _camposInfo = {
    'documento':       (icon: Icons.badge_outlined,          label: 'Tipo y número de documento'),
    'fechaNacimiento': (icon: Icons.cake_outlined,           label: 'Fecha de nacimiento'),
    'telefono':        (icon: Icons.phone_outlined,          label: 'Número de celular'),
    'direccion':       (icon: Icons.location_on_outlined,    label: 'Dirección'),
    'barrio':          (icon: Icons.home_outlined,           label: 'Barrio'),
  };

  List<String> _getPerfilFaltantes(Cliente cliente) {
    final faltantes = <String>[];
    final doc = cliente.documento.trim();
    final isTemp = doc.isEmpty || doc.startsWith('PASO-') || doc.startsWith('TMP') || doc.startsWith('G-');
    if (isTemp) faltantes.add('documento');
    if (cliente.fechaNacimiento == null || cliente.fechaNacimiento!.isEmpty) faltantes.add('fechaNacimiento');
    if (cliente.telefono == null || cliente.telefono!.isEmpty) faltantes.add('telefono');
    if (cliente.direccion == null || cliente.direccion!.isEmpty) faltantes.add('direccion');
    if (cliente.barrio == null || cliente.barrio!.isEmpty) faltantes.add('barrio');
    return faltantes;
  }

  Future<void> _handleClienteNuevaCita() async {
    final cliente = await _userContextService.obtenerClienteActual();
    if (!mounted) return;

    if (cliente != null) {
      final faltantes = _getPerfilFaltantes(cliente);
      if (faltantes.isNotEmpty) {
        _showPerfilIncompletoSheet(faltantes, cliente);
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AgendamientoFormScreen(role: widget.role)),
    ).then((value) {
      if (mounted && value == true) {
        context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1));
      }
    });
  }

  void _showPerfilIncompletoSheet(List<String> faltantes, Cliente cliente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1919),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A3A3A)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8B081).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD8B081).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.person_outline, color: Color(0xFFD8B081), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Completa tu perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 2),
                        Text('Para agendar necesitas completar estos datos:', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...faltantes.map((campo) {
                final info = _camposInfo[campo];
                if (info == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD8B081).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(info.icon, color: const Color(0xFFD8B081), size: 18),
                        const SizedBox(width: 12),
                        Text(info.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF111111)),
                  label: const Text('Completar mi perfil', style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B081),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UpdateProfileScreen(
                        role: widget.role,
                        entidadActual: cliente,
                        email: cliente.email ?? '',
                      )),
                    ).then((_) => _userContextService.limpiarCache());
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _horariosBloc = HorariosBloc(
      horarioService: HorarioBarberoService(),
      barberoService: BarberoService(),
      authService: AuthService(),
      userContextService: UserContextService(),
      role: widget.role,
    )..add(LoadHorariosRequested());

    _ventasBloc = VentasBloc(
      ventaService: VentaService(),
      clienteService: ClienteService(),
      barberoService: BarberoService(),
      authService: AuthService(),
    )..add(const LoadVentasRequested(page: 1));
  }

  @override
  void dispose() {
    _horariosBloc.close();
    _ventasBloc.close();
    super.dispose();
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


          BlocProvider.value(
            value: _ventasBloc,
            child: VentasScreen(role: widget.role),
          ),
          const ServiciosGestionScreen(),
          const ProductosGestionScreen(),
          BlocProvider.value(
            value: _horariosBloc,
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
          BlocProvider.value(
            value: _ventasBloc,
            child: VentasScreen(role: widget.role), // Reutilizamos aquí
          ),
          BlocProvider.value(
            value: _horariosBloc,
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
    final screens = _screens ??= _getScreens();
    
    // Configuración del FAB según el rol y la pantalla actual
    Widget? floatingActionButton;
    final goldGradient = const LinearGradient(
      colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (_currentIndex == 1 && (widget.role == AppRole.admin || widget.role == AppRole.manager)) {
      floatingActionButton = FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendamientoFormScreen())).then((value) {
          if (mounted && value == true) context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1));
        }),
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VentaFormScreen()),
        ).then((value) {
          if (value == true) {
            _ventasBloc.add(const LoadVentasRequested(page: 1));
          }
        }),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductoFormScreen())).then((_) {
          if (mounted) setState(() {});
        }),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: _horariosBloc, child: HorarioFormScreen(role: widget.role)))).then((_) {
          if (mounted) setState(() {});
        }),
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
        onPressed: _handleClienteNuevaCita,
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AgendamientoFormScreen(role: widget.role))).then((value) {
          if (mounted && value == true) context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1));
        }),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: _horariosBloc, child: HorarioFormScreen(role: widget.role)))).then((_) {
          if (mounted) setState(() {});
        }),
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

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
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
