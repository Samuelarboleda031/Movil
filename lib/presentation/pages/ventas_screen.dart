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
import 'venta_form_screen.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
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
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
        ),
        body: BlocConsumer<VentasBloc, VentasState>(
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

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar en la página...',
                      prefixIcon: const Icon(Icons.search),
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
            );
          },
        ),
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
        trailing: PopupMenuButton(
          onSelected: (val) {
            if (val == 'details') _verDetallesVenta(venta, catalogo);
            if (val == 'edit') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => VentaFormScreen(venta: venta))).then((_) {
                 context.read<VentasBloc>().add(const LoadVentasRequested(page: 1));
              });
            }
            if (val == 'delete') _eliminarVenta(venta);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Row(children: [Icon(Icons.visibility), SizedBox(width: 8), Text('Detalles')])),
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Editar')])),
            if (!isAnulada)
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 8), Text('Anular', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  Future<void> _verDetallesVenta(Venta summary, Map<int, Cliente> catalogo) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final full = await VentaService().obtenerVentaPorId(summary.id!);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Venta #${full.numero}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Cliente:', _getNombreMostrar(full, catalogo)),
                _detailRow('Responsable:', full.usuario?.nombreCompleto ?? full.barbero?.nombreCompleto ?? 'N/A'),
                _detailRow('Fecha:', full.fechaRegistro ?? 'N/A'),
                _detailRow('Pago:', full.metodoPago),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(full.detalles ?? []).map((d) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• ${d.cantidad} x ${AppFormat.cop(d.precioUnitario)}'),
                )),
                const Divider(),
                _detailRow('Total:', AppFormat.cop(full.total), isBold: true),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      AppToast.showError(context, 'Error: $e');
    }
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
      ]),
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
