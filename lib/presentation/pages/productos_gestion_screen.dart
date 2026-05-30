import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/categoria.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'producto_form_screen.dart';
import 'producto_detalle_screen.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/presentation/widgets/ellipsis_pagination.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class ProductosGestionScreen extends StatefulWidget {
  const ProductosGestionScreen({super.key});

  @override
  State<ProductosGestionScreen> createState() => _ProductosGestionScreenState();
}

class _ProductosGestionScreenState extends State<ProductosGestionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductoService _productoService = ProductoService();

  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  Paginacion<Producto>? _paginacion;

  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 8;

  String _searchQuery = '';
  Timer? _debounce;

  String _filtroEstado = 'Todos';
  int? _filtroCategoriaId;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _cargarProductos(1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final cats = await _productoService.getCategorias();
      if (mounted) setState(() => _categorias = cats);
    } catch (_) {}
  }

  Future<void> _cargarProductos(int page, {String? query}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });
    try {
      final pag = await _productoService.getProductos(
        page: page,
        pageSize: _pageSize,
        q: query ?? (_searchQuery.isEmpty ? null : _searchQuery),
      );
      if (mounted) {
        setState(() {
          _paginacion = pag;
          _productos = pag.items;
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

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() => _searchQuery = val);
      _cargarProductos(1, query: val.isEmpty ? null : val);
    });
  }

  // Filtros locales (estado y categoría son sobre los datos ya cargados de la página)
  List<Producto> get _productosFiltrados {
    var result = _productos;
    if (_filtroEstado != 'Todos') {
      final activo = _filtroEstado == 'Activo';
      result = result.where((p) => p.activo == activo).toList();
    }
    if (_filtroCategoriaId != null) {
      result = result
          .where((p) =>
              p.categoriaId == _filtroCategoriaId ||
              p.categoria?.id == _filtroCategoriaId)
          .toList();
    }
    return result;
  }

  Future<void> _abrirCrear() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(productosExistentes: _productos),
      ),
    );
    if (creado == true) _cargarProductos(_currentPage);
  }

  Future<void> _eliminarProducto(Producto producto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Eliminar Producto',
            style: TextStyle(color: AppColors.white)),
        content: Text(
          '¿Desea eliminar "${producto.nombre}"?',
          style: const TextStyle(color: AppColors.greyLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _productoService.deleteProducto(producto.id!);
        if (mounted) AppToast.showSuccess(context, 'Producto eliminado.');
        _cargarProductos(_currentPage);
      } catch (e) {
        if (mounted) {
          final isConflict = e.toString().toLowerCase().contains('conflict') ||
              e.toString().toLowerCase().contains('referenc');
          AppToast.showError(
            context,
            isConflict
                ? 'El producto tiene referencias y no puede eliminarse. Desactívalo en su lugar.'
                : limpiarError(e),
          );
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Gestión de Productos',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.bg,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  hintStyle: const TextStyle(color: AppColors.grey),
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                  filled: true,
                  fillColor: AppColors.card,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 20, color: AppColors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Filtros locales
            _buildFiltros(),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : RefreshIndicator(
                      color: AppColors.gold,
                      onRefresh: () => _cargarProductos(1),
                      child: _productosFiltrados.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: _productosFiltrados.length +
                                  ((_paginacion != null &&
                                          _paginacion!.totalPages > 1)
                                      ? 1
                                      : 0),
                              itemBuilder: (_, i) {
                                if (i == _productosFiltrados.length) {
                                  return _buildPaginacion();
                                }
                                return _buildCard(_productosFiltrados[i]);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: AppColors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Sin productos',
              style: TextStyle(color: AppColors.white, fontSize: 16)),
          const Text('Ajusta los filtros o crea uno nuevo.',
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
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
                    side: BorderSide(
                        color:
                            sel ? AppColors.gold : AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
              const Spacer(),
              if (_filtroEstado != 'Todos' || _filtroCategoriaId != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _filtroEstado = 'Todos';
                    _filtroCategoriaId = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(Icons.filter_alt_off,
                        size: 18, color: AppColors.gold),
                  ),
                ),
            ],
          ),
          if (_categorias.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _catChip(null, 'Todas'),
                  ..._categorias.map((c) => _catChip(c.id, c.nombre)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _catChip(int? id, String label) {
    final sel = _filtroCategoriaId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                color: sel ? AppColors.bg : AppColors.greyLight,
                fontSize: 11)),
        selected: sel,
        onSelected: (_) => setState(() => _filtroCategoriaId = id),
        selectedColor: AppColors.gold,
        backgroundColor: AppColors.card,
        side: BorderSide(color: sel ? AppColors.gold : AppColors.divider),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildCard(Producto p) {
    final lowStock = p.cantidad < 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: lowStock && p.activo
                ? AppColors.red.withValues(alpha: 0.4)
                : AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProductoDetalleScreen(producto: p, role: AppRole.admin)),
        ).then((_) => _cargarProductos(_currentPage)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen
              Hero(
                tag: 'prod_${p.id}',
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    image: (p.imagenProduc?.isNotEmpty ?? false)
                        ? DecorationImage(
                            image: NetworkImage(p.imagenProduc!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (p.imagenProduc?.isEmpty ?? true)
                      ? const Icon(Icons.inventory_2_outlined,
                          color: AppColors.grey, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, children: [
                      _badge(p.categoria?.nombre ?? 'General',
                          AppColors.gold.withValues(alpha: 0.18), AppColors.gold),
                      if (lowStock && p.activo)
                        _badge('Stock bajo',
                            AppColors.red.withValues(alpha: 0.12), AppColors.red),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _stockPill('Stock', p.cantidad),
                    ]),
                    const SizedBox(height: 6),
                    Text(AppFormat.cop(p.precioVenta),
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
              ),

              // Controles
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Switch(
                    value: p.activo,
                    activeColor: AppColors.gold,
                    onChanged: (_) async {
                      try {
                        final updated =
                            await _productoService.toggleProductoActivo(p.id!);
                        if (mounted) {
                          setState(() {
                            final idx =
                                _productos.indexWhere((x) => x.id == p.id);
                            if (idx != -1) _productos[idx] = updated;
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppToast.showError(context, limpiarError(e));
                        }
                      }
                    },
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.grey),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'details',
                          child: Text('Ver detalles',
                              style: TextStyle(color: Colors.white))),
                      PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar',
                              style: TextStyle(color: Colors.white))),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar',
                              style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (val) {
                      if (val == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProductoDetalleScreen(
                                  producto: p, role: AppRole.admin)),
                        ).then((_) => _cargarProductos(_currentPage));
                      } else if (val == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductoFormScreen(
                              producto: p,
                              productosExistentes: _productos,
                            ),
                          ),
                        ).then((_) => _cargarProductos(_currentPage));
                      } else if (val == 'delete') {
                        _eliminarProducto(p);
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
  }

  Widget _buildPaginacion() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EllipsisPagination(
        totalPages: _paginacion!.totalPages,
        currentPage: _currentPage,
        onPageChanged: _cargarProductos,
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stockPill(String label, int count) {
    final low = count < 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.grey, fontSize: 10)),
        Text('$count',
            style: TextStyle(
                color: low ? Colors.redAccent : AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }
}
