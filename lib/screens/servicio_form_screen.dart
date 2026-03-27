import 'package:flutter/material.dart';
import '../models/servicio.dart';
import '../services/auxiliar_service.dart';
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

  @override
  void initState() {
    super.initState();
    _isNew = widget.servicio == null;
    if (!_isNew) {
      _nombreCtrl.text = widget.servicio!.nombre;
      _descripcionCtrl.text = widget.servicio!.descripcion ?? '';
      _precioCtrl.text = widget.servicio!.precio.toString();
      _duracionCtrl.text = widget.servicio!.duracionMinutos.toString();
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
      final s = Servicio(
        id: widget.servicio?.id,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        precio: double.parse(_precioCtrl.text),
        duracionMinutos: int.parse(_duracionCtrl.text),
        estado: widget.servicio?.estado ?? true,
      );

      if (_isNew) {
        await _data.crearServicio(s);
      } else {
        await _data.actualizarServicio(s);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? 'Servicio creado' : 'Servicio actualizado'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
