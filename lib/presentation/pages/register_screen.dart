import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emailConfirmCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _auth = AuthService();
  final _clienteService = ClienteService();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscurePassConfirm = true;
  final AppRole _selectedRole = AppRole.client; // Todos los registros de la app móvil son Clientes por defecto

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _documentoCtrl.dispose();
    _emailCtrl.dispose();
    _emailConfirmCtrl.dispose();
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
    final documento = _documentoCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final emailConf = _emailConfirmCtrl.text.trim();
    final pass = _passCtrl.text;
    final passConf = _passConfirmCtrl.text;

    if (nombre.isEmpty || apellido.isEmpty || documento.isEmpty || email.isEmpty || pass.isEmpty) {
      _showMessage('Complete todos los campos obligatorios');
      return;
    }

    // Validación de email
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Ingresa un correo electrónico válido');
      return;
    }

    if (emailConf.isEmpty) {
      _showMessage('Confirma tu correo electrónico');
      return;
    }
    if (email != emailConf) {
      _showMessage('Los correos no coinciden');
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
      
      // Sincronizar el usuario con la API incluyendo nombre, apellido y documento
      final usuarioApi = await _auth.syncUsuarioConApi(
        rolId: rolIdForRole(_selectedRole),
        contrasena: pass,
        additionalData: {
          'nombre': nombre,
          'apellido': apellido,
          'documento': documento,
          'tipoDocumento': 'CC',
          'telefono': '0000000000', // Valor por defecto ya que no se pide en el form móvil aún
        },
      );

      if (usuarioApi == null || usuarioApi.id == null) {
        // ROLLBACK: Eliminar el usuario de Firebase si la API falla
        try {
          await FirebaseAuth.instance.currentUser?.delete();
        } catch (rollbackError) {
          print('Error en rollback de Firebase: $rollbackError');
        }
        throw Exception('No se pudo vincular tu cuenta con el sistema. Intenta nuevamente.');
      }

      // Crear registro de cliente con los datos reales
      final cliente = Cliente(
        documento: documento,
        nombre: nombre,
        apellido: apellido,
        email: email,
        usuarioId: usuarioApi.id,
        estado: true,
      );
      
      try {
        await _clienteService.crearCliente(cliente);
      } catch (e) {
        print('Error creando perfil de cliente: $e');
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
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _apellidoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellido *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _documentoCtrl,
              decoration: const InputDecoration(
                labelText: 'Documento / Cédula *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico *',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailConfirmCtrl,
              decoration: const InputDecoration(
                labelText: 'Confirmar Correo',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
                helperText: 'Mínimo 6 caracteres, una mayúscula y un número',
                helperStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePass = !_obscurePass);
                  },
                ),
              ),
              obscureText: _obscurePass,
              style: const TextStyle(color: Colors.white),
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
              ),
              obscureText: _obscurePassConfirm,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
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
