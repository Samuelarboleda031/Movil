import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'producto_form_screen.dart';
import 'producto_detalle_screen.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';

class ProductosGestionScreen extends StatefulWidget {
  const ProductosGestionScreen({super.key});

  @override
  State<ProductosGestionScreen> createState() => _ProductosGestionScreenState();
}

class _ProductosGestionScreenState extends State<ProductosGestionScreen> {
  final ProductoService _productoService = ProductoService();
  List<Producto> _productos = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _productoService.getProductos();
      if (mounted) {
        setState(() {
          _productos = data;
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
    if (_searchQuery.isEmpty) return _productos;
    return _productos.where((p) {
      return p.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.descripcion?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (p.categoria?.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
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
        _cargarProductos();
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
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(title: const Text('Gestión de Productos')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
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
                      onRefresh: _cargarProductos,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                        itemCount: _productosFiltrados.length,
                        itemBuilder: (context, index) {
                          final p = _productosFiltrados[index];
                          final activo = p.activo;
                          final useLabel = p.usoProducto == 'solo_venta' ? 'Venta' : 'Venta e Insumo';
                          final totalStock = p.stockVentas + p.stockInsumos;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProductoDetalleScreen(producto: p)),
                                ).then((_) => _cargarProductos());
                              },
                              leading: p.imagenProduc != null && p.imagenProduc!.isNotEmpty 
                                ? CircleAvatar(backgroundImage: NetworkImage(p.imagenProduc!))
                                : const CircleAvatar(child: Icon(Icons.inventory)),
                              title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p.categoria?.nombre ?? p.categoriaId} | $useLabel'),
                                  Text('Stock: $totalStock (V: ${p.stockVentas} / I: ${p.stockInsumos}) | Precio Venta: ${AppFormat.cop(p.precioVenta)}'),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: activo,
                                    onChanged: (val) async {
                                      try {
                                        await _productoService.toggleProductoActivo(p.id!);
                                        _cargarProductos();
                                      } catch (e) {
                                        if (context.mounted) AppToast.showError(context, 'Error: $e');
                                      }
                                    },
                                  ),
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'details', child: Text('Ver detalles')),
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                      ],
                                      onSelected: (val) {
                                        if (val == 'details') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => ProductoDetalleScreen(producto: p)),
                                          ).then((_) => _cargarProductos());
                                        } else if (val == 'edit') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => ProductoFormScreen(producto: p)),
                                          ).then((_) => _cargarProductos());
                                        } else if (val == 'delete') {
                                          _eliminarProducto(p);
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
}
