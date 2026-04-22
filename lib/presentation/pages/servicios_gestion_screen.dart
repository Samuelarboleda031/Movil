import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'servicio_form_screen.dart';
import 'servicio_detalle_screen.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class ServiciosGestionScreen extends StatefulWidget {
  const ServiciosGestionScreen({super.key});

  @override
  State<ServiciosGestionScreen> createState() => _ServiciosGestionScreenState();
}

class _ServiciosGestionScreenState extends State<ServiciosGestionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuxiliarService _servicioData = AuxiliarService();
  List<Servicio> _servicios = [];
  Paginacion<Servicio>? _ultimaPaginacion;
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 5;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarServicios(1);
  }

  Future<void> _cargarServicios(int page) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });
    try {
      // Nota: Si el backend no soporta paginación real en servicios, enviamos pageSize grande
      final data = await _servicioData.obtenerServicios(page: page, pageSize: _pageSize);
      
      // Simulación de paginación si el backend devuelve lista plana
      // (ajustar cuando el backend devuelva Paginacion real para servicios)
      if (mounted) {
        // Sort alphabetically
        data.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        
        setState(() {
          _servicios = data;
          _ultimaPaginacion = Paginacion<Servicio>(
            items: data,
            totalCount: data.length,
            pageSize: _pageSize,
            currentPage: page,
            totalPages: (data.length / _pageSize).ceil().clamp(1, 99), 
            hasPreviousPage: page > 1,
            hasNextPage: data.length == _pageSize,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
        _cargarServicios(_currentPage);
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        appBar: AppBar(title: const Text('Gestión de Servicios')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar en esta página...',
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _cargarServicios(1),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                        itemCount: _serviciosFiltrados.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _serviciosFiltrados.length) {
                             if (_ultimaPaginacion != null && _ultimaPaginacion!.totalPages > 1) {
                               return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: _buildPaginationControls());
                             }
                             return const SizedBox(height: 80);
                          }
                          final s = _serviciosFiltrados[index];
                          final activo = s.estado ?? true;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              onTap: () async {
                                final auth = AuthService();
                                final user = await auth.getCurrentUser();
                                final role = user?.rolId != null ? roleForRolId(user!.rolId) : AppRole.client;
                                
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ServicioDetalleScreen(
                                        servicio: s,
                                        role: role ?? AppRole.client,
                                      ),
                                    ),
                                  ).then((_) => _cargarServicios(_currentPage));
                                }
                              },
                              leading: s.imagen != null && s.imagen!.isNotEmpty 
                                ? CircleAvatar(backgroundImage: NetworkImage(s.imagen!))
                                : const CircleAvatar(child: Icon(Icons.content_cut)),
                              title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${s.duracionMinutos} min | ${AppFormat.cop(s.precio)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: activo,
                                    onChanged: (val) async {
                                      await _servicioData.cambiarEstadoServicio(s.id!, val);
                                      _cargarServicios(_currentPage);
                                    },
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                    ],
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => ServicioFormScreen(servicio: s))).then((_) => _cargarServicios(_currentPage));
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
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _ultimaPaginacion!.totalPages;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(icon: Icons.chevron_left, onTap: _currentPage > 1 ? () => _cargarServicios(_currentPage - 1) : null),
        const SizedBox(width: 8),
        ..._buildPageNumbers(totalPages),
        const SizedBox(width: 8),
        _buildPageButton(icon: Icons.chevron_right, onTap: _currentPage < totalPages ? () => _cargarServicios(_currentPage + 1) : null),
      ],
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> widgets = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 || i == totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1)) {
        widgets.add(_buildPageNumberButton(i));
      } else if (i == _currentPage - 2 || i == _currentPage + 2) {
        widgets.add(const Text('...', style: TextStyle(color: Colors.grey)));
      }
    }
    return widgets;
  }

  Widget _buildPageNumberButton(int page) {
    bool isSelected = page == _currentPage;
    return GestureDetector(
      onTap: isSelected ? null : () => _cargarServicios(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD8B081) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Text(page.toString(), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
        child: Icon(icon, color: onTap == null ? Colors.grey : Colors.white, size: 20),
      ),
    );
  }
}
