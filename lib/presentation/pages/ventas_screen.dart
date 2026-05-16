import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_bloc.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_event.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_state.dart';
import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/presentation/pages/venta_detalle_screen.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/presentation/widgets/dashboard_ganancias_widget.dart';
import 'package:parte_movil/presentation/widgets/ellipsis_pagination.dart';
import 'package:parte_movil/presentation/widgets/cita_notification_bell.dart';
import 'package:parte_movil/data/datasources/dashboard_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';

class VentasScreen extends StatefulWidget {
  final AppRole role;
  
  const VentasScreen({super.key, this.role = AppRole.admin});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filtroEstado = 'Todas';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _periodoActivo = '';
  bool _filtroFechaActivo = false;

  String _getNombreMostrar(Venta venta, Map<int, Cliente> catalogoClientes) {
    if (venta.cliente != null && venta.cliente!.nombre.isNotEmpty) return venta.cliente!.nombreCompleto;
    final clienteEnCatalogo = catalogoClientes[venta.clienteId];
    if (clienteEnCatalogo != null) return clienteEnCatalogo.nombreCompleto;
    if (venta.clienteNombre != null && venta.clienteNombre!.isNotEmpty) return venta.clienteNombre!;
    return 'Cliente #ID:${venta.clienteId}';
  }

  List<Venta> _getVentasFiltradas(List<Venta> ventas, Map<int, Cliente> catalogoClientes) {
    var resultado = ventas;

    if (_filtroEstado != 'Todas') {
      resultado = resultado.where((v) {
        final estado = (v.estado ?? '').toLowerCase();
        return estado == _filtroEstado.toLowerCase();
      }).toList();
    }

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
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      resultado = resultado.where((venta) {
        final matchesNumero = venta.numero.toLowerCase().contains(query);
        final nombreMostrado = _getNombreMostrar(venta, catalogoClientes).toLowerCase();
        return matchesNumero || nombreMostrado.contains(query);
      }).toList();
    }

