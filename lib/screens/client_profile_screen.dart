import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../services/auth_service.dart';
import '../services/auxiliar_service.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _auxiliarService = AuxiliarService();

  Cliente? _clienteActual;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _documentoEditable = true;
  final _documentoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Widget _buildProfileForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Datos del Cliente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _documentoCtrl,
              readOnly: !_documentoEditable,
              decoration: InputDecoration(
                labelText: _documentoEditable ? 'Documento *' : 'Documento (Protegido)',
                border: const OutlineInputBorder(),
                filled: !_documentoEditable,
                fillColor: _documentoEditable ? null : Colors.grey.withOpacity(0.1),
                helperText: _documentoEditable ? 'Ingresa tu documento oficial' : 'Este campo no se puede modificar',
              ),
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El documento es obligatorio';
                }
                if (value.length > 15) {
                  return 'Máximo 15 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                if (value.length > 40) {
                  return 'Máximo 40 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apellidoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellido *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El apellido es obligatorio';
                }
                if (value.length > 40) {
                  return 'Máximo 40 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length > 12) {
                  return 'Máximo 12 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty && !value.contains('@')) {
                  return 'Email no válido';
                }
                if (value != null && value.length > 40) {
                  return 'Máximo 40 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value != null && value.length > 80) {
                  return 'Máximo 80 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarPerfil,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _authService.signOut();
                  if (mounted) Navigator.pushReplacementNamed(context, '/');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _documentoCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseUser = _authService.currentUser;
      final correo = firebaseUser?.email;

      if (correo == null) {
        throw Exception('No se pudo obtener el correo del usuario actual.');
      }

      final clientes = await _auxiliarService.obtenerClientes();
      Cliente? encontrado;

      try {
        encontrado = clientes.firstWhere(
          (c) => (c.email ?? '').toLowerCase() == correo.toLowerCase(),
        );
      } catch (_) {
        encontrado = null;
      }

      _clienteActual = encontrado;

      _documentoCtrl.text = encontrado?.documento ?? '';
      _nombreCtrl.text = encontrado?.nombre ?? '';
      _apellidoCtrl.text = encontrado?.apellido ?? '';
      _telefonoCtrl.text = encontrado?.telefono ?? '';
      _emailCtrl.text = encontrado?.email ?? correo;
      _direccionCtrl.text = encontrado?.direccion ?? '';

      // Si el documento es nulo, vacío o empieza con TMP/G-, permitimos editarlo una vez.
      final docActual = _documentoCtrl.text;
      _documentoEditable = docActual.isEmpty || 
                           docActual.startsWith('TMP') || 
                           docActual.startsWith('G-');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar perfil de cliente: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final cliente = Cliente(
        id: _clienteActual?.id,
        documento: _documentoCtrl.text.trim(),
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        estado: true,
      );

      Cliente guardado;
      if (_clienteActual == null || _clienteActual!.id == null) {
        guardado = await _auxiliarService.crearCliente(cliente);
      } else {
        guardado = await _auxiliarService.actualizarCliente(cliente);
      }

      _clienteActual = guardado;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.client,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Perfil'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildProfileForm(),
      ),
    );
  }
}


