import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../services/venta_service.dart';
import '../services/auxiliar_service.dart';
import '../services/auth_service.dart';
import '../models/cliente.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';

class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  final VentaService _ventaService = VentaService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final AuthService _authService = AuthService();
  
  List<Venta> _ventas = [];
  Map<int, String> _nombresBarberos = {};
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
      final user = _authService.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No se pudo identificar al usuario actual.');
      }

      // 1. Identificar al cliente actual
      final clientes = await _auxiliarService.obtenerClientes();
      final clienteActual = clientes.firstWhere(
        (c) => (c.email ?? '').toLowerCase() == user.email!.toLowerCase(),
        orElse: () => Cliente(
          id: 0,
          documento: '',
          nombre: 'Cliente',
          apellido: 'Desconocido',
          telefono: '',
          email: user.email,
          direccion: '',
          estado: true,
        ),
      );

      final todasLasVentas = await _ventaService.obtenerVentas();
      
      // 2. Filtrar ventas del cliente actual
      final misCompras = todasLasVentas.where((v) {
        final coincideId = clienteActual.id != null && 
                          clienteActual.id != 0 && 
                          v.clienteId == clienteActual.id;
                          
        final coincideEmail = v.cliente?.email != null &&
            clienteActual.email != null &&
            v.cliente!.email!.toLowerCase() == clienteActual.email!.toLowerCase();
            
        return coincideId || coincideEmail;
      }).toList();
      
      // Cargar barberos para mapear nombres si faltan en la venta
      try {
        final barberos = await _auxiliarService.obtenerBarberos();
        _nombresBarberos = {for (var b in barberos) b.id!: b.nombreCompleto};
      } catch (e) {
        print('Error cargando barberos auxiliares: $e');
      }

      setState(() {
        _ventas = misCompras;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las compras: $e')),
        );
      }
    }
  }

  List<Venta> get _ventasFiltradas {
    if (_searchQuery.isEmpty) return _ventas;
    return _ventas.where((venta) {
      return venta.numero.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (venta.fechaRegistro?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          venta.total.toString().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.client,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis Compras')),
        body: Column(
          children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por número o total...',
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
          // Lista de compras
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ventasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay compras registradas'
                                  : 'No se encontraron compras',
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
                                          final nombreBarbero = venta.barbero?.nombreCompleto ?? 
                                                              _nombresBarberos[venta.barberoId];
                                          
                                          return Text(
                                            nombreBarbero != null
                                                ? 'Venta hecha por $nombreBarbero'
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
                                        color: (venta.estado == true ? Colors.green : Colors.red)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: venta.estado == true ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      child: Text(
                                        venta.estado == true ? 'Activa' : 'Anulada',
                                        style: TextStyle(
                                          color: venta.estado == true ? Colors.green : Colors.red,
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
                                    if (venta.fechaRegistro != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(venta.fechaRegistro!))}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (venta.metodoPago.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.payment, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Pago: ${venta.metodoPago}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
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
                                  onPressed: () {
                                    _mostrarDetallesVenta(context, venta);
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
      ),
    );
  }

  void _mostrarDetallesVenta(BuildContext context, Venta venta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de la Compra #${venta.numero}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalleItem('Fecha:',
                  venta.fechaRegistro ?? 'No disponible'),
              _buildDetalleItem('Cliente:', venta.cliente?.nombre ?? 'No especificado'),
              if (venta.barbero != null)
                _buildDetalleItem('Barbero:', venta.barbero!.nombre),
              _buildDetalleItem('Método de pago:', venta.metodoPago),
              const SizedBox(height: 16),
              if (venta.detalles != null && venta.detalles!.isNotEmpty) ...[
                const Text('Detalles:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...venta.detalles!.map((detalle) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4),
                      child: Text(_obtenerNombreDetalle(detalle)),
                    )),
                const SizedBox(height: 8),
              ],
              _buildDetalleItem('Subtotal:',
                  '\$${venta.subtotal.toStringAsFixed(2)}', true),
              _buildDetalleItem('Descuento:',
                  '${venta.porcentajeDescuento.toStringAsFixed(2)}%', true),
              _buildDetalleItem(
                  'Total:', '\$${venta.total.toStringAsFixed(2)}', true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _obtenerNombreDetalle(DetalleVenta detalle) {
    if (detalle.productoId != null) {
      return '- Producto #${detalle.productoId} (${detalle.cantidad} x \$${detalle.precioUnitario.toStringAsFixed(2)})';
    } else if (detalle.servicioId != null) {
      return '- Servicio #${detalle.servicioId} (\$${detalle.precioUnitario.toStringAsFixed(2)})';
    } else if (detalle.paqueteId != null) {
      return '- Paquete #${detalle.paqueteId} (\$${detalle.precioUnitario.toStringAsFixed(2)})';
    }
    return '- Producto no especificado (${detalle.cantidad} x \$${detalle.precioUnitario.toStringAsFixed(2)})';
  }

  Widget _buildDetalleItem(String label, String value, [bool isBold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
