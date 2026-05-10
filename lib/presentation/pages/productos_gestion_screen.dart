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
  Paginacion<Producto>? _ultimaPaginacion;
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 5;
  String _searchQuery = '';
  String _filtroEstado = 'Todos';
  int? _filtroCategoriaId;

  @override
  void initState() {
    super.initState();
    _cargarProductos(1);
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    try {
      final cats = await _productoService.getCategorias();
      if (mounted) setState(() => _categorias = cats);
    } catch (_) {}
  }

  Future<void> _cargarProductos(int page) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });
    try {
      final data = await _productoService.getProductos(page: page, pageSize: _pageSize);
      
      // Simulación de paginación si el backend no devuelve Paginacion real aún
      if (mounted) {
        setState(() {
          _productos = data;
          _ultimaPaginacion = Paginacion<Producto>(
            items: data,
            totalCount: data.length, // Ajustar si el API devuelve el total
            pageSize: _pageSize,
            currentPage: page,
            totalPages: (data.length == _pageSize) ? page + 1 : page, // Simulación simple
            hasPreviousPage: page > 1,
            hasNextPage: data.length == _pageSize,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Error al cargar: $e');
      }
    }
  }

  List<Producto> get _productosFiltrados {
    var resultado = _productos;

    if (_filtroEstado != 'Todos') {
      final activo = _filtroEstado == 'Activo';
      resultado = resultado.where((p) => p.activo == activo).toList();
    }

    if (_filtroCategoriaId != null) {
      resultado = resultado.where((p) => p.categoriaId == _filtroCategoriaId || p.categoria?.id == _filtroCategoriaId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      resultado = resultado.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
            (p.descripcion?.toLowerCase().contains(q) ?? false) ||
            (p.categoria?.nombre.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return resultado;
  }

  Widget _buildFiltrosProductos() {
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
              if (_filtroEstado != 'Todos' || _filtroCategoriaId != null || _searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchController.clear(); setState(() { _searchQuery = ''; _filtroEstado = 'Todos'; _filtroCategoriaId = null; }); },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                    child: const Icon(Icons.filter_alt_off, size: 18, color: AppColors.gold),
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
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('Todas', style: TextStyle(color: _filtroCategoriaId == null ? AppColors.bg : AppColors.greyLight, fontSize: 11)),
                      selected: _filtroCategoriaId == null,
                      onSelected: (_) => setState(() => _filtroCategoriaId = null),
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.card,
                      side: BorderSide(color: _filtroCategoriaId == null ? AppColors.gold : AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  ..._categorias.map((c) {
                    final sel = _filtroCategoriaId == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(c.nombre, style: TextStyle(color: sel ? AppColors.bg : AppColors.greyLight, fontSize: 11)),
                        selected: sel,
                        onSelected: (_) => setState(() => _filtroCategoriaId = c.id),
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _eliminarProducto(Producto producto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Desea eliminar el producto "${producto.nombre}"?'),
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
        await _productoService.deleteProducto(producto.id!);
        _cargarProductos(_currentPage);
        if (mounted) {
          AppToast.showSuccess(context, 'Producto eliminado correctamente.');
        }
      } catch (e) {
        if (mounted) {
          final isConflict = e.toString().toLowerCase().contains('conflict') || e.toString().toLowerCase().contains('referenc');
          if (isConflict) {
            AppToast.showError(context, 'El producto tiene conexiones y no puede ser eliminado permanentemente. Se desactivará al editar.');
          } else {
            AppToast.showError(context, 'Error al eliminar: $e');
          }
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
          title: const Text('Gestión de Productos', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  hintText: 'Buscar productos...',
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
            _buildFiltrosProductos(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _cargarProductos(1),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: _productosFiltrados.length + ((_ultimaPaginacion != null && _ultimaPaginacion!.totalPages > 1) ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _productosFiltrados.length) {
                             return _buildPaginationControls();
                          }
                          final p = _productosFiltrados[index];
                          final activo = p.activo;
                          final useLabel = p.usoProducto == 'solo_venta' ? 'Venta' : 'Venta e Insumo';
                          final totalStock = p.stockVentas + p.stockInsumos;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProductoDetalleScreen(producto: p, role: AppRole.admin)),
                                ).then((_) => _cargarProductos(_currentPage));
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Imagen del producto
                                    Hero(
                                      tag: 'prod_${p.id}',
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: AppColors.bg,
                                          borderRadius: BorderRadius.circular(12),
                                          image: p.imagenProduc != null && p.imagenProduc!.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(p.imagenProduc!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: p.imagenProduc == null || p.imagenProduc!.isEmpty
                                            ? const Icon(Icons.inventory_2_outlined, color: AppColors.grey, size: 30)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Info central
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.nombre,
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              _buildBadge(p.categoria?.nombre ?? 'General', AppColors.gold.withOpacity(0.2), AppColors.gold),
                                              _buildBadge(useLabel, Colors.blue.withOpacity(0.1), Colors.blue[300]!),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildStockInfo('Venta', p.stockVentas),
                                              const SizedBox(width: 12),
                                              _buildStockInfo('Insumo', p.stockInsumos),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            AppFormat.cop(p.precioVenta),
                                            style: const TextStyle(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Controles derechos
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Switch(
                                          value: activo,
                                          activeColor: AppColors.gold,
                                          onChanged: (val) async {
                                            try {
                                              final updated = await _productoService.toggleProductoActivo(p.id!);
                                              if (mounted) {
                                                setState(() {
                                                  final idx = _productos.indexWhere((x) => x.id == p.id);
                                                  if (idx != -1) _productos[idx] = updated;
                                                });
                                              }
                                            } catch (e) {
                                              if (context.mounted) AppToast.showError(context, 'Error: $e');
                                            }
                                          },
                                        ),
                                        PopupMenuButton(
                                          icon: const Icon(Icons.more_vert, color: AppColors.grey),
                                          color: AppColors.surface,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'details', child: Text('Ver detalles', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                          ],
                                          onSelected: (val) {
                                            if (val == 'details') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => ProductoDetalleScreen(producto: p, role: AppRole.admin)),
                                              ).then((_) => _cargarProductos(_currentPage));
                                            } else if (val == 'edit') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => ProductoFormScreen(producto: p)),
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
        onPageChanged: (page) => _cargarProductos(page),
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

  Widget _buildStockInfo(String label, int count) {
    final bool lowStock = count < 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
        Text(
          count.toString(),
          style: TextStyle(
            color: lowStock ? Colors.redAccent : AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
