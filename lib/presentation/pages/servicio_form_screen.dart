import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/datasources/media_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';

// ─── Constantes de validación (espejo del web) ───────────────────────────────
const int _kNombreMinLen = 2;
const int _kNombreMaxLen = 18;
const int _kPrecioMaxDigits = 15;
const int _kImagenMaxMb = 5;
const List<String> _kAllowedMimeTypes = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
];
// Extensiones permitidas derivadas de los MIME anteriores
const List<String> _kAllowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

// Regex: solo puntuación, sin ninguna letra (igual que el web)
final RegExp _kOnlyPunctuation =
    RegExp(r'^[^a-zA-ZáéíóúÁÉÍÓÚüÜñÑ]+$');

class ServicioFormScreen extends StatefulWidget {
  final Servicio? servicio;
  /// Lista de servicios existentes para validar nombre duplicado
  final List<Servicio> serviciosExistentes;

  const ServicioFormScreen({
    super.key,
    this.servicio,
    this.serviciosExistentes = const [],
  });

  @override
  State<ServicioFormScreen> createState() => _ServicioFormScreenState();
}

class _ServicioFormScreenState extends State<ServicioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();

  final MediaService _mediaService = MediaService();
  final ServicioService _servicioService = ServicioService();

  bool _loading = false;
  bool _isNew = true;

  // Imagen
  String? _imagenUrl;
  XFile? _imagenFile;
  Uint8List? _imageBytesPreview;
  String? _imageError;

  // ── Validación de nombre en tiempo real ──────────────────────────────────
  bool _nombreHasDigit = false;
  bool _nombreOnlyPunctuation = false;
  bool _nombreTooShort = false;
  bool _nombreTooLong = false;
  bool _nombreDuplicado = false;

  // ── Validación de precio en tiempo real ──────────────────────────────────
  bool _precioInvalid = false;

  // ── Validación de duración en tiempo real ────────────────────────────────
  bool _duracionInvalid = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.servicio == null;
    if (!_isNew) {
      _nombreCtrl.text = widget.servicio!.nombre;
      _descripcionCtrl.text = widget.servicio!.descripcion ?? '';
      _precioCtrl.text = widget.servicio!.precio.toString();
      _duracionCtrl.text = widget.servicio!.duracionMinutos.toString();
      _imagenUrl = widget.servicio!.imagen;
    }

    _nombreCtrl.addListener(_onNombreChanged);
    _precioCtrl.addListener(_onPrecioChanged);
    _duracionCtrl.addListener(_onDuracionChanged);
  }

  @override
  void dispose() {
    _nombreCtrl.removeListener(_onNombreChanged);
    _precioCtrl.removeListener(_onPrecioChanged);
    _duracionCtrl.removeListener(_onDuracionChanged);
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _duracionCtrl.dispose();
    super.dispose();
  }

  // ── Listeners ────────────────────────────────────────────────────────────

  void _onNombreChanged() {
    final val = _nombreCtrl.text;
    setState(() {
      _nombreHasDigit = RegExp(r'\d').hasMatch(val);
      _nombreOnlyPunctuation = val.isNotEmpty && _kOnlyPunctuation.hasMatch(val);
      _nombreTooShort = val.isNotEmpty && val.length < _kNombreMinLen;
      _nombreTooLong = val.length > _kNombreMaxLen;
      // Limpiar duplicado al editar
      if (_nombreDuplicado) _nombreDuplicado = false;
    });
  }

  void _onPrecioChanged() {
    final val = _precioCtrl.text.trim();
    final parsed = double.tryParse(val);
    setState(() {
      _precioInvalid = val.isNotEmpty && (parsed == null || parsed <= 0);
    });
  }

  void _onDuracionChanged() {
    final val = _duracionCtrl.text.trim();
    final parsed = int.tryParse(val);

    // Clamp automático a 600 min (10 h)
    if (parsed != null && parsed > 600) {
      _duracionCtrl.value = _duracionCtrl.value.copyWith(
        text: '600',
        selection: const TextSelection.collapsed(offset: 3),
      );
      return;
    }

    setState(() {
      _duracionInvalid = val.isNotEmpty && (parsed == null || parsed <= 0);
    });
  }

  // ── Imagen ───────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    // Validar extensión
    final ext = image.name.split('.').last.toLowerCase();
    if (!_kAllowedExtensions.contains(ext)) {
      setState(() {
        _imageError = 'Formato no válido. Solo JPG, PNG, GIF o WEBP.';
      });
      return;
    }

    final bytes = await image.readAsBytes();

    // Validar tamaño (5 MB)
    if (bytes.length > _kImagenMaxMb * 1024 * 1024) {
      setState(() {
        _imageError = 'La imagen no debe superar los $_kImagenMaxMb MB.';
      });
      return;
    }

    setState(() {
      _imagenFile = image;
      _imageBytesPreview = bytes;
      _imageError = null;
    });
  }

  void _removeImage() {
    setState(() {
      _imagenFile = null;
      _imageBytesPreview = null;
      _imagenUrl = null;
      _imageError = null;
    });
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    // Disparar validadores del Form
    if (!_formKey.currentState!.validate()) return;

    // Validar nombre duplicado (case-insensitive, excluyendo el propio al editar)
    final nombreTrimmed = _nombreCtrl.text.trim().toLowerCase();
    final existe = widget.serviciosExistentes.any((s) {
      if (!_isNew && s.id == widget.servicio?.id) return false;
      return (s.nombre).trim().toLowerCase() == nombreTrimmed;
    });
    if (existe) {
      setState(() => _nombreDuplicado = true);
      _formKey.currentState!.validate(); // re-render para mostrar el error
      return;
    }

    setState(() {
      _loading = true;
      _nombreDuplicado = false;
    });

    try {
      String? imagenFinal = _imagenUrl;
      if (_imagenFile != null && _imageBytesPreview != null) {
        imagenFinal = await _mediaService.subirImagen(
          _imagenFile!.path,
          imageBytes: _imageBytesPreview,
          fileName: _imagenFile!.name,
        );
      }

      final s = Servicio(
        id: widget.servicio?.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        precio: double.parse(_precioCtrl.text.trim()),
        duracionMinutos: int.parse(_duracionCtrl.text.trim()),
        estado: widget.servicio?.estado ?? true,
        imagen: imagenFinal,
      );

      if (_isNew) {
        await _servicioService.crearServicio(s);
      } else {
        await _servicioService.actualizarServicio(s);
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          _isNew ? '✅ Servicio creado' : '✅ Servicio actualizado',
        );
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

  // ── Helpers de UI ────────────────────────────────────────────────────────

  /// Devuelve el mensaje de error del nombre o null si está bien.
  String? _validateNombre(String? val) {
    final v = (val ?? '').trim();
    if (v.isEmpty) return 'El nombre es obligatorio.';
    if (_nombreHasDigit) return 'Este campo solo permite letras.';
    if (_nombreOnlyPunctuation) return 'No se permiten solo signos de puntuación.';
    if (_nombreTooShort) return 'Debe tener al menos $_kNombreMinLen caracteres.';
    if (_nombreTooLong) return 'Máximo $_kNombreMaxLen caracteres.';
    if (_nombreDuplicado) return 'Ya existe un servicio con ese nombre.';
    return null;
  }

  String? _validatePrecio(String? val) {
    final v = (val ?? '').trim();
    if (v.isEmpty) return 'El precio es obligatorio.';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Ingresa un número válido.';
    if (parsed <= 0) return 'El precio debe ser mayor a cero.';
    return null;
  }

  String? _validateDuracion(String? val) {
    final v = (val ?? '').trim();
    if (v.isEmpty) return 'La duración es obligatoria.';
    final parsed = int.tryParse(v);
    if (parsed == null) return 'Ingresa un número entero válido.';
    if (parsed <= 0) return 'La duración debe ser mayor a 0.';
    if (parsed > 600) return 'La duración no puede superar las 10 horas (600 min).';
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int nombreLen = _nombreCtrl.text.length;
    final bool nombreNearLimit =
        !_nombreTooLong && nombreLen >= _kNombreMaxLen - 3;

    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Nuevo Servicio' : 'Editar Servicio'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Nombre ──────────────────────────────────────────────
                TextFormField(
                  controller: _nombreCtrl,
                  maxLength: _kNombreMaxLen,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) {
                    // Contador personalizado con color de advertencia
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
                    labelText: 'Nombre del Servicio *',
                    hintText: 'Ej: Corte Moderno',
                    border: const OutlineInputBorder(),
                    helperText: 'Mínimo $_kNombreMinLen, máximo $_kNombreMaxLen caracteres',
                    helperStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    // Bloquear dígitos en tiempo real
                    FilteringTextInputFormatter.deny(RegExp(r'\d')),
                  ],
                  validator: _validateNombre,
                  onChanged: (_) {
                    // Forzar re-validación visual si ya se intentó guardar
                    if (_nombreDuplicado) setState(() => _nombreDuplicado = false);
                  },
                ),

                // ── Imagen ──────────────────────────────────────────────
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
                                  Icon(Icons.add_a_photo,
                                      size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Añadir imagen (Opcional)',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                  ),
                ),
                // Hint de restricciones de imagen
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: Color(0xFFC9A96E)),
                      const SizedBox(width: 4),
                      Text(
                        'Máx. $_kImagenMaxMb MB · JPG, PNG, GIF, WEBP',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_imageError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Text(
                      _imageError!,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.red),
                    ),
                  ),
                if (_imageBytesPreview != null ||
                    (_imagenUrl != null && _imagenUrl!.isNotEmpty))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Quitar imagen',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),

                // ── Descripción (opcional) ───────────────────────────────
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Describe el servicio detalladamente',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                // ── Precio y Duración ────────────────────────────────────
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Precio
                    Expanded(
                      child: TextFormField(
                        controller: _precioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Precio (\$) *',
                          hintText: 'Ej: 25000',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          // Máximo 15 dígitos (igual que el web)
                          LengthLimitingTextInputFormatter(_kPrecioMaxDigits),
                          // Solo números y un punto decimal
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: _validatePrecio,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Duración
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _duracionCtrl,
                        builder: (_, v, __) {
                          final mins = int.tryParse(v.text) ?? 0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _duracionCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Duración (min) *',
                                  hintText: 'Ej: 30',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: _validateDuracion,
                              ),
                              // Preview de duración formateada (igual que el web)
                              if (mins > 0)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 4, left: 4),
                                  child: Text(
                                    '= ${AppFormat.duracion(mins)}',
                                    style: const TextStyle(
                                      color: Color(0xFFC9A96E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // ── Botón Guardar ────────────────────────────────────────
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _loading ? null : _guardar,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF9A7040),
                          Color(0xFFC9A96E),
                          Color(0xFFE0C080),
                        ],
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
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF111111),
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Guardar Servicio',
                              style: TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
}
