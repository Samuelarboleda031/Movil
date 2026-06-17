import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'servicio_form_screen.dart';
import 'servicio_detalle_screen.dart';
import 'paquete_form_screen.dart';
import 'paquete_detalle_screen.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/presentation/widgets/ellipsis_pagination.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/core/utils/app_confirm_dialog.dart';

class ServiciosGestionScreen extends StatefulWidget {
  const ServiciosGestionScreen({super.key});

  @override
  State<ServiciosGestionScreen> createState() => _ServiciosGestionScreenState();
}

class _ServiciosGestionScreenState extends State<ServiciosGestionScreen> {
  // ── Tab selector ──────────────────────────────────────────────────────────
  bool _mostrandoServicios = true; // true = Servicios, false = Paquetes

  // ── Servicios ─────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final ServicioService _servicioService = ServicioService();
  List<Servicio> _servicios = [];
  Paginacion<Servicio>? _ultimaPaginacion;
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 5;
  String _searchQuery = '';
  String _filtroEstado = 'Todos';

  // ── Paquetes ──────────────────────────────────────────────────────────────
  final TextEditingController _searchPaqueteController = TextEditingController();
  final PaqueteService _paqueteService = PaqueteService();
  List<Paquete> _paquetes = [];
  bool _isLoadingPaquetes = true;
  String? _errorPaquetes;
  String _searchPaqueteQuery = '';
  String _filtroEstadoPaquete = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarServicios(1);
    _cargarPaquetes();
  }

  // ── Servicios: carga ──────────────────────────────────────────────────────
  Future<void> _cargarServicios(int page) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });
    try {
      final data = await _servicioService.obtenerServicios(page: page, pageSize: _pageSize);
      data.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      if (mounted) {
        setState(() {
          _servicios = data;
          _ultimaPaginacion = Paginacion<Servicio>(
            items: data,
            totalCount: data.length,
            pageSize: _pageSize,
            currentPage: page,
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
        AppToast.showError(context, limpiarError(e));
      }
    }
  }

  // ── Paquetes: carga ───────────────────────────────────────────────────────
  Future<void> _cargarPaquetes() async {
    if (!mounted) return;
    setState(() { _isLoadingPaquetes = true; _errorPaquetes = null; });
    try {
      final data = await _paqueteService.obtenerPaquetes();
      data.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      if (mounted) setState(() { _paquetes = data; _isLoadingPaquetes = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingPaquetes = false; _errorPaquetes = e.toString(); });
    }
  }

  // ── Filtros ───────────────────────────────────────────────────────────────
  List<Servicio> get _serviciosFiltrados {
    var r = _servicios;
    if (_filtroEstado != 'Todos') {
      final activo = _filtroEstado == 'Activo';
      r = r.where((s) => (s.estado ?? true) == activo).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      r = r.where((s) =>
          s.nombre.toLowerCase().contains(q) ||
          (s.descripcion?.toLowerCase().contains(q) ?? false)).toList();
    }
    return r;
  }

  List<Paquete> get _paquetesFiltrados {
    var r = _paquetes;
    if (_filtroEstadoPaquete != 'Todos') {
      final activo = _filtroEstadoPaquete == 'Activo';
      r = r.where((p) => (p.estado ?? true) == activo).toList();
    }
    if (_searchPaqueteQuery.isNotEmpty) {
      final q = _searchPaqueteQuery.toLowerCase();
      r = r.where((p) =>
          p.nombre.toLowerCase().contains(q) ||
          (p.descripcion?.toLowerCase().contains(q) ?? false)).toList();
    }
    return r;
  }

  // ── Eliminar servicio ─────────────────────────────────────────────────────
  Future<void> _eliminarServicio(Servicio servicio) async {
    final confirm = await AppConfirmDialog.showDelete(
      context,
      itemName: servicio.nombre,
      title: 'Eliminar Servicio',
      message: '¿Estás seguro de que deseas eliminar el servicio "${servicio.nombre}"?\n\nEsta acción no se puede deshacer.',
      confirmLabel: 'Eliminar Servicio',
    );
    if (confirm == true) {
      try {
        await _servicioService.eliminarServicio(servicio.id!);
        if (mounted) AppToast.showSuccess(context, 'El servicio "${servicio.nombre}" ha sido eliminado exitosamente del catálogo.');
        _cargarServicios(_currentPage);
      } catch (e) {
        if (mounted) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('conflict') || msg.contains('referenc') || msg.contains('asociad')) {
            AppToast.showError(context, 'Este servicio está asociado a ventas, paquetes o citas. Debes eliminar o desasociar esos registros antes de eliminarlo.');
          } else {
            AppToast.showError(context, limpiarError(e));
          }
        }
      }
    }
  }

  Future<void> _eliminarPaquete(Paquete paquete) async {
    final confirm = await AppConfirmDialog.showDelete(
      context,
      itemName: paquete.nombre,
      title: 'Eliminar Paquete',
      message: '¿Estás seguro de que deseas eliminar el paquete "${paquete.nombre}"?\n\nEsta acción no se puede deshacer.',
      confirmLabel: 'Eliminar Paquete',
    );
    if (confirm == true) {
      try {
        await _paqueteService.eliminarPaquete(paquete.id!);
        _cargarPaquetes();
        if (mounted) AppToast.showSuccess(context, 'El paquete "${paquete.nombre}" ha sido eliminado del sistema.');
      } catch (e) {
        if (mounted) {
          final desactivar = await AppConfirmDialog.showWarning(
            context,
            title: 'No se puede eliminar',
            message: 'Este paquete tiene conexiones o citas asociadas y no puede borrarse físicamente.\n\n¿Deseas desactivarlo en su lugar para conservar el historial?',
            confirmLabel: 'Desactivar',
          );
          if (desactivar == true && mounted) {
            try {
              await _paqueteService.cambiarEstadoPaquete(paquete.id!, false);
              _cargarPaquetes();
              if (mounted) AppToast.showSuccess(context, 'El paquete "${paquete.nombre}" se desactivó automáticamente porque tiene conexiones.');
            } catch (ex) {
              if (mounted) AppToast.showError(context, limpiarError(ex));
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchPaqueteController.dispose();
    super.dispose();
  }

  // ── Tab selector widget ───────────────────────────────────────────────────
  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _buildTab(
              label: 'Servicios',
              icon: Icons.content_cut,
              selected: _mostrandoServicios,
              onTap: () {
                if (!_mostrandoServicios) {
                  setState(() => _mostrandoServicios = true);
                  _cargarServicios(1);
                }
              },
            ),
            _buildTab(
              label: 'Paquetes',
              icon: Icons.inventory_2_outlined,
              selected: !_mostrandoServicios,
              onTap: () {
                if (_mostrandoServicios) {
                  setState(() => _mostrandoServicios = false);
                  _cargarPaquetes();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? const Color(0xFF111111) : AppColors.greyLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF111111) : AppColors.greyLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtros servicios ─────────────────────────────────────────────────────
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
                label: Text(e,
                    style: TextStyle(
                        color: sel ? AppColors.bg : AppColors.greyLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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
              onTap: () {
                _searchController.clear();
                setState(() { _searchQuery = ''; _filtroEstado = 'Todos'; });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider)),
                child: const Icon(Icons.filter_alt_off, size: 18, color: AppColors.gold),
              ),
            ),
        ],
      ),
    );
  }

  // ── Filtros paquetes ──────────────────────────────────────────────────────
  Widget _buildFiltrosPaquetes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          ...['Todos', 'Activo', 'Inactivo'].map((e) {
            final sel = _filtroEstadoPaquete == e;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(e,
                    style: TextStyle(
                        color: sel ? AppColors.bg : AppColors.greyLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                selected: sel,
                onSelected: (_) => setState(() => _filtroEstadoPaquete = e),
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
          if (_filtroEstadoPaquete != 'Todos' || _searchPaqueteQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchPaqueteController.clear();
                setState(() { _searchPaqueteQuery = ''; _filtroEstadoPaquete = 'Todos'; });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider)),
                child: const Icon(Icons.filter_alt_off, size: 18, color: AppColors.gold),
              ),
            ),
        ],
      ),
    );
  }

  // ── Lista servicios ───────────────────────────────────────────────────────
  Widget _buildListaServicios() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _cargarServicios(1),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        itemCount: _serviciosFiltrados.length +
            ((_ultimaPaginacion != null && _ultimaPaginacion!.totalPages > 1) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _serviciosFiltrados.length) return _buildPaginationControls();
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
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        image: s.imagen != null && s.imagen!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(s.imagen!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: s.imagen == null || s.imagen!.isEmpty
                          ? const Icon(Icons.content_cut, color: AppColors.gold, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nombre,
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _buildBadge(AppFormat.duracion(s.duracionMinutos),
                                AppColors.gold.withOpacity(0.15), AppColors.gold),
                          ]),
                          const SizedBox(height: 6),
                          Text(AppFormat.cop(s.precio),
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Switch(
                          value: activo,
                          activeColor: AppColors.gold,
                          onChanged: (val) async {
                            try {
                              await _servicioService.cambiarEstadoServicio(s.id!, val);
                              _cargarServicios(_currentPage);
                              if (mounted) {
                                AppToast.showSuccess(
                                  context,
                                  'El servicio "${s.nombre}" ha sido ${val ? "activado" : "desactivado"} exitosamente.',
                                );
                              }
                            } catch (e) {
                              if (mounted) AppToast.showError(context, limpiarError(e));
                            }
                          },
                        ),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: AppColors.grey),
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar', style: TextStyle(color: Colors.white))),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                          ],
                          onSelected: (val) {
                            if (val == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ServicioFormScreen(servicio: s)),
                              ).then((_) => _cargarServicios(_currentPage));
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
    );
  }

  // ── Lista paquetes ────────────────────────────────────────────────────────
  Widget _buildListaPaquetes() {
    if (_isLoadingPaquetes) return const Center(child: CircularProgressIndicator());

    if (_errorPaquetes != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorPaquetes!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _cargarPaquetes,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Reintentar',
                      style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final lista = _paquetesFiltrados;
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.grey.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('Sin paquetes', style: TextStyle(color: AppColors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarPaquetes,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final p = lista[index];
          final activo = p.estado ?? true;
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
                      builder: (_) => PaqueteDetalleScreen(
                        paquete: p,
                        role: role ?? AppRole.client,
                      ),
                    ),
                  ).then((_) => _cargarPaquetes());
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Icono paquete
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nombre,
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _buildBadge(AppFormat.duracion(p.duracionMinutos),
                                AppColors.gold.withOpacity(0.15), AppColors.gold),
                          ]),
                          const SizedBox(height: 6),
                          // Calcular precio final con descuento
                          Builder(builder: (context) {
                            final double precioOriginal = p.precio;
                            final double descuento = p.descuento;
                            final double precioFinal = descuento > 0 
                                ? precioOriginal - (precioOriginal * (descuento / 100)) 
                                : precioOriginal;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (descuento > 0)
                                  Text(
                                    AppFormat.cop(precioOriginal),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  AppFormat.cop(precioFinal),
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          }),
                          if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(p.descripcion!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Switch(
                          value: activo,
                          activeColor: AppColors.gold,
                          onChanged: (val) async {
                            try {
                              await _paqueteService.cambiarEstadoPaquete(p.id!, val);
                              _cargarPaquetes();
                              if (mounted) {
                                AppToast.showSuccess(
                                  context,
                                  'El paquete "${p.nombre}" ha sido ${val ? "activado" : "desactivado"} exitosamente.',
                                );
                              }
                            } catch (e) {
                              if (mounted) AppToast.showError(context, limpiarError(e));
                            }
                          },
                        ),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: AppColors.grey),
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar', style: TextStyle(color: Colors.white))),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                          ],
                          onSelected: (val) {
                            if (val == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PaqueteFormScreen(paquete: p)),
                              ).then((_) => _cargarPaquetes());
                            } else if (val == 'delete') {
                              _eliminarPaquete(p);
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
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Gestión de Servicios',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.bg,
          elevation: 0,
        ),
        body: Column(
          children: [
            // ── Tab selector ──────────────────────────────────────────────
            _buildTabSelector(),

            // ── Buscador ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _mostrandoServicios
                  ? TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar servicio...',
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
                    )
                  : TextField(
                      controller: _searchPaqueteController,
                      style: const TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar paquete...',
                        hintStyle: const TextStyle(color: AppColors.grey),
                        prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                        filled: true,
                        fillColor: AppColors.card,
                        suffixIcon: _searchPaqueteQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20, color: AppColors.grey),
                                onPressed: () {
                                  _searchPaqueteController.clear();
                                  setState(() => _searchPaqueteQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) => setState(() => _searchPaqueteQuery = val),
                    ),
            ),

            // ── Filtros ───────────────────────────────────────────────────
            _mostrandoServicios ? _buildFiltrosServicios() : _buildFiltrosPaquetes(),

            // ── Lista ─────────────────────────────────────────────────────
            Expanded(
              child: _mostrandoServicios
                  ? _buildListaServicios()
                  : _buildListaPaquetes(),
            ),
          ],
        ),
        // ── FAB ───────────────────────────────────────────────────────────
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            if (_mostrandoServicios) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicioFormScreen()),
              ).then((_) => _cargarServicios(_currentPage));
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaqueteFormScreen()),
              ).then((_) => _cargarPaquetes());
            }
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Color(0xFF111111)),
          ),
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
