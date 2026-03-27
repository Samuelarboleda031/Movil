import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/app_role.dart';
import '../models/usuario.dart';
import '../models/cliente.dart';
import '../models/barbero.dart';
import '../services/cliente_service.dart';
import '../services/barbero_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscureText = true;

  // AppRole _selectedRole = AppRole.client; // YA NO SE USA MANUALMENTE

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _homeRouteForRole(AppRole role) {
    switch (role) {
      case AppRole.manager:
      case AppRole.admin:
        return '/main-admin';
      case AppRole.barber:
        return '/main-barber';
      case AppRole.client:
        return '/main-client';
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await _auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      await _verificarAccesoYRedirigir();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Error en autenticación');
    } catch (e) {
      _showMessage('Error inesperado');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) {
        await _verificarAccesoYRedirigir();
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Error en autenticación con Google');
    } catch (e) {
      _showMessage('Error inesperado con Google');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _verificarAccesoYRedirigir() async {
    final firebaseUser = _auth.currentUser;
    final emailActual = firebaseUser?.email ?? '(sin correo)';
    
    print('[Login] Verificando acceso para $emailActual...');

    Usuario? usuarioApi = await _auth.fetchUsuarioDesdeApi();

    // Fallback a datos cacheados
    if (usuarioApi == null && firebaseUser?.email != null) {
      final cached = await _auth.getCurrentUser();
      if (cached != null && cached.correo.toLowerCase() == firebaseUser!.email!.toLowerCase()) {
        usuarioApi = cached;
      }
    }

    if (usuarioApi == null) {
      // Si el usuario no existe (nueva cuenta Google), por defecto es CLIENTE (rolId: 3)
      print('[Login] Usuario no encontrado. Registrando como Cliente por defecto.');
      usuarioApi = await _auth.syncUsuarioConApi(rolId: 3); // 3 = Cliente
    }

    if (usuarioApi == null || usuarioApi.rolId == null) {
      _showMessage('No fue posible validar tu rol. Contacta al administrador.');
      await _auth.signOut();
      return;
    }

    final AppRole role = roleForRolId(usuarioApi.rolId) ?? AppRole.client;
    print('[Login] Ingresando con rol: ${roleLabel(role)}');

    // --- AUTO-CREACIÓN DE PERFILES ---
    try {
      if (role == AppRole.client) {
        final clienteService = ClienteService();
        final clienteExistente = await clienteService.obtenerClientePorUsuarioId(usuarioApi.id!);
        if (clienteExistente == null) {
          final nuevoCliente = Cliente(
            documento: 'G-${DateTime.now().millisecondsSinceEpoch}',
            nombre: firebaseUser?.displayName?.split(' ').first ?? 'Usuario',
            apellido: firebaseUser?.displayName?.split(' ').skip(1).join(' ') ?? 'Google',
            email: usuarioApi.correo,
            fotoPerfil: firebaseUser?.photoURL, // Añadir foto de perfil
            usuarioId: usuarioApi.id,
            estado: true,
          );
          await clienteService.crearCliente(nuevoCliente);
        }
      } else if (role == AppRole.barber) {
        final barberoService = BarberoService();
        final barberoExistente = await barberoService.obtenerBarberoPorUsuarioId(usuarioApi.id!);
        if (barberoExistente == null) {
          final nuevoBarbero = Barbero(
            documento: 'G-${DateTime.now().millisecondsSinceEpoch}',
            nombre: firebaseUser?.displayName?.split(' ').first ?? 'Barbero',
            apellido: firebaseUser?.displayName?.split(' ').skip(1).join(' ') ?? 'Google',
            email: usuarioApi.correo,
            fotoPerfil: firebaseUser?.photoURL, // Añadir foto de perfil si tu modelo lo tiene
            usuarioId: usuarioApi.id,
            estado: true,
            fechaIngreso: DateTime.now().toIso8601String().split('T').first, 
          );
          await barberoService.crearBarbero(nuevoBarbero);
        }
      }
    } catch (e) {
      print('[Login] Error en auto-creación: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, _homeRouteForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              const Color(0xFFD8B081).withOpacity(0.05),
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Circular
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD8B081).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                    border: Border.all(color: const Color(0xFFD8B081).withOpacity(0.3), width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/Manito.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'MANITO BARBERSHOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: const Color(0xFFD8B081).withOpacity(0.8),
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 48),

                // Formulario
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscureText,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: Color(0xFFD8B081)),
                    ),
                  ),
                ),
                // Botones
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 8,
                      shadowColor: const Color(0xFFD8B081).withOpacity(0.4),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

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

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _googleLogin,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png', height: 20),
                    label: const Text('Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: RichText(
                    text: const TextSpan(
                      text: '¿No tienes una cuenta? ',
                      style: TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                          text: 'Regístrate aquí',
                          style: TextStyle(color: Color(0xFFD8B081), fontWeight: FontWeight.bold),
                        ),
                      ],
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

