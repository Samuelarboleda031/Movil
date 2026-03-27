import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../services/venta_service.dart';
import '../services/auxiliar_service.dart';
import '../models/cliente.dart';
import '../models/barbero.dart';
import '../models/producto.dart';
import '../models/servicio.dart';
import '../models/paquete.dart';
import 'venta_form_screen.dart';

import '../models/app_role.dart';
import '../widgets/session_guard.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final VentaService _ventaService = VentaService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  List<Venta> _ventas = [];
  Map<int, String> _nombresClientes = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ventas = await _ventaService.obtenerVentas();
      
      // Cargar clientes para mapear nombres si faltan en la venta
      try {
        final clientes = await _auxiliarService.obtenerClientes();
        _nombresClientes = {for (var c in clientes) c.id!: c.nombreCompleto};
      } catch (e) {
        print('Error cargando clientes auxiliares: $e');
      }

      setState(() {
        _ventas = ventas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ventas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Venta> get _ventasFiltradas {
    if (_searchQuery.isEmpty) {
      return _ventas;
    }
    return _ventas.where((venta) {
      final numero = venta.numero.toLowerCase();
      final cliente = venta.cliente?.nombreCompleto.toLowerCase() ?? '';
      return numero.contains(_searchQuery.toLowerCase()) ||
          cliente.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _verDetallesVenta(Venta ventaResumen) async {
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var venta = await _ventaService.obtenerVentaPorId(ventaResumen.id!);
      
      // Resolve names
      String clienteNombre = venta.cliente?.nombreCompleto ?? 'N/A';
      String barberoNombre = venta.barbero?.nombreCompleto ?? 'N/A';
      
      List<Producto> productos = [];
      List<Servicio> servicios = [];
      List<Paquete> paquetes = [];

      // Fetch items for details
      try {
        final detalles = await _ventaService.obtenerDetallesVenta(venta.id!);
        // Create a new Venta object with the fetched details (since Venta fields are final)
        // Or just use the local list for display. Let's use a local list.
        if (detalles.isNotEmpty) {
           // We need to update the 'venta' object or just use 'detalles' in the UI.
           // Since 'venta' is used in the UI, let's create a new Venta with these details.
           // However, Venta is immutable. Let's just use a local variable for the dialog.
           // Actually, the dialog uses 'venta.detalles'.
           // Let's re-instantiate 'venta' with the new details.
           venta = Venta(
             id: venta.id,
             numero: venta.numero,
             fechaRegistro: venta.fechaRegistro,
             clienteId: venta.clienteId,
             barberoId: venta.barberoId,
             metodoPago: venta.metodoPago,
             subtotal: venta.subtotal,
             porcentajeDescuento: venta.porcentajeDescuento,
             total: venta.total,
             estado: venta.estado,
             cliente: venta.cliente,
             barbero: venta.barbero,
             detalles: detalles,
           );
           
           productos = await _auxiliarService.obtenerProductos();
           servicios = await _auxiliarService.obtenerServicios();
           paquetes = await _auxiliarService.obtenerPaquetes();
        }
      } catch (e) {
        print('Error recuperando detalles de venta: $e');
      }

      // Fetch auxiliary data if needed
      if (venta.cliente == null || venta.barbero == null) {
        try {
          if (venta.cliente == null) {
            final clientes = await _auxiliarService.obtenerClientes();
            final cliente = clientes.firstWhere(
              (c) => c.id == venta.clienteId,
              orElse: () => Cliente(id: 0, documento: '', nombre: 'Desconocido', apellido: '', telefono: '', email: '', direccion: '', estado: true)
            );
            clienteNombre = cliente.nombreCompleto;
          }
          
          if (venta.barbero == null) {
            final barberos = await _auxiliarService.obtenerBarberos();
            final barbero = barberos.firstWhere(
              (b) => b.id == venta.barberoId,
              orElse: () => Barbero(id: 0, documento: '', nombre: 'Desconocido', apellido: '', telefono: '', email: '', direccion: '', estado: true)
            );
            barberoNombre = barbero.nombreCompleto;
          }
        } catch (e) {
          print('Error recuperando datos auxiliares: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Detalles Venta #${venta.numero}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Cliente:', clienteNombre),
                _buildDetailRow('Barbero:', barberoNombre),
                _buildDetailRow('Fecha:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(venta.fechaRegistro ?? DateTime.now().toIso8601String()))),
                _buildDetailRow('Método Pago:', venta.metodoPago),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (venta.detalles != null && venta.detalles!.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200), // Limit height for many items
                    child: SingleChildScrollView(
                      child: Column(
                        children: venta.detalles!.map((d) {
                          String nombreItem = 'Item desconocido';
                          String tipoItem = 'Desconocido';
                          String idInfo = '';
                          
                          if (d.productoId != null) {
                            tipoItem = 'Producto';
                            idInfo = '(ID: ${d.productoId})';
                            final producto = productos.firstWhere(
                              (p) => p.id == d.productoId,
                              orElse: () => Producto(id: 0, nombre: 'Producto no encontrado', descripcion: '', categoriaId: 0, proveedorId: 0, precioCompra: 0, precioVenta: 0, stock: 0, stockMinimo: 0, estado: true)
                            );
                            nombreItem = producto.nombre;
                          } else if (d.servicioId != null) {
                            tipoItem = 'Servicio';
                            idInfo = '(ID: ${d.servicioId})';
                            final servicio = servicios.firstWhere(
                              (s) => s.id == d.servicioId,
                              orElse: () => Servicio(id: 0, nombre: 'Servicio no encontrado', descripcion: '', precio: 0, duracionMinutos: 0, estado: true)
                            );
                            nombreItem = servicio.nombre;
                          } else if (d.paqueteId != null) {
                            tipoItem = 'Paquete';
                            idInfo = '(ID: ${d.paqueteId})';
                            final paquete = paquetes.firstWhere(
                              (p) => p.id == d.paqueteId,
                              orElse: () => Paquete(id: 0, nombre: 'Paquete no encontrado', descripcion: '', precio: 0, duracionMinutos: 0, estado: true)
                            );
                            nombreItem = paquete.nombre;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            color: Theme.of(context).cardTheme.color,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade800),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tipoItem,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          nombreItem,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${d.cantidad} x \$${d.precioUnitario.toStringAsFixed(2)}',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      ),
                                      Text(
                                        '\$${(d.subTotal ?? (d.cantidad * d.precioUnitario)).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (nombreItem.contains('no encontrado') || nombreItem.contains('desconocido'))
                                    Text(
                                      idInfo,
                                      style: const TextStyle(fontSize: 10, color: Colors.red),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                else
                  const Text('No hay detalles registrados.'),
                const Divider(),
                _buildDetailRow('Subtotal:', '\$${venta.subtotal.toStringAsFixed(2)}'),
                _buildDetailRow('Descuento:', '${venta.porcentajeDescuento}%'),
                _buildDetailRow('Total:', '\$${venta.total.toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar detalles: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    if (estado == null || estado.toLowerCase() == 'activa' || estado.toLowerCase() == 'completada' || estado.toLowerCase() == 'pagada') {
      return Colors.green;
    } else if (estado.toLowerCase() == 'anulada' || estado.toLowerCase() == 'cancelada') {
      return Colors.red;
    } else {
      return Colors.orange; // Otros estados (Pendiente, etc)
    }
  }

  Future<void> _eliminarVenta(Venta venta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular Venta'),
        content: Text('¿Está seguro que desea anular la venta ${venta.numero}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _ventaService.eliminarVenta(venta.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Venta eliminada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarVentas();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar venta: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(title: const Text('MANITO BARBERSHOP')),
        body: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por número o cliente...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            // Lista de ventas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ventasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No hay ventas registradas'
                                    : 'No se encontraron ventas',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargarVentas,
                          child: ListView.builder(
                            itemCount: _ventasFiltradas.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final venta = _ventasFiltradas[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            final nombreCliente = venta.cliente?.nombreCompleto ?? 
                                                                _nombresClientes[venta.clienteId];
                                            
                                            return Text(
                                              nombreCliente != null
                                                  ? 'Venta hecha a $nombreCliente'
                                                  : 'Venta #${venta.numero}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            );
                                          }
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getEstadoColor(venta.estado).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getEstadoColor(venta.estado),
                                          ),
                                        ),
                                        child: Text(
                                          venta.estado ?? 'Activa',
                                          style: TextStyle(
                                            color: _getEstadoColor(venta.estado),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      if (venta.barbero != null)
                                        Text(
                                          'Barbero: ${venta.barbero!.nombreCompleto}',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      if (venta.fechaRegistro != null)
                                        Text(
                                          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(venta.fechaRegistro!))}',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Total: \$${venta.total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Or Theme.of(context).primaryColor
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility, size: 20, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Ver Detalles'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.cancel, size: 20, color: Colors.orange),
                                            SizedBox(width: 8),
                                            Text('Anular', style: TextStyle(color: Colors.orange)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'details') {
                                        _verDetallesVenta(venta);
                                      } else if (value == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => VentaFormScreen(venta: venta),
                                          ),
                                        ).then((_) => _cargarVentas());
                                      } else if (value == 'delete') {
                                        _eliminarVenta(venta);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VentaFormScreen(),
              ),
            ).then((_) => _cargarVentas());
          },
          backgroundColor: const Color(0xFFD8B081),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

