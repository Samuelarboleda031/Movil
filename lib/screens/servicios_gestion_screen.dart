import 'package:flutter/material.dart';
import '../models/servicio.dart';
import '../services/auxiliar_service.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';
import 'servicio_form_screen.dart';

class ServiciosGestionScreen extends StatefulWidget {
  const ServiciosGestionScreen({super.key});

  @override
  State<ServiciosGestionScreen> createState() => _ServiciosGestionScreenState();
}

class _ServiciosGestionScreenState extends State<ServiciosGestionScreen> {
  final AuxiliarService _servicioData = AuxiliarService();
  List<Servicio> _servicios = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarServicios();
  }

  Future<void> _cargarServicios() async {
    setState(() => _isLoading = true);
    try {
      final data = await _servicioData.obtenerServicios();
      setState(() {
        _servicios = data;
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

  List<Servicio> get _serviciosFiltrados {
    if (_searchQuery.isEmpty) return _servicios;
    return _servicios.where((s) {
      return s.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.descripcion?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  Future<void> _eliminarServicio(Servicio servicio) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: Text('¿Desea eliminar el servicio "${servicio.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _servicioData.eliminarServicio(servicio.id!);
        _cargarServicios();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Permitir acceso tanto a Gerente (ID 1) como Administrador (ID 18)
    return SessionGuard(
      requiredRole: AppRole.admin, 
      child: Scaffold(
        appBar: AppBar(title: const Text('MANITO BARBERSHOP')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar servicios...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarVentas, // Perdón, _cargarServicios
                      child: ListView.builder(
                        itemCount: _serviciosFiltrados.length,
                        itemBuilder: (context, index) {
                          final s = _serviciosFiltrados[index];
                          final activo = s.estado ?? true;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${s.duracionMinutos} min | \$${s.precio}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: activo,
                                    onChanged: (val) async {
                                      await _servicioData.cambiarEstadoServicio(s.id!, val);
                                      _cargarServicios();
                                    },
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                    ],
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => ServicioFormScreen(servicio: s)),
                                        ).then((_) => _cargarServicios());
                                      } else if (val == 'delete') {
                                        _eliminarServicio(s);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ServicioFormScreen()),
            ).then((_) => _cargarServicios());
          },
          backgroundColor: const Color(0xFFD8B081),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _cargarVentas() => _cargarServicios();
}
