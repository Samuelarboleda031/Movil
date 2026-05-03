import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/data/datasources/dashboard_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class DashboardGananciasWidget extends StatefulWidget {
  final AppRole role;
  const DashboardGananciasWidget({super.key, required this.role});

  @override
  State<DashboardGananciasWidget> createState() => _DashboardGananciasWidgetState();
}

class _DashboardGananciasWidgetState extends State<DashboardGananciasWidget> {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();
  final BarberoService _barberoService = BarberoService();

  bool _isLoading = true;
  String? _error;

  double _gananciasBarberos = 0;
  double _gananciaBarberia = 0;

  List<Barbero> _barberosCat = [];

  String _filtroPeriodo = 'hoy'; // hoy, semanal, mensual, anual
  String _selectedBarberoId = 'Todos';

  Barbero? _currentBarberoUser;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = await _authService.getCurrentUser();
      final fbUser = _authService.currentUser;
      final barberos = await _barberoService.obtenerBarberos();
      final emailBuscado = user?.correo ?? fbUser?.email ?? '';

      if (widget.role == AppRole.barber) {
        final barberoLocal = barberos.firstWhere(
          (b) => (b.email ?? '').toLowerCase() == emailBuscado.toLowerCase(),
          orElse: () => throw Exception('Perfil de barbero no encontrado'),
        );
        _currentBarberoUser = barberoLocal;
        _selectedBarberoId = barberoLocal.id.toString();
      }

      _barberosCat = barberos;
      await _cargarGanancias();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarGanancias() async {
    setState(() => _isLoading = true);
    try {
      String barberoBusqueda = 'Todos';
      if (_selectedBarberoId != 'Todos') {
        final selecteB = _barberosCat.where((b) => b.id.toString() == _selectedBarberoId).firstOrNull;
        if (selecteB != null) {
          barberoBusqueda = selecteB.nombre; // Enviamos el nombre para que el backend haga el match
        } else if (_currentBarberoUser != null) {
          barberoBusqueda = _currentBarberoUser!.nombre;
        }
      }

      final data = await _dashboardService.obtenerGanancias(_filtroPeriodo, barberoBusqueda);
      if (mounted) {
        setState(() {
          _gananciasBarberos = double.tryParse(data['gananciasBarberos']?.toString() ?? '0') ?? 0;
          _gananciaBarberia = double.tryParse(data['gananciasBarberia']?.toString() ?? '0') ?? 0;
          _error = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text('Error al cargar métricas: $_error', style: const TextStyle(color: Colors.red)),
      );
    }

    // Si es barbero, mostrar solo sus ganancias
    if (widget.role == AppRole.barber) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFiltrosBarbero(),
          const SizedBox(height: 16),
          _buildTarjetaBarbero('Tus Ganancias', _gananciasBarberos, Icons.content_cut),
        ],
      );
    }
    
    // Admin/Manager - mostrar ambas tarjetas
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFiltrosAdmin(),
        const SizedBox(height: 16),
        _buildTarjeta('Ganancias Barberos (60%)', _gananciasBarberos, Icons.content_cut, false),
        const SizedBox(height: 16),
        _buildTarjeta('Ganancia Barbería (40%)', _gananciaBarberia, Icons.attach_money, true),
      ],
    );
  }

  Widget _buildFiltrosAdmin() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text('Filtros de Ganancias', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Periodo', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    value: _filtroPeriodo,
                    items: const [
                      DropdownMenuItem(value: 'hoy', child: Text('Hoy')),
                      DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                      DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                      DropdownMenuItem(value: 'anual', child: Text('Anual')),
                    ],
                    onChanged: (v) { 
                      if (v != null) {
                        setState(() => _filtroPeriodo = v);
                        _cargarGanancias();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Barbero', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    value: _selectedBarberoId,
                    items: [
                      const DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      ..._barberosCat.map((b) => DropdownMenuItem(value: b.id.toString(), child: Text(b.nombreCompleto)))
                    ],
                    onChanged: (v) { 
                      if (v != null) {
                        setState(() => _selectedBarberoId = v);
                        _cargarGanancias();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosBarbero() {
    return Row(
      children: [
        const Text('Periodo: ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
            value: _filtroPeriodo,
            items: const [
              DropdownMenuItem(value: 'hoy', child: Text('Hoy')),
              DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
              DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
              DropdownMenuItem(value: 'anual', child: Text('Anual')),
            ],
            onChanged: (v) { 
              if (v != null) {
                setState(() => _filtroPeriodo = v);
                _cargarGanancias();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTarjeta(String titulo, double valor, IconData icono, bool isGold) {
    String subtitle = 'Un barbero';
    if (isGold) {
      subtitle = 'Solo en servicios';
    } else {
      if (_selectedBarberoId == 'Todos') {
        subtitle = 'Todos los barberos';
      } else {
        final selecteB = _barberosCat.where((b) => b.id.toString() == _selectedBarberoId).firstOrNull;
        subtitle = selecteB?.nombreCompleto ?? _currentBarberoUser?.nombreCompleto ?? 'Un barbero';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isGold ? const Color(0xFFD8B081).withOpacity(0.5) : Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isGold ? const Color(0xFFD8B081) : Colors.grey).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icono, size: 30, color: isGold ? const Color(0xFFD8B081) : Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(AppFormat.cop(valor), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isGold ? const Color(0xFFD8B081) : Colors.white)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: isGold ? const Color(0xFFD8B081) : Colors.greenAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta especial para barbero (estilo dorado premium)
  Widget _buildTarjetaBarbero(String titulo, double valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
        gradient: LinearGradient(
          colors: [
            AppColors.card,
            AppColors.card.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, size: 28, color: AppColors.bg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(AppFormat.cop(valor), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.white)),
                const SizedBox(height: 4),
                Text(
                  '60% de tus servicios',
                  style: TextStyle(fontSize: 12, color: AppColors.gold.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