    return resultado;
  }

  bool get _hayFiltrosActivos => _filtroEstado != 'Todas' || _filtroFechaActivo || _searchQuery.isNotEmpty;

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filtroEstado = 'Todas';
      _fechaDesde = null;
      _fechaHasta = null;
      _filtroFechaActivo = false;
      _periodoActivo = '';
    });
  }

  Future<void> _seleccionarRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _fechaDesde != null && _fechaHasta != null
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.card, onSurface: AppColors.white),
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
      });
    }
  }

  void _setFechaRapida(String periodo) {
    final hoy = DateTime.now();
    setState(() {
      _periodoActivo = periodo;
      _filtroFechaActivo = true;
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
          color: sel ? AppColors.gold.withOpacity(0.2) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.gold : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(color: sel ? AppColors.gold : AppColors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFiltrosVentas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // 1. Filtros de Fecha (Botones rápidos + Rango)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _periodoActivo = '';
                    _seleccionarRangoFechas();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _filtroFechaActivo && _periodoActivo.isEmpty
                          ? AppColors.gold.withOpacity(0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _filtroFechaActivo && _periodoActivo.isEmpty ? AppColors.gold : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16,
                          color: _filtroFechaActivo ? AppColors.gold : AppColors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _filtroFechaActivo && _fechaDesde != null && _fechaHasta != null
                                ? '${_fechaDesde!.day}/${_fechaDesde!.month} - ${_fechaHasta!.day}/${_fechaHasta!.month}'
                                : 'Filtrar por fecha',
                            style: TextStyle(
                              color: _filtroFechaActivo ? AppColors.gold : AppColors.grey,
                              fontSize: 12,
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
                            child: const Icon(Icons.close, size: 16, color: AppColors.gold),
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
          const SizedBox(height: 10),
          // 2. Filtros de Estado
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todas', 'Completada', 'Anulada'].map((estado) {
                      final selected = _filtroEstado == estado;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(estado, style: TextStyle(color: selected ? AppColors.bg : AppColors.greyLight, fontSize: 12, fontWeight: FontWeight.w600)),
                          selected: selected,
                          onSelected: (_) => setState(() => _filtroEstado = estado),
                          selectedColor: AppColors.gold,
                          backgroundColor: AppColors.card,
                          side: BorderSide(color: selected ? AppColors.gold : AppColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          showCheckmark: false,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_hayFiltrosActivos) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _limpiarFiltros,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_off, size: 14, color: AppColors.gold),
                        SizedBox(width: 4),
                        Text('Limpiar', style: TextStyle(fontSize: 12, color: AppColors.gold)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
      child: BlocConsumer<VentasBloc, VentasState>(
        listener: (context, state) {
          if (state is VentasError) {
            AppToast.showError(context, state.message);
          } else if (state is VentasActionSuccess) {
            AppToast.showSuccess(context, state.message);
          }
        },
        builder: (context, state) {
          bool isLoading = state is VentasInitial || state is VentasLoading;
          List<Venta> ventas = [];
          Map<int, Cliente> catalogo = {};
          Paginacion<Venta>? paginacion;
          int currentPage = 1;

          if (state is VentasLoaded) {
            ventas = state.ventas;
            catalogo = state.catalogoClientes;
            paginacion = state.paginacion;
            currentPage = state.currentPage;
          }

          final ventasFiltradas = _getVentasFiltradas(ventas, catalogo);

          // ── Barbero: diseño oscuro premium ──
          if (widget.role == AppRole.barber) {
            return Scaffold(
              backgroundColor: AppColors.bg,
              body: SafeArea(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                    : RefreshIndicator(
                        onRefresh: () async {
                          context.read<VentasBloc>().add(const LoadVentasRequested(page: 1));
                        },
                        color: AppColors.gold,
                        backgroundColor: AppColors.card,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Header
                            SliverToBoxAdapter(child: _buildVentasHeader()),
                            // Banner de ganancia
                            SliverToBoxAdapter(
                              child: _MiniGananciaPill(role: widget.role, salesHash: ventas.hashCode),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 8)),
                            // Buscador
                            SliverToBoxAdapter(child: _buildVentasBuscador()),
                            // Lista
                            ventasFiltradas.isEmpty
                                  ? SliverToBoxAdapter(child: _buildEmptyStateDark())
                                  : SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildVentaCard(ventasFiltradas[index], catalogo),
                                        childCount: ventasFiltradas.length,
                                      ),
                                    ),
                            // Paginación
                            if (paginacion != null && paginacion.totalPages > 1)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: _buildPaginationControls(paginacion.totalPages, currentPage),
                                ),
                              ),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                      ),
              ),
            );
          }

          // ── Admin/Manager: diseño original ──
          return Scaffold(
            appBar: AppBar(
              title: const Text('Panel de Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.bg,
              elevation: 0,
              actions: [CitaNotificationBell(role: widget.role)],
            ),
            backgroundColor: AppColors.bg,
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar venta o cliente...',
                      hintStyle: const TextStyle(color: AppColors.grey),
                      prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                      filled: true,
                      fillColor: AppColors.card,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20, color: AppColors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                _buildFiltrosVentas(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ventasFiltradas.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () async {
                                context.read<VentasBloc>().add(const LoadVentasRequested(page: 1));
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                itemCount: ventasFiltradas.length + ((paginacion != null && paginacion.totalPages > 1) ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == ventasFiltradas.length) {
                                    return _buildPaginationControls(paginacion!.totalPages, currentPage);
                                  }
                                  return _buildVentaCard(ventasFiltradas[index], catalogo);
                                },
                              ),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages, int currentPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EllipsisPagination(
        totalPages: totalPages,
        currentPage: currentPage,
        onPageChanged: (page) {
          context.read<VentasBloc>().add(LoadVentasRequested(page: page));
        },
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════
  // DISEÑO OSCURO PREMIUM PARA BARBERO (mismo estilo que Citas)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildVentasHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mis Ventas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Resumen de tu actividad',
                style: TextStyle(fontSize: 14, color: AppColors.grey),
              ),
            ],
          ),
          CitaNotificationBell(role: widget.role),
        ],
      ),
    );
  }

  Widget _buildVentasBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: AppColors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Buscar venta o cliente...',
                  hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20, color: AppColors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.red.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.red, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyStateDark() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.gold.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No hay ventas que coincidan con tu búsqueda'
                : 'No tienes ventas registradas',
            style: const TextStyle(color: AppColors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DISEÑO ADMIN/MANAGER (original)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          const Text('No hay ventas en esta página', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildVentaCard(Venta venta, Map<int, Cliente> catalogo) {
    final bool isAnulada = venta.estado?.toLowerCase() == 'anulada';
    final String labelNumero = venta.numero.isNotEmpty ? '#${venta.numero}' : '#${venta.id}';
    final String labelCliente = _getNombreMostrar(venta, catalogo);
    final String labelPrecio = AppFormat.cop(venta.total);
    final String fechaStr = (venta.fechaRegistro?.contains('T') ?? false) 
        ? venta.fechaRegistro!.split('T')[0] 
        : (venta.fechaRegistro ?? '');

    return GestureDetector(
      onTap: () => _verDetallesVenta(venta, catalogo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isAnulada ? AppColors.red.withOpacity(0.3) : AppColors.divider.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isAnulada ? AppColors.red.withOpacity(0.12) : AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAnulada ? Icons.close : Icons.shopping_bag_outlined,
                color: isAnulada ? AppColors.red : AppColors.gold,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(labelNumero, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      if (isAnulada) _buildStatusBadge('ANULADA'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(labelCliente, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(fechaStr, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(labelPrecio, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: AppColors.gold, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _verDetallesVenta(Venta summary, Map<int, Cliente> catalogo) {
    final ventasBloc = context.read<VentasBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: ventasBloc,
          child: VentaDetalleScreen(
            ventaSummary: summary,
            role: widget.role,
            catalogoClientes: catalogo,
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarVenta(Venta v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Anulación'),
        content: Text('¿Desea anular la venta #${v.numero}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Anular', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      context.read<VentasBloc>().add(DeleteVentaRequested(v.id!));
    }
  }
}

class _MiniGananciaPill extends StatefulWidget {
  final AppRole role;
  final int salesHash;
  const _MiniGananciaPill({Key? key, required this.role, required this.salesHash}) : super(key: key);
  @override
  State<_MiniGananciaPill> createState() => _MiniGananciaPillState();
}

class _MiniGananciaPillState extends State<_MiniGananciaPill> {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();
  final BarberoService _barberoService = BarberoService();
  
  bool _isLoading = true;
  double _ganancia = 0;
  String _filtroPeriodo = 'mensual';
  String _barberoNombreBusqueda = 'Todos';
  
  // Nombres bonitos para el UI
  String _getNombrePeriodo() {
    switch (_filtroPeriodo) {
      case 'hoy': return 'Hoy';
      case 'semanal': return 'Semanal';
      case 'mensual': return 'Mensual';
      case 'anual': return 'Anual';
      default: return 'Mensual';
    }
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  @override
  void didUpdateWidget(covariant _MiniGananciaPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la lista de ventas cambió por fuera (agregaron o anularon una venta), recargar esto.
    if (oldWidget.salesHash != widget.salesHash) {
      _cargarGanancia(silent: true);
    }
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
            orElse: () => throw Exception('Perfil no encontrado'),
        );
        _barberoNombreBusqueda = barberoLocal.nombre;
      }
      await _cargarGanancia();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _actualizarPeriodo(String periodo) {
    if (periodo == _filtroPeriodo) return;
    setState(() => _filtroPeriodo = periodo);
    _cargarGanancia(silent: false);
  }

  Future<void> _cargarGanancia({bool silent = true}) async {
    setState(() => _isLoading = true);
    try {
      final data = await _dashboardService.obtenerGanancias(_filtroPeriodo, _barberoNombreBusqueda);
      if (mounted) {
        setState(() {
          _ganancia = double.tryParse(data['gananciasBarberos']?.toString() ?? '0') ?? 0;
          _isLoading = false;
        });
        if (!silent) {
           AppToast.showSuccess(context, 'Métricas actualizadas para $_filtroPeriodo');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'No se pudo cargar: $e');
      }
    }
  }

  void _mostrarSelectorPeriodo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Seleccione Periodo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.today), 
                title: const Text('Hoy'), 
                trailing: _filtroPeriodo == 'hoy' ? const Icon(Icons.check, color: Color(0xFFD8B081)) : null,
                onTap: () { Navigator.pop(ctx); _actualizarPeriodo('hoy'); }
              ),
              ListTile(
                leading: const Icon(Icons.view_week), 
                title: const Text('Semanal'), 
                trailing: _filtroPeriodo == 'semanal' ? const Icon(Icons.check, color: Color(0xFFD8B081)) : null,
                onTap: () { Navigator.pop(ctx); _actualizarPeriodo('semanal'); }
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month), 
                title: const Text('Mensual'), 
                trailing: _filtroPeriodo == 'mensual' ? const Icon(Icons.check, color: Color(0xFFD8B081)) : null,
                onTap: () { Navigator.pop(ctx); _actualizarPeriodo('mensual'); }
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today), 
                title: const Text('Anual'), 
                trailing: _filtroPeriodo == 'anual' ? const Icon(Icons.check, color: Color(0xFFD8B081)) : null,
                onTap: () { Navigator.pop(ctx); _actualizarPeriodo('anual'); }
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: _mostrarSelectorPeriodo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD8B081).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF1A1A2E),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MI GANANCIA (${_getNombrePeriodo()})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A1A2E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: const Color(0xFF1A1A2E).withOpacity(0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_isLoading)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1A2E),
                        ),
                      )
                    else
                      Text(
                        AppFormat.cop(_ganancia),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
