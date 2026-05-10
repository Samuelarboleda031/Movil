import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'servicio_form_screen.dart';
import 'servicio_detalle_screen.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/presentation/widgets/ellipsis_pagination.dart';

class ServiciosGestionScreen extends StatefulWidget {
  const ServiciosGestionScreen({super.key});

  @override
  State<ServiciosGestionScreen> createState() => _ServiciosGestionScreenState();
}

class _ServiciosGestionScreenState extends State<ServiciosGestionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ServicioService _servicioService = ServicioService();
  List<Servicio> _servicios = [];
  Paginacion<Servicio>? _ultimaPaginacion;
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 5;
  String _searchQuery = '';
  String _filtroEstado = 'Todos';

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
      final data = await _servicioService.obtenerServicios(page: page, pageSize: _pageSize);
      
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
            // Si el backend no devuelve el total, asumimos que si hay _pageSize hay más páginas
            totalPages: (data.length == _pageSize) ? page + 1 : page,
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
    var resultado = _servicios;

    if (_filtroEstado != 'Todos') {
      final activo = _filtroEstado == 'Activo';
      resultado = resultado.where((s) => (s.estado ?? true) == activo).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      resultado = resultado.where((s) {
        return s.nombre.toLowerCase().contains(q) ||
            (s.descripcion?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return resultado;
  }

  Widget _buildFiltrosServicios() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          ...['Todos', 'Activo', 'Inactivo'].map((e) {
            final sel = _filtroEstado == e;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(e, style: TextStyle(color: sel ? AppColors.bg : AppColors.greyLight, fontSize: 12, fontWeight: FontWeight.w600)),
                selected: sel,
                onSelected: (_) => setState(() => _filtroEstado = e),
                selectedColor: AppColors.gold,
                backgroundColor: AppColors.card,
                side: BorderSide(color: sel ? AppColors.gold : AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
          const Spacer(),
          if (_filtroEstado != 'Todos' || _searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () { _searchController.clear(); setState(() { _searchQuery = ''; _filtroEstado = 'Todos'; }); },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                child: const Icon(Icons.filter_alt_off, size: 18, color: AppColors.gold),
              ),
            ),
        ],
      ),
    );
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
        await _servicioService.eliminarServicio(servicio.id!);
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Gestión de Servicios', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.bg,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar en esta página...',
                  hintStyle: const TextStyle(color: AppColors.grey),
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                  filled: true,
                  fillColor: AppColors.card,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20, color: AppColors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            _buildFiltrosServicios(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _cargarServicios(1),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                        itemCount: _serviciosFiltrados.length + ((_ultimaPaginacion != null && _ultimaPaginacion!.totalPages > 1) ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _serviciosFiltrados.length) {
                             return _buildPaginationControls();
                          }
                          final s = _serviciosFiltrados[index];
                          final activo = s.estado ?? true;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
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
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Imagen/Icono
                                    Container(
                                      width: 65,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        color: AppColors.bg,
                                        borderRadius: BorderRadius.circular(12),
                                        image: s.imagen != null && s.imagen!.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(s.imagen!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: s.imagen == null || s.imagen!.isEmpty
                                          ? const Icon(Icons.content_cut, color: AppColors.gold, size: 28)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.nombre,
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _buildBadge('${s.duracionMinutos} min', AppColors.gold.withOpacity(0.15), AppColors.gold),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            AppFormat.cop(s.precio),
                                            style: const TextStyle(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Controles
                                    Column(
                                      children: [
                                        Switch(
                                          value: activo,
                                          activeColor: AppColors.gold,
                                          onChanged: (val) async {
                                            await _servicioService.cambiarEstadoServicio(s.id!, val);
                                            _cargarServicios(_currentPage);
                                          },
                                        ),
                                        PopupMenuButton(
                                          icon: const Icon(Icons.more_vert, color: AppColors.grey),
                                          color: AppColors.surface,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Colors.white))),
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
                                  ],
                                ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EllipsisPagination(
        totalPages: _ultimaPaginacion!.totalPages,
        currentPage: _currentPage,
        onPageChanged: (page) => _cargarServicios(page),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

