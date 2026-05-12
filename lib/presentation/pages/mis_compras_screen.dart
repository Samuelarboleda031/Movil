import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/presentation/pages/venta_detalle_screen.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/widgets/ellipsis_pagination.dart';
import 'package:parte_movil/data/datasources/devolucion_service.dart';

class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  final TextEditingController _searchController = TextEditingController();
  final VentaService _ventaService = VentaService();
  final UserContextService _userContextService = UserContextService();
  final AuthService _authService = AuthService();
  final BarberoService _barberoService = BarberoService();
  final ServicioService _servicioService = ServicioService();
  final PaqueteService _paqueteService = PaqueteService();
  final DevolucionService _devolucionService = DevolucionService();
  
  List<Venta> _ventas = [];
  double _saldoAFavor = 0;
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 5;
  String _searchQuery = '';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _periodoActivo = '';
  bool _filtroFechaActivo = false;
  final Map<int, String> _nombresBarberos = {};
  final Map<int, String> _nombresUsuarios = {};
  final Map<int, String> _nombresProductos = {};
  final Map<int, String> _nombresServicios = {};
  final Map<int, String> _nombresPaquetes = {};

  @override
  void initState() {
    super.initState();
    _cargarCompras();
  }

  Future<void> _cargarCompras() async {
    setState(() => _isLoading = true);
    try {
      final cliente = await _userContextService.obtenerClienteActual();
      if (cliente == null || cliente.id == null) {
        throw Exception('Perfil de cliente no encontrado');
      }

      final paginacion = await _ventaService.obtenerVentas(page: 1, pageSize: 5000);
      final misVentas = paginacion.items.where((v) => v.clienteId == cliente.id).toList();

      final barberos = await _barberoService.obtenerBarberos();
      for (var b in barberos) {
        if (b.id != null) {
          _nombresBarberos[b.id!] = b.nombreCompleto;
        }
      }

      try {
        final usuarios = await _authService.obtenerUsuarios();
        for (var u in usuarios) {
          if (u.id != null) {
            _nombresUsuarios[u.id!] = u.nombreCompleto;
          }
        }
      } catch (e) {
        print('Error cargando usuarios: $e');
      }

      try {
        final productos = await ProductoService().getProductos(pageSize: 1000);
        for (var p in productos) {
          if (p.id != null) _nombresProductos[p.id!] = p.nombre;
        }
        
        final servicios = await _servicioService.obtenerServicios();
        for (var s in servicios) {
          if (s.id != null) _nombresServicios[s.id!] = s.nombre;
        }

        final paquetes = await _paqueteService.obtenerPaquetes();
        for (var p in paquetes) {
          if (p.id != null) _nombresPaquetes[p.id!] = p.nombre;
        }
      } catch (e) {
        print('Error cargando catálogos de ítems: $e');
      }

      double saldo = 0;
      try {
        saldo = await _devolucionService.obtenerSaldoAFavor(cliente.id!);
      } catch (e) {
        print('Error cargando saldo a favor: $e');
      }
      
      setState(() {
        _ventas = misVentas;
        _saldoAFavor = saldo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Venta> get _ventasFiltradas {
    var resultado = _ventas;

    if (_filtroFechaActivo && (_fechaDesde != null || _fechaHasta != null)) {
      resultado = resultado.where((v) {
        if (v.fechaRegistro == null || v.fechaRegistro!.isEmpty) return false;
        try {
          final fecha = DateTime.parse(v.fechaRegistro!);
          if (_fechaDesde != null) {
            final desde = DateTime(_fechaDesde!.year, _fechaDesde!.month, _fechaDesde!.day);
            if (fecha.isBefore(desde)) return false;
          }
          if (_fechaHasta != null) {
            final hasta = DateTime(_fechaHasta!.year, _fechaHasta!.month, _fechaHasta!.day, 23, 59, 59);
            if (fecha.isAfter(hasta)) return false;
          }
          return true;
        } catch (_) { return false; }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      resultado = resultado.where((v) => v.numero.toLowerCase().contains(q)).toList();
    }

    return resultado;
  }

  Future<void> _seleccionarFechasCompras() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _fechaDesde != null && _fechaHasta != null ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!) : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD8B081),
            onPrimary: Color(0xFF111111),
            surface: Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (rango != null) {
      setState(() { 
        _fechaDesde = rango.start; 
        _fechaHasta = rango.end; 
        _filtroFechaActivo = true;
        _periodoActivo = '';
        _currentPage = 1; 
      });
    }
  }

  void _setFechaRapida(String periodo) {
    final hoy = DateTime.now();
    setState(() {
      _periodoActivo = periodo;
      _filtroFechaActivo = true;
      _currentPage = 1;
      switch (periodo) {
        case 'hoy':
          _fechaDesde = hoy;
          _fechaHasta = hoy;
          break;
        case 'semanal':
          _fechaDesde = hoy.subtract(Duration(days: hoy.weekday - 1));
          _fechaHasta = hoy;
          break;
        case 'mensual':
          _fechaDesde = DateTime(hoy.year, hoy.month, 1);
          _fechaHasta = hoy;
          break;
      }
    });
  }

  Widget _buildQuickDateBtn(String label, String periodo) {
    final sel = _periodoActivo == periodo && _filtroFechaActivo;
    return GestureDetector(
      onTap: () => _setFechaRapida(periodo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFD8B081).withOpacity(0.2) : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? const Color(0xFFD8B081) : Colors.grey.shade800),
        ),
        child: Text(
          label,
          style: TextStyle(color: sel ? const Color(0xFFD8B081) : Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _fechaDesde = null;
      _fechaHasta = null;
      _filtroFechaActivo = false;
      _periodoActivo = '';
      _currentPage = 1;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.client],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Compras'),
        ),
        body: Column(
          children: [
            // Saldo a Favor Header
            if (!_isLoading) 
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A1A0E), Color(0xFF1A1008)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8B081).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'SALDO A FAVOR DISPONIBLE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFormat.cop(_saldoAFavor),
                      style: const TextStyle(
                        color: Color(0xFFD8B081),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por número de ticket...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Selector de rango
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _periodoActivo = '';
                            _seleccionarFechasCompras();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: _filtroFechaActivo && _periodoActivo.isEmpty
                                  ? const Color(0xFFD8B081).withOpacity(0.15)
                                  : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _filtroFechaActivo && _periodoActivo.isEmpty ? const Color(0xFFD8B081) : Colors.grey.shade800,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 16,
                                  color: _filtroFechaActivo ? const Color(0xFFD8B081) : Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _filtroFechaActivo && _fechaDesde != null && _fechaHasta != null
                                        ? '${_fechaDesde!.day}/${_fechaDesde!.month} - ${_fechaHasta!.day}/${_fechaHasta!.month}'
                                        : 'Filtrar por fecha',
                                    style: TextStyle(
                                      color: _filtroFechaActivo ? const Color(0xFFD8B081) : Colors.grey,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_filtroFechaActivo)
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _fechaDesde = null; _fechaHasta = null;
                                      _filtroFechaActivo = false; _periodoActivo = '';
                                    }),
                                    child: const Icon(Icons.close, size: 16, color: Color(0xFFD8B081)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickDateBtn('Hoy', 'hoy'),
                      const SizedBox(width: 6),
                      _buildQuickDateBtn('Semana', 'semanal'),
                      const SizedBox(width: 6),
                      _buildQuickDateBtn('Mes', 'mensual'),
                    ],
                  ),
                  if (_filtroFechaActivo || _searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _limpiarFiltros,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8B081).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_alt_off, size: 14, color: Color(0xFFD8B081)),
                              SizedBox(width: 4),
                              Text('Limpiar filtros', style: TextStyle(fontSize: 12, color: Color(0xFFD8B081))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ventasFiltradas.isEmpty
                      ? const Center(child: Text('No hay compras registradas'))
                      : RefreshIndicator(
                          onRefresh: _cargarCompras,
                          child: Builder(
                            builder: (context) {
                              final totalItems = _ventasFiltradas.length;
                              final totalPages = (totalItems / _pageSize).ceil();
                              final startIndex = (_currentPage - 1) * _pageSize;
                              final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
                              final currentPageItems = _ventasFiltradas.sublist(startIndex, endIndex);

                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                itemCount: currentPageItems.length + (totalPages > 1 ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == currentPageItems.length) {
                                    return _buildPaginationControls(totalPages);
                                  }
                                  return _buildCompraCard(currentPageItems[index]);
                                },
                              );
                            }
                          ),
                        ),
                        ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EllipsisPagination(
        totalPages: totalPages,
        currentPage: _currentPage,
        onPageChanged: (page) => setState(() => _currentPage = page),
      ),
    );
  }


  String _getResponsableName(Venta venta) {
    if (venta.responsableNombre != null && venta.responsableNombre!.isNotEmpty && venta.responsableNombre != 'Sin asignar') {
      return venta.responsableNombre!;
    } else if (venta.usuario != null && venta.usuario!.nombreCompleto.isNotEmpty) {
      return venta.usuario!.nombreCompleto;
    } else if (venta.usuarioId != null && _nombresUsuarios.containsKey(venta.usuarioId)) {
      return _nombresUsuarios[venta.usuarioId!]!;
    }
    return 'N/A';
  }

  String _getBarberoName(Venta venta) {
    if (venta.barberoNombreStr != null && venta.barberoNombreStr!.isNotEmpty && venta.barberoNombreStr != 'Sin asignar') {
      return venta.barberoNombreStr!;
    } else if (venta.barbero != null && venta.barbero!.nombreCompleto.isNotEmpty) {
      return venta.barbero!.nombreCompleto;
    } else if (venta.barberoId != null && _nombresBarberos.containsKey(venta.barberoId)) {
      return _nombresBarberos[venta.barberoId!]!;
    }
    return 'Sin asignar';
  }

  Widget _buildCompraCard(Venta venta) {
    final bool isAnulada = venta.estado == false;
    final String responsable = _getResponsableName(venta);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isAnulada ? Colors.red.withOpacity(0.1) : const Color(0xFFD8B081).withOpacity(0.1),
          child: Icon(
            isAnulada ? Icons.close : Icons.shopping_bag,
            color: isAnulada ? Colors.red : const Color(0xFFD8B081),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Responsable: $responsable',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              AppFormat.cop(venta.total),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.confirmation_num_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Ticket #${venta.numero}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  venta.fechaRegistro?.split('T')[0] ?? 'Sin fecha',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _verDetallesCompra(venta),
      ),
    );
  }

  void _verDetallesCompra(Venta summary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VentaDetalleScreen(
          ventaSummary: summary,
          role: AppRole.client,
        ),
      ),
    );
  }
}
