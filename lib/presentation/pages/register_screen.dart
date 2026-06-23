import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/logger.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _auth = AuthService();
  final _clienteService = ClienteService();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscurePassConfirm = true;
  List<String> _emailErrors = [];
  String? _emailDuplicadoError; // "Este correo ya está registrado" (verificación en vivo)
  Timer? _emailDebounce;
  String? _nombreError;
  String? _apellidoError;
  List<String> _passErrors = [];
  String? _passConfirmError;
  final AppRole _selectedRole = AppRole.client;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_validarEmail);
    _nombreCtrl.addListener(_validarNombre);
    _apellidoCtrl.addListener(_validarApellido);
    _passCtrl.addListener(_validarPass);
    _passConfirmCtrl.addListener(_validarPassConfirm);
  }

  void _validarPass() {
    final pass = _passCtrl.text;
    final List<String> errors = [];

    if (pass.isEmpty) {
      errors.add('El campo es obligatorio');
    } else {
      if (pass.length < 8) {
        errors.add('Mínimo 8 caracteres');
      }
      if (pass.length > 50) {
        errors.add('Máximo 50 caracteres');
      }
      if (!pass.contains(RegExp(r'[A-Z]'))) {
        errors.add('Al menos una letra mayúscula');
      }
      if (!pass.contains(RegExp(r'[a-z]'))) {
        errors.add('Al menos una letra minúscula');
      }
      if (!pass.contains(RegExp(r'[0-9]'))) {
        errors.add('Al menos un número');
      }
    }

    setState(() {
      _passErrors = errors;
    });
    // Also validate the confirmation when the password changes
    _validarPassConfirm();
  }

  void _validarPassConfirm() {
    final pass = _passCtrl.text;
    final passConfirm = _passConfirmCtrl.text;
    String? error;

    if (passConfirm.isNotEmpty && pass != passConfirm) {
      error = 'Las contraseñas no coinciden';
    }

    setState(() {
      _passConfirmError = error;
    });
  }

  void _validarNombre() {
    final text = _nombreCtrl.text.trim();
    String? error;
    if (text.isEmpty) {
      error = 'El nombre es obligatorio';
    } else if (text.length < 2) {
      error = 'Mínimo 2 caracteres';
    } else if (text.length > 18) {
      error = 'Máximo 18 caracteres';
    }
    setState(() => _nombreError = error);
  }

  void _validarApellido() {
    final text = _apellidoCtrl.text.trim();
    String? error;
    if (text.isEmpty) {
      error = 'El apellido es obligatorio';
    } else if (text.length < 2) {
      error = 'Mínimo 2 caracteres';
    } else if (text.length > 18) {
      error = 'Máximo 18 caracteres';
    }
    setState(() => _apellidoError = error);
  }

  void _validarEmail() {
    final email = _emailCtrl.text;
    final List<String> errors = [];

    if (email.isEmpty) {
      errors.add('El correo es obligatorio');
    } else {
      if (email.length < 5) {
        errors.add('Mínimo 5 caracteres');
      }
      if (email.length > 154) {
        errors.add('Máximo 154 caracteres');
      }
      if (email.contains(' ')) {
        errors.add('Sin espacios');
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        errors.add('Formato de correo inválido');
      }
    }

    setState(() {
      _emailErrors = errors;
    });

    // Verificación en tiempo real contra el backend (igual que en Front4).
    // Solo se consulta cuando el formato es válido, con debounce para no
    // disparar una petición por cada tecla.
    _emailDebounce?.cancel();
    if (errors.isEmpty && email.trim().isNotEmpty) {
      _emailDebounce = Timer(const Duration(milliseconds: 500), () {
        _verificarEmailExiste(email.trim());
      });
    } else if (_emailDuplicadoError != null) {
      setState(() => _emailDuplicadoError = null);
    }
  }

  Future<void> _verificarEmailExiste(String email) async {
    final existe = await _auth.existeEmail(email);
    if (!mounted) return;
    // Evita condiciones de carrera: solo aplica si el correo no cambió mientras
    // esperábamos la respuesta.
    if (_emailCtrl.text.trim() != email) return;
    setState(() {
      _emailDuplicadoError = existe ? 'Este correo ya está registrado' : null;
    });
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailCtrl.removeListener(_validarEmail);
    _nombreCtrl.removeListener(_validarNombre);
    _apellidoCtrl.removeListener(_validarApellido);
    _passCtrl.removeListener(_validarPass);
    _passConfirmCtrl.removeListener(_validarPassConfirm);
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = true}) {
    if (!mounted) return;
    if (isError) {
      AppToast.showError(context, msg);
    } else {
      AppToast.showSuccess(context, msg);
    }
  }

  Future<void> _register() async {
    final nombre = _nombreCtrl.text.trim();
    final apellido = _apellidoCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final passConf = _passConfirmCtrl.text;

    if (nombre.isEmpty || apellido.isEmpty || email.isEmpty || pass.isEmpty) {
      _showMessage('Complete todos los campos obligatorios');
      return;
    }

    // Validación de email
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Ingresa un correo electrónico válido');
      return;
    }

    if (_emailDuplicadoError != null) {
      _showMessage('Este correo ya está registrado. Intenta iniciar sesión.');
      return;
    }

    // Validaciones de contraseña (igual que en la web)
    if (pass.length < 6) {
      _showMessage('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(pass)) {
      _showMessage('La contraseña debe incluir al menos un número');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(pass)) {
      _showMessage('La contraseña debe incluir al menos una mayúscula');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(pass)) {
      _showMessage('La contraseña debe incluir al menos una minúscula');
      return;
    }

    if (passConf.isEmpty) {
      _showMessage('Confirma tu contraseña');
      return;
    }
    if (pass != passConf) {
      _showMessage('Las contraseñas no coinciden');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.signUp(email, pass);
      
      // Sincronizar el usuario con la API incluyendo nombre y apellido
      final usuarioApi = await _auth.syncUsuarioConApi(
        rolId: rolIdForRole(_selectedRole),
        contrasena: pass,
        additionalData: {
          'nombre': nombre,
          'apellido': apellido,
          'documento': null, // Se deja vacío para completar perfil después
          'tipoDocumento': 'CC',
          'telefono': '0000000000',
        },
      );

      if (usuarioApi == null || usuarioApi.id == null) {
        // ROLLBACK: Eliminar el usuario de Firebase si la API falla
        try {
          await FirebaseAuth.instance.currentUser?.delete();
        } catch (rollbackError) {
          logD('Error en rollback de Firebase: $rollbackError');
        }
        throw Exception('No se pudo vincular tu cuenta con el sistema. Intenta nuevamente.');
      }

      // Crear registro de cliente con los datos reales
      final cliente = Cliente(
        documento: '', // Se deja vacío para completar perfil después
        nombre: nombre,
        apellido: apellido,
        email: email,
        usuarioId: usuarioApi.id,
        estado: true,
      );
      
      try {
        await _clienteService.crearCliente(cliente);
      } catch (e) {
        logD('Error creando perfil de cliente: $e');
      }
      
      await _auth.sendEmailVerification();
      _showMessage('Cuenta creada con éxito. Revisa tu correo para verificar tu cuenta.', isError: false);
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } catch (e) {
      _showMessage('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado. Intenta iniciar sesión.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red e inténtalo de nuevo.';
      default:
        return e.message ?? 'No se pudo completar el registro.';
    }
  }

  Future<void> _googleRegister() async {
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithGoogle();
      if (cred != null && mounted) {
        Navigator.pushReplacementNamed(context, '/main-client');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Error en registro con Google');
    } catch (e) {
      _showMessage('Error inesperado con Google');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('MANITO BARBERSHOP'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crear Cuenta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Únete a la mejor experiencia de barbería',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _nombreError,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _apellidoCtrl,
              decoration: InputDecoration(
                labelText: 'Apellido *',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _apellidoError,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico *',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailErrors.isNotEmpty ? _emailErrors.first : null,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
            ),
            if (_emailErrors.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _emailErrors
                      .skip(1)
                      .map((err) => Text(
                            '• $err',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
            if (_emailDuplicadoError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  _emailDuplicadoError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePass = !_obscurePass);
                  },
                ),
                errorText: _passErrors.isNotEmpty ? _passErrors.first : null,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              obscureText: _obscurePass,
              style: const TextStyle(color: Colors.white),
            ),
            if (_passErrors.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _passErrors
                      .skip(1)
                      .map((err) => Text(
                            '• $err',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _passConfirmCtrl,
              decoration: InputDecoration(
                labelText: 'Confirmar Contraseña',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassConfirm = !_obscurePassConfirm);
                  },
                ),
                errorText: _passConfirmError,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              obscureText: _obscurePassConfirm,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading ||
                        _emailErrors.isNotEmpty ||
                        _emailDuplicadoError != null ||
                        _nombreError != null ||
                        _apellidoError != null ||
                        _passErrors.isNotEmpty ||
                        _passConfirmError != null)
                    ? null
                    : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text('REGISTRARSE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white10)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('o continúa con', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white10)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _googleRegister,
                icon: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                label: const Text('Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
