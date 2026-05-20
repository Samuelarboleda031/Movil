import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/categoria.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/datasources/media_service.dart';
import 'package:parte_movil/data/datasources/media_service.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;

  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductoService _productoService = ProductoService();
  final MediaService _mediaService = MediaService();
  
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();
  final _precioCompraCtrl = TextEditingController();
  final _stockVentasCtrl = TextEditingController();
  final _stockInsumosCtrl = TextEditingController();
  final _stockTotalCtrl = TextEditingController();
  final _minCantidadCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();

  bool _loading = false;
  bool _isNew = true;
  String? _imagenUrl;
  XFile? _imagenFile;
  Uint8List? _imageBytesPreview;

  List<Categoria> _categorias = [];
  int? _selectedCategoriaId;
  String _usoProducto = 'venta_e_insumo';

  @override
  void initState() {
    super.initState();
    _isNew = widget.producto == null;
    _cargarCategorias();

    if (!_isNew) {
      final p = widget.producto!;
      _nombreCtrl.text = p.nombre;
      _descripcionCtrl.text = p.descripcion ?? '';
      _precioVentaCtrl.text = p.precioVenta.toString();
      _precioCompraCtrl.text = p.precioCompra.toString();
      _stockVentasCtrl.text = p.stockVentas.toString();
      _stockInsumosCtrl.text = p.stockInsumos.toString();
      _stockTotalCtrl.text = (p.stockVentas + p.stockInsumos).toString();
      _minCantidadCtrl.text = p.minCantidad.toString();
      _marcaCtrl.text = p.marca ?? '';
      final usageValue = p.usoProducto;
      if (usageValue == 'solo_venta' || usageValue == 'venta_e_insumo') {
        _usoProducto = usageValue;
      } else {
        _usoProducto = 'venta_e_insumo';
      }
      _imagenUrl = p.imagenProduc;
      _selectedCategoriaId = p.categoriaId != 0 ? p.categoriaId : p.categoria?.id;
      
      // Listeners para actualizar Stock Total
      _stockVentasCtrl.addListener(_updateTotalStock);
      _stockInsumosCtrl.addListener(_updateTotalStock);
    } else {
      _precioVentaCtrl.text = '0';
      _precioCompraCtrl.text = '0';
      _stockVentasCtrl.text = '0';
      _stockInsumosCtrl.text = '0';
      _stockTotalCtrl.text = '0';
      _minCantidadCtrl.text = '0';
    }
  }

  void _updateTotalStock() {
    final v = int.tryParse(_stockVentasCtrl.text) ?? 0;
    final i = int.tryParse(_stockInsumosCtrl.text) ?? 0;
    _stockTotalCtrl.text = (v + i).toString();
  }

  Future<void> _cargarCategorias() async {
    try {
      final cats = await _productoService.getCategorias();
      if (mounted) {
        setState(() {
          _categorias = cats;
          if (_categorias.isNotEmpty && _selectedCategoriaId == null) {
            // Default select
            _selectedCategoriaId = _categorias.first.id;
          } else if (_categorias.isNotEmpty && _selectedCategoriaId != null) {
            // Check if exists
            bool exists = _categorias.any((c) => c.id == _selectedCategoriaId);
            if (!exists) _selectedCategoriaId = _categorias.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cargar categorías: $e');
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioCompraCtrl.dispose();
    _stockVentasCtrl.dispose();
    _stockInsumosCtrl.dispose();
    _stockTotalCtrl.dispose();
    _minCantidadCtrl.dispose();
    _marcaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imagenFile = image;
        _imageBytesPreview = bytes;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoriaId == null) {
      AppToast.showError(context, 'Debe seleccionar una categoría');
      return;
    }

    setState(() => _loading = true);
    try {
      String? imagenFinal = _imagenUrl;
      if (_imagenFile != null && _imageBytesPreview != null) {
        imagenFinal = await _mediaService.subirImagen(
          _imagenFile!.path, 
          imageBytes: _imageBytesPreview, 
          fileName: _imagenFile!.name
        );
      }

      final sv = int.parse(_stockVentasCtrl.text.isEmpty ? '0' : _stockVentasCtrl.text);
      int si = int.parse(_stockInsumosCtrl.text.isEmpty ? '0' : _stockInsumosCtrl.text);
      if (_usoProducto == 'solo_venta') {
        si = 0; // forzar a 0
      }

      final cat = _categorias.firstWhere((c) => c.id == _selectedCategoriaId);

      final p = Producto(
        id: widget.producto?.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        categoriaId: cat.id ?? 0,
        categoria: cat,
        precioVenta: double.parse(_precioVentaCtrl.text),
        precioCompra: double.parse(_precioCompraCtrl.text),
        stockVentas: sv,
        stockInsumos: si,
        cantidad: sv + si,
        minCantidad: int.parse(_minCantidadCtrl.text),
        marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
        activo: widget.producto?.activo ?? true,
        usoProducto: _usoProducto,
        tipo: _usoProducto,
        imagenProduc: imagenFinal,
      );

      if (_isNew) {
        await _productoService.createProducto(p);
      } else {
        await _productoService.updateProducto(p);
      }

      if (mounted) {
        AppToast.showSuccess(context, _isNew ? '✅ Producto creado' : '✅ Producto actualizado');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, limpiarError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        appBar: AppBar(title: Text(_isNew ? 'Nuevo Producto' : 'Editar Producto')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCategoriaId,
                  decoration: const InputDecoration(labelText: 'Categoría *', border: OutlineInputBorder()),
                  items: _categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                  onChanged: (val) => setState(() => _selectedCategoriaId = val),
                  validator: (val) => val == null ? 'Requerida' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _usoProducto,
                  decoration: const InputDecoration(labelText: 'Uso del Producto *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'venta_e_insumo', child: Text('Venta e Insumos')),
                    DropdownMenuItem(value: 'solo_venta', child: Text('Solo Venta')),
                  ],
                  onChanged: (val) => setState(() {
                    if (val != null) {
                      _usoProducto = val;
                      if (_usoProducto == 'solo_venta') {
                        _stockInsumosCtrl.text = '0';
                        _updateTotalStock();
                      }
                    }
                  }),
                ),
                const SizedBox(height: 16),
                
                if (!_isNew) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _precioVentaCtrl,
                          decoration: const InputDecoration(labelText: 'Precio Venta (\$)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Requerido';
                            if (double.tryParse(val) == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _precioCompraCtrl,
                          decoration: const InputDecoration(labelText: 'Precio Compra (\$)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Requerido';
                            if (double.tryParse(val) == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_isNew) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockTotalCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Stock Total', 
                            border: OutlineInputBorder(),
                            fillColor: Colors.black26,
                            filled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockVentasCtrl,
                          decoration: const InputDecoration(labelText: 'Stock Ventas', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val != null && val.isNotEmpty && int.tryParse(val) == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockInsumosCtrl,
                          enabled: _usoProducto == 'venta_e_insumo',
                          decoration: InputDecoration(
                            labelText: 'Stock Insumos', 
                            border: const OutlineInputBorder(),
                            fillColor: _usoProducto == 'solo_venta' ? Colors.black26 : null,
                            filled: _usoProducto == 'solo_venta',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val != null && val.isNotEmpty && int.tryParse(val) == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _marcaCtrl,
                        decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: _imageBytesPreview != null
                        ? Image.memory(_imageBytesPreview!, fit: BoxFit.cover)
                        : (_imagenUrl != null && _imagenUrl!.isNotEmpty)
                            ? Image.network(_imagenUrl!, fit: BoxFit.cover)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Añadir imagen (Opcional)', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
                if (_imageBytesPreview != null || (_imagenUrl != null && _imagenUrl!.isNotEmpty))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imagenFile = null;
                          _imageBytesPreview = null;
                          _imagenUrl = null;
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Quitar imagen', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _loading ? null : _guardar,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC9A96E).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Color(0xFF111111), strokeWidth: 2.5),
                            )
                          : const Text(
                              'Guardar Producto',
                              style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
