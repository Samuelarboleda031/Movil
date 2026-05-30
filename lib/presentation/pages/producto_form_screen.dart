import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/categoria.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/datasources/media_service.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

// ── Constantes de validación ──────────────────────────────────────────────────
const int _kNombreMinLen = 2;
const int _kNombreMaxLen = 18;
final RegExp _kOnlyPunctuation = RegExp(r'^[^a-zA-ZáéíóúÁÉÍÓÚüÜñÑ]+$');

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;
  final List<Producto> productosExistentes;

  const ProductoFormScreen({
    super.key,
    this.producto,
    this.productosExistentes = const [],
  });

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductoService();
  final _mediaService = MediaService();

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();
  final _precioCompraCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _categoriaSearchCtrl = TextEditingController();

  bool _loading = false;
  bool get _isNew => widget.producto == null;

  String? _imagenUrl;
  XFile? _imagenFile;
  Uint8List? _imageBytesPreview;

  List<Categoria> _categorias = [];
  List<Categoria> _categoriasFiltradas = [];
  int? _selectedCategoriaId;
  String? _selectedCategoriaNombre;

  // ── Validación de nombre en tiempo real ──────────────────────────────────
  bool _nombreHasDigit = false;
  bool _nombreOnlyPunctuation = false;
  bool _nombreTooShort = false;
  bool _nombreTooLong = false;
  bool _nombreDuplicado = false;

  @override
  void initState() {
    super.initState();

    if (!_isNew) {
      final p = widget.producto!;
      _nombreCtrl.text = p.nombre;
      _descripcionCtrl.text = p.descripcion ?? '';
      _precioVentaCtrl.text = p.precioVenta.toStringAsFixed(0);
      _precioCompraCtrl.text = p.precioCompra.toStringAsFixed(0);
      _stockCtrl.text = p.cantidad.toString();
      _marcaCtrl.text = p.marca ?? '';
      _imagenUrl = p.imagenProduc;
      _selectedCategoriaId = p.categoriaId != 0 ? p.categoriaId : p.categoria?.id;
      _selectedCategoriaNombre = p.categoria?.nombre;
    } else {
      _precioVentaCtrl.text = '0';
      _precioCompraCtrl.text = '0';
      _stockCtrl.text = '0';
    }

    _nombreCtrl.addListener(_onNombreChanged);
    _cargarCategorias();
  }

  @override
  void dispose() {
    _nombreCtrl.removeListener(_onNombreChanged);
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioCompraCtrl.dispose();
    _stockCtrl.dispose();
    _marcaCtrl.dispose();
    _categoriaSearchCtrl.dispose();
    super.dispose();
  }

  // ── Listener ─────────────────────────────────────────────────────────────

  void _onNombreChanged() {
    final val = _nombreCtrl.text;
    setState(() {
      _nombreHasDigit = RegExp(r'\d').hasMatch(val);
      _nombreOnlyPunctuation = val.isNotEmpty && _kOnlyPunctuation.hasMatch(val);
      _nombreTooShort = val.isNotEmpty && val.length < _kNombreMinLen;
      _nombreTooLong = val.length > _kNombreMaxLen;
      if (_nombreDuplicado) _nombreDuplicado = false;
    });
  }

  // ── Validators ───────────────────────────────────────────────────────────

  String? _validateNombre(String? val) {
    final v = (val ?? '').trim();
    if (v.isEmpty) return 'El nombre es obligatorio.';
    if (_nombreHasDigit) return 'Este campo solo permite letras.';
    if (_nombreOnlyPunctuation) return 'No se permiten solo signos de puntuación.';
    if (_nombreTooShort) return 'Debe tener al menos $_kNombreMinLen caracteres.';
    if (_nombreTooLong) return 'Máximo $_kNombreMaxLen caracteres.';
    if (_nombreDuplicado) return 'Ya existe un producto con ese nombre.';
    return null;
  }

  String? _validarNumero(String? v) {
    if (v == null || v.isEmpty) return 'Requerido';
    if (double.tryParse(v) == null) return 'Número inválido';
    return null;
  }

  String? _validarEntero(String? v) {
    if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
      return 'Entero inválido';
    }
    return null;
  }

  // ── Categorías ───────────────────────────────────────────────────────────

  Future<void> _cargarCategorias() async {
    try {
      final cats = await _service.getCategorias();
      if (mounted) {
        setState(() {
          _categorias = cats;
          _categoriasFiltradas = cats;
          if (_selectedCategoriaId == null && cats.isNotEmpty) {
            _selectedCategoriaId = cats.first.id;
            _selectedCategoriaNombre = cats.first.nombre;
          } else if (_selectedCategoriaId != null) {
            final existe = cats.any((c) => c.id == _selectedCategoriaId);
            if (!existe && cats.isNotEmpty) {
              _selectedCategoriaId = cats.first.id;
              _selectedCategoriaNombre = cats.first.nombre;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cargar categorías: $e');
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imagenFile = picked;
        _imageBytesPreview = bytes;
      });
    }
  }

  Future<void> _mostrarSelectorCategoria() async {
    _categoriaSearchCtrl.clear();
    _categoriasFiltradas = List.from(_categorias);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.85,
              minChildSize: 0.4,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.grey,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        'Seleccionar Categoría',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _categoriaSearchCtrl,
                        style: const TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar categoría...',
                          hintStyle: const TextStyle(color: AppColors.grey),
                          prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                          filled: true,
                          fillColor: AppColors.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        onChanged: (q) {
                          setModalState(() {
                            _categoriasFiltradas = _categorias
                                .where((c) => c.nombre
                                    .toLowerCase()
                                    .contains(q.toLowerCase()))
                                .toList();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: _categoriasFiltradas.length,
                          itemBuilder: (_, i) {
                            final cat = _categoriasFiltradas[i];
                            final isSelected = cat.id == _selectedCategoriaId;
                            return ListTile(
                              title: Text(
                                cat.nombre,
                                style: TextStyle(
                                  color: isSelected ? AppColors.gold : AppColors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: AppColors.gold, size: 20)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedCategoriaId = cat.id;
                                  _selectedCategoriaNombre = cat.nombre;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    // Validar nombre duplicado antes de disparar el Form
    final nombreTrimmed = _nombreCtrl.text.trim().toLowerCase();
    final existe = widget.productosExistentes.any((p) {
      if (!_isNew && p.id == widget.producto?.id) return false;
      return p.nombre.trim().toLowerCase() == nombreTrimmed;
    });
    if (existe) {
      setState(() => _nombreDuplicado = true);
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoriaId == null) {
      AppToast.showError(context, 'Selecciona una categoría');
      return;
    }

    setState(() => _loading = true);
    try {
      String? imagenFinal = _imagenUrl;
      if (_imagenFile != null && _imageBytesPreview != null) {
        imagenFinal = await _mediaService.subirImagen(
          _imagenFile!.path,
          imageBytes: _imageBytesPreview,
          fileName: _imagenFile!.name,
        );
      }

      final stock = int.tryParse(_stockCtrl.text) ?? 0;
      final cat = _categorias.firstWhere((c) => c.id == _selectedCategoriaId);

      final p = Producto(
        id: widget.producto?.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        categoriaId: cat.id ?? 0,
        categoria: cat,
        precioVenta: double.tryParse(_precioVentaCtrl.text) ?? 0,
        precioCompra: double.tryParse(_precioCompraCtrl.text) ?? 0,
        cantidad: stock,
        marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
        activo: widget.producto?.activo ?? true,
        imagenProduc: imagenFinal,
      );

      if (_isNew) {
        await _service.createProducto(p);
      } else {
        await _service.updateProducto(p);
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          _isNew ? 'Producto creado correctamente' : 'Producto actualizado',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, limpiarError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int nombreLen = _nombreCtrl.text.length;
    final bool nombreNearLimit = !_nombreTooLong && nombreLen >= _kNombreMaxLen - 3;

    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: Text(
            _isNew ? 'Nuevo Producto' : 'Editar Producto',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Imagen ──────────────────────────────────────────────
                _buildImagePicker(),
                const SizedBox(height: 24),

                // ── Nombre ──────────────────────────────────────────────
                TextFormField(
                  controller: _nombreCtrl,
                  maxLength: _kNombreMaxLen,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) {
                    final color = _nombreTooLong
                        ? Colors.red
                        : nombreNearLimit
                            ? const Color(0xFFC9A96E)
                            : Colors.grey;
                    return Text(
                      '$currentLength/$_kNombreMaxLen',
                      style: TextStyle(fontSize: 11, color: color),
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'Nombre *',
                    labelStyle: const TextStyle(color: AppColors.grey),
                    helperText: 'Mínimo $_kNombreMinLen, máximo $_kNombreMaxLen caracteres',
                    helperStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  style: const TextStyle(color: AppColors.white),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\d')),
                  ],
                  validator: _validateNombre,
                  onChanged: (_) {
                    if (_nombreDuplicado) setState(() => _nombreDuplicado = false);
                  },
                ),
                const SizedBox(height: 16),

                // ── Categoría (buscador + selector) ─────────────────────
                _buildCategoriaSelector(),
                const SizedBox(height: 16),

                // ── Campos solo en edición ───────────────────────────────
                if (!_isNew) ...[
                  _sectionLabel('Precios'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _field(
                        controller: _precioVentaCtrl,
                        label: 'Precio Venta (\$)',
                        keyboard: TextInputType.number,
                        validator: _validarNumero,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _field(
                        controller: _precioCompraCtrl,
                        label: 'Precio Compra (\$)',
                        keyboard: TextInputType.number,
                        validator: _validarNumero,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _sectionLabel('Stock'),
                  const SizedBox(height: 10),
                  _field(
                    controller: _stockCtrl,
                    label: 'Stock',
                    keyboard: TextInputType.number,
                    validator: _validarEntero,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Marca ───────────────────────────────────────────────
                _field(
                  controller: _marcaCtrl,
                  label: 'Marca (opcional)',
                ),
                const SizedBox(height: 16),

                // ── Descripción ─────────────────────────────────────────
                _field(
                  controller: _descripcionCtrl,
                  label: 'Descripción (opcional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // ── Botón ───────────────────────────────────────────────
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 54,
                    child: GestureDetector(
                      onTap: _loading ? null : _guardar,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: _loading
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    AppColors.goldDeep,
                                    AppColors.goldMid,
                                    AppColors.goldLight,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _loading ? AppColors.surface : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _loading
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: AppColors.gold, strokeWidth: 2.5),
                                )
                              : Text(
                                  _isNew ? 'Crear' : 'Guardar Cambios',
                                  style: const TextStyle(
                                    color: AppColors.bg,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
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

  // ── Selector de categoría ─────────────────────────────────────────────────

  Widget _buildCategoriaSelector() {
    return GestureDetector(
      onTap: _mostrarSelectorCategoria,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCategoriaNombre ?? 'Seleccionar categoría *',
                style: TextStyle(
                  color: _selectedCategoriaNombre != null
                      ? AppColors.white
                      : AppColors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.search, color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.gold,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 0.6,
      ),
    );
  }

  InputDecoration _inputDeco(String label, {bool filled = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.grey),
      filled: true,
      fillColor: filled ? AppColors.surface : AppColors.inputBg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    bool filled = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      readOnly: readOnly,
      maxLines: maxLines,
      style: TextStyle(
        color: readOnly ? AppColors.grey : AppColors.white,
      ),
      decoration: _inputDeco(label, filled: filled || readOnly),
      validator: validator,
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 170,
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: _imageBytesPreview != null
                ? Image.memory(_imageBytesPreview!, fit: BoxFit.cover)
                : (_imagenUrl?.isNotEmpty ?? false)
                    ? Image.network(_imagenUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder())
                    : _imagePlaceholder(),
          ),
        ),
        if (_imageBytesPreview != null || (_imagenUrl?.isNotEmpty ?? false))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _imagenFile = null;
                _imageBytesPreview = null;
                _imagenUrl = null;
              }),
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.red, size: 18),
              label: const Text('Quitar imagen',
                  style: TextStyle(color: AppColors.red, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(Icons.add, size: 38, color: AppColors.grey),
    );
  }
}
