import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/datasources/usuario_service.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/presentation/pages/venta_detalle_screen.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';

class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  final VentaService _ventaService = VentaService();
  final UserContextService _userContextService = UserContextService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final UsuarioService _usuarioService = UsuarioService();
  
  List<Venta> _ventas = [];
  bool _isLoading = true;
  String _searchQuery = '';
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

      final paginacion = await _ventaService.obtenerVentas(page: 1, pageSize: 2000);
      final misVentas = paginacion.items.where((v) => v.clienteId == cliente.id).toList();

      final barberos = await _auxiliarService.obtenerBarberos();
      for (var b in barberos) {
        if (b.id != null) {
          _nombresBarberos[b.id!] = b.nombreCompleto;
        }
      }

      try {
        final usuarios = await _usuarioService.obtenerUsuarios();
        for (var u in usuarios) {
          if (u.id != null) {
            _nombresUsuarios[u.id!] = u.nombreCompleto;
          }
        }
      } catch (e) {
        print('Error cargando usuarios: $e');
      }

      try {
        final productos = await _auxiliarService.obtenerProductos();
        for (var p in productos) {
          if (p.id != null) _nombresProductos[p.id!] = p.nombre;
        }
        
        final servicios = await _auxiliarService.obtenerServicios();
        for (var s in servicios) {
          if (s.id != null) _nombresServicios[s.id!] = s.nombre;
        }

        final paquetes = await _auxiliarService.obtenerPaquetes();
        for (var p in paquetes) {
          if (p.id != null) _nombresPaquetes[p.id!] = p.nombre;
        }
      } catch (e) {
        print('Error cargando catálogos de ítems: $e');
      }

      setState(() {
        _ventas = misVentas;
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
    return _ventas.where((v) => v.numero.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.client,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Compras'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por número de ticket...',
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
                      ? const Center(child: Text('No hay compras registradas'))
                      : RefreshIndicator(
                          onRefresh: _cargarCompras,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _ventasFiltradas.length,
                            itemBuilder: (context, index) {
                              return _buildCompraCard(_ventasFiltradas[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
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
