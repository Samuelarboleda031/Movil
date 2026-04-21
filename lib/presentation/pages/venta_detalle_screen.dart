import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_bloc.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_event.dart';
import 'package:parte_movil/presentation/pages/venta_form_screen.dart';

class VentaDetalleScreen extends StatefulWidget {
  final Venta ventaSummary;
  final AppRole role;
  final Map<int, Cliente>? catalogoClientes;

  const VentaDetalleScreen({
    Key? key,
    required this.ventaSummary,
    required this.role,
    this.catalogoClientes,
  }) : super(key: key);

  @override
  State<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends State<VentaDetalleScreen> {
  final VentaService _ventaService = VentaService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  
  bool _isLoading = true;
  Venta? _ventaCompleta;
  List<Producto> _productos = [];
  List<Servicio> _servicios = [];
  List<Paquete> _paquetes = [];

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    try {
      final results = await Future.wait([
        _ventaService.obtenerVentaPorId(widget.ventaSummary.id!),
        _auxiliarService.obtenerProductos(),
        _auxiliarService.obtenerServicios(),
        _auxiliarService.obtenerPaquetes(),
      ]);

      if (mounted) {
        setState(() {
          _ventaCompleta = results[0] as Venta;
          _productos = results[1] as List<Producto>;
          _servicios = results[2] as List<Servicio>;
          _paquetes = results[3] as List<Paquete>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar detalles: $e')));
      }
    }
  }

  String _getNombreMostrar(Venta v) {
    if (v.clienteNombre != null && v.clienteNombre!.isNotEmpty && v.clienteNombre != 'Cliente invitado') {
      return v.clienteNombre!;
    }
    if (v.cliente != null) return v.cliente!.nombreCompleto;
    if (widget.catalogoClientes != null && widget.catalogoClientes!.containsKey(v.clienteId)) {
      return widget.catalogoClientes![v.clienteId]!.nombreCompleto;
    }
    return 'Cliente Genérico';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        title: const Text('Detalles de la Venta'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      resizeToAvoidBottomInset: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8B081)))
          : _ventaCompleta == null
              ? const Center(child: Text('No se pudieron cargar los detalles'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(_ventaCompleta!),
                            const SizedBox(height: 24),

                            _buildInfoGrid(_ventaCompleta!),
                            const SizedBox(height: 24),

                            _buildStatusBadge(_ventaCompleta!),
                            const SizedBox(height: 24),
                            
                            const Text('Items Comprados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            _buildItemsList(_ventaCompleta!),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.grey),
                            const SizedBox(height: 16),

                            _buildPaymentSummary(_ventaCompleta!),
                          ],
                        ),
                      ),
                    ),
                    _buildActionButtonsBar(context, _ventaCompleta!),
                  ],
                ),
    );
  }

  Widget _buildHeader(Venta venta) {
    final String labelNumero = venta.numero.isNotEmpty ? '#${venta.numero}' : '#ID:${venta.id}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Venta $labelNumero',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          AppFormat.cop(venta.total),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFD8B081),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(Venta venta) {
    final String labelCliente = _getNombreMostrar(venta);
    final String responsableMostrar = venta.responsableNombre ?? venta.usuario?.nombreCompleto ?? 'N/A';
    final String barberoMostrar = venta.barberoNombreStr ?? venta.barbero?.nombreCompleto ?? 'Sin asignar';
    final String fecha = venta.fechaRegistro?.split('T')[0] ?? 'N/A';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildInfoCard('Cliente', labelCliente),
        _buildInfoCard('Fecha', fecha),
        _buildInfoCard('Responsable', responsableMostrar),
        if (barberoMostrar != 'Sin asignar' && barberoMostrar.isNotEmpty) ...[
           _buildInfoCard('Barbero', barberoMostrar),
        ]
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Venta venta) {
    final isAnulada = venta.estado?.toLowerCase() == 'anulada';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isAnulada ? Colors.red[900] : const Color(0xFFD8B081).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isAnulada ? Colors.red : const Color(0xFFD8B081), width: 0.5)
          ),
          child: Text(
            isAnulada ? 'Estado: Anulada' : 'Pago: ${venta.metodoPago}',
            style: TextStyle(
              fontSize: 13,
              color: isAnulada ? Colors.red[100] : const Color(0xFFD8B081),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(Venta venta) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: venta.detalles?.length ?? 0,
      itemBuilder: (context, index) {
        final d = venta.detalles![index];
        String itemName = 'Item Desconocido';
        String? itemImage;
        IconData defaultIcon = Icons.shopping_bag_outlined;

        if (d.productoId != null) {
          try {
            final prod = _productos.firstWhere((p) => p.id == d.productoId);
            itemName = prod.nombre;
            itemImage = prod.imagenProduc;
            defaultIcon = Icons.inventory_2_outlined;
          } catch (_) {}
        } else if (d.servicioId != null) {
          try {
            final serv = _servicios.firstWhere((s) => s.id == d.servicioId);
            itemName = serv.nombre;
            itemImage = serv.imagen;
            defaultIcon = Icons.cut_outlined;
          } catch (_) {}
        } else if (d.paqueteId != null) {
          try {
            final paq = _paquetes.firstWhere((p) => p.id == d.paqueteId);
            itemName = paq.nombre;
            defaultIcon = Icons.card_giftcard_outlined;
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[850]!, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: itemImage != null && itemImage.isNotEmpty
                ? Image.network(
                    itemImage.startsWith('http') ? itemImage : '${ApiConfig.baseUrl}$itemImage',
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 45, height: 45, color: Colors.grey[800],
                      child: Icon(defaultIcon, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 45, height: 45, color: Colors.grey[800],
                    child: Icon(defaultIcon, color: Colors.grey),
                  ),
            ),
            title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${d.cantidad} x ${AppFormat.cop(d.precioUnitario)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            trailing: Text(AppFormat.cop(d.cantidad * d.precioUnitario), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          ),
        );
      },
    );
  }

  Widget _buildPaymentSummary(Venta venta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen Financiero',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal', style: TextStyle(color: Colors.white70)),
            Text(AppFormat.cop(venta.subtotal), style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Descuento', style: TextStyle(color: Colors.white70)),
            Text('- ${AppFormat.cop(venta.porcentajeDescuento)}', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.greenAccent)),
          ],
        ),
        const Divider(height: 32, thickness: 0.5, color: Colors.grey),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            Text(
              AppFormat.cop(venta.total),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD8B081),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtonsBar(BuildContext context, Venta venta) {
    final bool isAnulada = venta.estado?.toLowerCase() == 'anulada';
    final bool isClient = widget.role == AppRole.client;

    if (isClient) {
      // Cliente no puede validar, solo salir.
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        border: Border(
          top: BorderSide(color: Colors.grey[850]!, width: 1.0),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // Administrador o Barbero
          if (!isAnulada && widget.role == AppRole.admin) ...[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showDeleteDialog(context, venta),
                child: const Text(
                  'Anular',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          if (widget.role == AppRole.admin) ...[
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B081),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VentaFormScreen(venta: venta))).then((_) {
                    context.read<VentasBloc>().add(const LoadVentasRequested(page: 1));
                  });
                },
                child: const Text(
                  'Editar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B081),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Venta venta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('¿Anular venta?'),
        content: const Text('Esta acción no se puede deshacer y el estado pasará a Anulada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // popup
              Navigator.pop(this.context); // detalle view
              context.read<VentasBloc>().add(DeleteVentaRequested(venta.id!));
            },
            child: const Text('Confirmar Anulación', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
