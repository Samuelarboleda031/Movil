import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/venta.dart';
import '../models/barbero.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/servicio.dart';
import '../models/paquete.dart';
import '../services/venta_service.dart';
import '../services/auxiliar_service.dart';
import '../services/auth_service.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';

class BarberVentasScreen extends StatefulWidget {
  const BarberVentasScreen({super.key});

  @override
  State<BarberVentasScreen> createState() => _BarberVentasScreenState();
}

class _BarberVentasScreenState extends State<BarberVentasScreen> {
  final VentaService _ventaService = VentaService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final AuthService _authService = AuthService();

  List<Venta> _ventas = [];
  Map<int, String> _nombresClientes = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarVentasBarbero();
  }

  Future<void> _cargarVentasBarbero() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No se pudo identificar al usuario actual como barbero.');
      }

      // Cargar clientes para mapear nombres si faltan en la venta
      try {
        final clientes = await _auxiliarService.obtenerClientes();
        _nombresClientes = {for (var c in clientes) c.id!: c.nombreCompleto};
      } catch (e) {
        print('Error cargando clientes auxiliares: $e');
      }

      final barberos = await _auxiliarService.obtenerBarberos();
      final barbero = barberos.firstWhere(
        (b) => (b.email ?? '').toLowerCase() == user.email!.toLowerCase(),
        orElse: () => Barbero(
          id: 0,
          documento: '',
          nombre: 'Barbero',
          apellido: 'Desconocido',
          telefono: '',
          email: user.email,
          direccion: '',
          estado: true,
        ),
      );

      final todas = await _ventaService.obtenerVentas();

      final propias = todas.where((v) {
        final coincideId = barbero.id != null && barbero.id != 0 && v.barberoId == barbero.id;
        final coincideEmail = v.barbero?.email != null &&
            barbero.email != null &&
            v.barbero!.email!.toLowerCase() == barbero.email!.toLowerCase();
        return coincideId || coincideEmail;
      }).toList();

      setState(() {
        _ventas = propias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar tus ventas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Venta> get _ventasFiltradas {
    final base = _ventas;
    if (_searchQuery.isEmpty) return base;
    return base.where((venta) {
      final numero = venta.numero.toLowerCase();
      final cliente = venta.cliente?.nombreCompleto.toLowerCase() ?? '';
      return numero.contains(_searchQuery.toLowerCase()) ||
          cliente.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  double get _totalIngresos {
    // Solo consideramos ventas activas (estado != false)
    return _ventasFiltradas
        .where((v) => v.estado != false)
        .fold(0.0, (sum, v) => sum + v.total);
  }

  double get _gananciaBarbero => _totalIngresos * 0.6;
  double get _gananciaBarberia => _totalIngresos * 0.4;

  Widget _buildIndicador(String label, double valor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          Text(
            '\$${valor.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verDetallesVenta(Venta ventaResumen) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var venta = await _ventaService.obtenerVentaPorId(ventaResumen.id!);

      String clienteNombre = venta.cliente?.nombreCompleto ?? 'N/A';
      String barberoNombre = venta.barbero?.nombreCompleto ?? 'N/A';

      List<Producto> productos = [];
      List<Servicio> servicios = [];
      List<Paquete> paquetes = [];

      try {
        final detalles = await _ventaService.obtenerDetallesVenta(venta.id!);
        if (detalles.isNotEmpty) {
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
        // Ignorar, pero registrar
        // ignore: avoid_print
        print('Error recuperando detalles de venta (barbero): $e');
      }

      if (venta.cliente == null || venta.barbero == null) {
        try {
          if (venta.cliente == null) {
            final clientes = await _auxiliarService.obtenerClientes();
            final cliente = clientes.firstWhere(
              (c) => c.id == venta.clienteId,
              orElse: () => Cliente(
                id: 0,
                documento: '',
                nombre: 'Desconocido',
                apellido: '',
                telefono: '',
                email: '',
                direccion: '',
                estado: true,
              ),
            );
            clienteNombre = cliente.nombreCompleto;
          }

          if (venta.barbero == null) {
            final barberos = await _auxiliarService.obtenerBarberos();
            final barbero = barberos.firstWhere(
              (b) => b.id == venta.barberoId,
              orElse: () => Barbero(
                id: 0,
                documento: '',
                nombre: 'Desconocido',
                apellido: '',
                telefono: '',
                email: '',
                direccion: '',
                estado: true,
              ),
            );
            barberoNombre = barbero.nombreCompleto;
          }
        } catch (e) {
          // ignore: avoid_print
          print('Error recuperando datos auxiliares (barbero): $e');
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
                _buildDetailRow(
                  'Fecha:',
                  DateFormat('dd/MM/yyyy HH:mm').format(
                    DateTime.parse(
                      venta.fechaRegistro ?? DateTime.now().toIso8601String(),
                    ),
                  ),
                ),
                _buildDetailRow('Método Pago:', venta.metodoPago),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (venta.detalles != null && venta.detalles!.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
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
                              orElse: () => Producto(
                                id: 0,
                                nombre: 'Producto no encontrado',
                                descripcion: '',
                                categoriaId: 0,
                                proveedorId: 0,
                                precioCompra: 0,
                                precioVenta: 0,
                                stock: 0,
                                stockMinimo: 0,
                                estado: true,
                              ),
                            );
                            nombreItem = producto.nombre;
                          } else if (d.servicioId != null) {
                            tipoItem = 'Servicio';
                            idInfo = '(ID: ${d.servicioId})';
                            final servicio = servicios.firstWhere(
                              (s) => s.id == d.servicioId,
                              orElse: () => Servicio(
                                id: 0,
                                nombre: 'Servicio no encontrado',
                                descripcion: '',
                                precio: 0,
                                duracionMinutos: 0,
                                estado: true,
                              ),
                            );
                            nombreItem = servicio.nombre;
                          } else if (d.paqueteId != null) {
                            tipoItem = 'Paquete';
                            idInfo = '(ID: ${d.paqueteId})';
                            final paquete = paquetes.firstWhere(
                              (p) => p.id == d.paqueteId,
                              orElse: () => Paquete(
                                id: 0,
                                nombre: 'Paquete no encontrado',
                                descripcion: '',
                                precio: 0,
                                duracionMinutos: 0,
                                estado: true,
                              ),
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
                                  if (nombreItem.contains('no encontrado') ||
                                      nombreItem.contains('desconocido'))
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar detalles: $e'),
          backgroundColor: Colors.red,
        ),
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
          Text(
            value,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
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
      return Colors.orange; // Otros estados
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.barber,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Ventas'),
          actions: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  _buildIndicador('Ingresos', _totalIngresos),
                  _buildIndicador('Barbero 60%', _gananciaBarbero),
                  _buildIndicador('Barbería 40%', _gananciaBarberia),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
          // Búsqueda
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
                                  ? 'No tienes ventas registradas'
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
                        onRefresh: _cargarVentasBarbero,
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
                                      const SizedBox(height: 8),
                                    if (venta.cliente != null)
                                      Text(
                                        'Cliente: ${venta.cliente!.nombreCompleto}',
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
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.blue),
                                  onPressed: () => _verDetallesVenta(venta),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}


