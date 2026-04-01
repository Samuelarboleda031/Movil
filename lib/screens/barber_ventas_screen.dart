import 'package:flutter/material.dart';
import '../models/venta.dart';
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
  bool _isLoading = true;
  String _searchQuery = '';

  final Map<int, String> _nombresClientes = {};

  @override
  void initState() {
    super.initState();
    _cargarVentasBarbero();
  }

  Future<void> _cargarVentasBarbero() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null || user.email == null) throw Exception('No identificado');

      final barberos = await _auxiliarService.obtenerBarberos();
      final barbero = barberos.firstWhere(
        (b) => (b.email ?? '').toLowerCase() == user.email!.toLowerCase(),
        orElse: () => throw Exception('Perfil de barbero no encontrado para este usuario'),
      );

      final paginacion = await _ventaService.obtenerVentas(page: 1, pageSize: 2000);
      final todas = paginacion.items;
      final propias = todas.where((v) => v.barberoId == barbero.id).toList();

      // Cargar nombres de clientes para fallback
      final clientes = await _auxiliarService.obtenerClientes();
      for (var c in clientes) {
        _nombresClientes[c.id!] = c.nombreCompleto;
      }

      setState(() {
        _ventas = propias;
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
    if (_searchQuery.isEmpty) return _ventas;
    final q = _searchQuery.toLowerCase();
    return _ventas.where((v) {
      final num = v.numero.toLowerCase();
      final cli = v.cliente?.nombreCompleto.toLowerCase() ?? (_nombresClientes[v.clienteId]?.toLowerCase() ?? '');
      return num.contains(q) || cli.contains(q);
    }).toList();
  }

  double get _totalIngresos => _ventasFiltradas.where((v) => v.estado != false).fold(0, (sum, v) => sum + v.total);
  double get _gananciaBarbero => _totalIngresos * 0.6;

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.barber,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Ventas'),
          actions: [
            _buildResumenHeader(),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por número o cliente...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ventasFiltradas.isEmpty
                      ? const Center(child: Text('No hay ventas registradas'))
                      : RefreshIndicator(
                          onRefresh: _cargarVentasBarbero,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _ventasFiltradas.length,
                            itemBuilder: (context, index) {
                              return _buildVentaCard(_ventasFiltradas[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenHeader() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD8B081).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8B081).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('MI GANANCIA (60%)', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(
            '\$${_gananciaBarbero.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD8B081)),
          ),
        ],
      ),
    );
  }

  Widget _buildVentaCard(Venta venta) {
    final bool isAnulada = venta.estado == false;
    final nombreCliente = venta.cliente?.nombreCompleto ?? (_nombresClientes[venta.clienteId] ?? 'Venta #${venta.numero}');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isAnulada ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          child: Icon(
            isAnulada ? Icons.close : Icons.shopping_bag,
            color: isAnulada ? Colors.red : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nombreCliente,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '\$${venta.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD8B081)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  venta.fechaRegistro?.split('T')[0] ?? 'Sin fecha',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Icon(
                  venta.estado == false ? Icons.cancel : Icons.check_circle,
                  size: 13,
                  color: venta.estado == false ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  venta.estado == false ? 'ANULADA' : 'ACTIVA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: venta.estado == false ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _verDetallesVenta(venta),
      ),
    );
  }

  Future<void> _verDetallesVenta(Venta summary) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final full = await _ventaService.obtenerVentaPorId(summary.id!);
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
                _detailRow('Cliente:', full.cliente?.nombreCompleto ?? 'N/A'),
                _detailRow('Pago:', full.metodoPago),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (full.detalles != null)
                  ...full.detalles!.map((d) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• ${d.cantidad} x ${d.precioUnitario.toStringAsFixed(2)}'),
                      )),
                const Divider(),
                _detailRow('Total:', '\$${full.total.toStringAsFixed(2)}'),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
