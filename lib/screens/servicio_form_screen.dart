import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/servicio.dart';
import '../services/auxiliar_service.dart';
import '../utils/app_snackbar.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';

class ServicioFormScreen extends StatefulWidget {
  final Servicio? servicio;

  const ServicioFormScreen({super.key, this.servicio});

  @override
  State<ServicioFormScreen> createState() => _ServicioFormScreenState();
}

class _ServicioFormScreenState extends State<ServicioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();
  
  final AuxiliarService _data = AuxiliarService();
  bool _loading = false;
  bool _isNew = true;
  String? _imagenUrl;
  XFile? _imagenFile;
  Uint8List? _imageBytesPreview;

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
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _duracionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      String? imagenFinal = _imagenUrl;
      if (_imagenFile != null && _imageBytesPreview != null) {
        imagenFinal = await _data.subirImagen(
          _imagenFile!.path, 
          imageBytes: _imageBytesPreview, 
          fileName: _imagenFile!.name
        );
      }

      final s = Servicio(
        id: widget.servicio?.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        precio: double.parse(_precioCtrl.text),
        duracionMinutos: int.parse(_duracionCtrl.text),
        estado: widget.servicio?.estado ?? true,
        imagen: imagenFinal,
      );

      if (_isNew) {
        await _data.crearServicio(s);
      } else {
        await _data.actualizarServicio(s);
      }

      if (mounted) {
        AppToast.showSuccess(context, _isNew ? '✅ Servicio creado' : '✅ Servicio actualizado');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(title: Text(_isNew ? 'Nuevo Servicio' : 'Editar Servicio')),
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
                  validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _precioCtrl,
                        decoration: const InputDecoration(labelText: 'Precio (\$)', border: OutlineInputBorder()),
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
                        controller: _duracionCtrl,
                        decoration: const InputDecoration(labelText: 'Duración (min)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Requerido';
                          if (int.tryParse(val) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loading ? null : _guardar,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar Servicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
