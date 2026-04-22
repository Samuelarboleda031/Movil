import 'package:flutter/material.dart';
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
import 'package:parte_movil/data/datasources/dashboard_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
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
  
  String _getNombreMostrar(Venta venta, Map<int, Cliente> catalogoClientes) {
    if (venta.cliente != null && venta.cliente!.nombre.isNotEmpty) return venta.cliente!.nombreCompleto;
    final clienteEnCatalogo = catalogoClientes[venta.clienteId];
    if (clienteEnCatalogo != null) return clienteEnCatalogo.nombreCompleto;
    if (venta.clienteNombre != null && venta.clienteNombre!.isNotEmpty) return venta.clienteNombre!;
    return 'Cliente #ID:${venta.clienteId}';
  }

  List<Venta> _getVentasFiltradas(List<Venta> ventas, Map<int, Cliente> catalogoClientes) {
    if (_searchQuery.isEmpty) return ventas;
    final query = _searchQuery.toLowerCase();
    return ventas.where((venta) {
      final matchesNumero = venta.numero.toLowerCase().contains(query);
      final nombreMostrado = _getNombreMostrar(venta, catalogoClientes).toLowerCase();
      return matchesNumero || nombreMostrado.contains(query);
    }).toList();
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

          List<Widget>? appBarAcciones;
          if (widget.role == AppRole.barber) {
             appBarAcciones = [_MiniGananciaPill(
               role: widget.role,
               salesHash: ventas.hashCode,
             )];
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(widget.role == AppRole.barber ? 'Mis Ventas' : 'Panel de Ventas', style: const TextStyle(fontWeight: FontWeight.bold)),
              elevation: 0,
              actions: appBarAcciones,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar en la página...',
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
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
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                                itemCount: ventasFiltradas.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == ventasFiltradas.length) {
                                    if (paginacion != null && paginacion.totalPages > 1) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 20, bottom: 40),
                                        child: _buildPaginationControls(paginacion.totalPages, currentPage),
                                      );
                                    }
                                    return const SizedBox(height: 80);
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
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(
            icon: Icons.chevron_left,
            onTap: currentPage > 1 ? () => context.read<VentasBloc>().add(LoadVentasRequested(page: currentPage - 1)) : null,
          ),
          const SizedBox(width: 8),
          ..._buildPageNumbers(totalPages, currentPage),
          const SizedBox(width: 8),
          _buildPageButton(
            icon: Icons.chevron_right,
            onTap: currentPage < totalPages ? () => context.read<VentasBloc>().add(LoadVentasRequested(page: currentPage + 1)) : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages, int currentPage) {
    List<Widget> widgets = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 || i == totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
        widgets.add(_buildPageNumberButton(i, currentPage));
      } else if (i == currentPage - 2 || i == currentPage + 2) {
        widgets.add(const Text('...', style: TextStyle(color: Colors.grey)));
      }
    }
    return widgets;
  }

  Widget _buildPageNumberButton(int page, int currentPage) {
    bool isSelected = page == currentPage;
    return GestureDetector(
      onTap: isSelected ? null : () => context.read<VentasBloc>().add(LoadVentasRequested(page: page)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD8B081) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Icon(icon, color: onTap == null ? Colors.grey : Colors.white, size: 20),
      ),
    );
  }

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
    final String labelNumero = venta.numero.isNotEmpty ? '#${venta.numero}' : '#ID:${venta.id}';
    final String labelCliente = _getNombreMostrar(venta, catalogo);
    final String labelPrecio = AppFormat.cop(venta.total);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        onTap: () => _verDetallesVenta(venta, catalogo),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isAnulada ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          child: Icon(isAnulada ? Icons.close : Icons.shopping_bag, color: isAnulada ? Colors.red : Colors.green),
        ),
        title: Row(
          children: [
            Expanded(child: Text('Venta $labelNumero', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(labelPrecio, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD8B081))),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFFD8B081)),
              const SizedBox(width: 4),
              Expanded(child: Text(labelCliente, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(venta.fechaRegistro?.split('T')[0] ?? 'Sin fecha', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ],
        ),
      ),
    );
  }

  void _verDetallesVenta(Venta summary, Map<int, Cliente> catalogo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VentaDetalleScreen(
          ventaSummary: summary,
          role: widget.role,
          catalogoClientes: catalogo,
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
  final AuxiliarService _auxiliarService = AuxiliarService();
  
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
      final barberos = await _auxiliarService.obtenerBarberos();
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
    return GestureDetector(
      onTap: _mostrarSelectorPeriodo,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFD8B081).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFD8B081).withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MI GANANCIA (${_getNombrePeriodo()})', 
                  style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 2),
            if (_isLoading)
               const SizedBox(
                 height: 14, 
                 width: 14, 
                 child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD8B081))
               )
            else
               Text(
                 AppFormat.cop(_ganancia),
                 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD8B081)),
               ),
          ],
        ),
      ),
    );
  }
}
