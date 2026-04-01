import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parte_movil/data/models/usuario.dart';
import 'usuario_service.dart';

class AuthService {
  static const String _userKey = 'user_data';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UsuarioService _usuarioService = UsuarioService();

  // Inicia sesión con correo y contraseña
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Inicia sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // El usuario canceló el inicio de sesión

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  // Registra un nuevo usuario
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Envía correo para restablecer contraseña. Retorna true si se envió correctamente.
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Envia verificación de correo al usuario actual
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Cierra sesión
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    
    try {
      // Solo cerrar sesión de Google si el usuario inició sesión con Google
      if (await _googleSignIn.isSignedIn() == true) {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      }
    } catch (e) {
      // Registrar el error pero continuar con el cierre de sesión de Firebase
      print('Error durante el cierre de sesión de Google: $e');
    }
    
    // Siempre cerrar sesión de Firebase Auth
    await _auth.signOut();
  }

  Future<String?> getToken() async {
    // Por ahora, retornar null ya que no hay autenticación
    return null;
  }

  Future<Usuario?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return Usuario.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    // Por ahora, siempre retornar false ya que no hay autenticación
    return false;
  }

  User? get currentUser => _auth.currentUser;

  // Sincroniza el usuario autenticado de Firebase con la API (tabla Usuarios)
  // rolId: Rol sugerido para usuarios nuevos (ej: 3 para Cliente)
  Future<Usuario?> syncUsuarioConApi({required int rolId, String? contrasena}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    final correo = user.email!;
    final passwordValue = contrasena ?? 'firebase_auth';

    try {
      Usuario? existente = await _usuarioService.obtenerUsuarioPorCorreo(correo);
      Usuario sincronizado;

      if (existente == null) {
        // Extraer nombre y apellido de Google/Firebase
        String nombre = 'Cliente';
        String apellido = 'Nuevo';
        
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          final parts = user.displayName!.split(' ');
          nombre = parts[0];
          if (parts.length > 1) {
            apellido = parts.sublist(1).join(' ');
          }
        }

        // Crear nuevo usuario en la API con el rol sugerido
        final nuevo = Usuario(
          correo: correo,
          nombre: nombre,
          apellido: apellido,
          fotoPerfil: user.photoURL,
          contrasena: passwordValue,
          rolId: rolId,
          estado: true,
        );
        sincronizado = await _usuarioService.crearUsuario(nuevo);
      } else {
       // RESPETAR EL ROL EXISTENTE: Si ya tiene un rol en la API, no lo cambiamos
        // Esto evita que un Admin se convierta en Cliente al loguearse.
        final rolFinal = existente.rolId ?? rolId;
        
        if (existente.rolId != rolFinal || existente.estado != true) {
          final actualizado = Usuario(
            id: existente.id,
            correo: existente.correo,
            contrasena: existente.contrasena ?? passwordValue,
            rolId: rolFinal,
            estado: true,
          );
          sincronizado = await _usuarioService.actualizarUsuario(actualizado);
        } else {
          sincronizado = existente;
        }
      }

      await _saveApiUser(sincronizado);
      return sincronizado;
    } catch (e) {
      print('Error sincronizando usuario con API: $e');
      return null;
    }
  }

  Future<Usuario?> fetchUsuarioDesdeApi() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    try {
      print('[AuthService] Consultando usuario API para ${user.email}');
      final usuario = await _usuarioService.obtenerUsuarioPorCorreo(user.email!);
      if (usuario == null) {
        print('[AuthService] Usuario no encontrado en API para ${user.email}');
      } else {
        print('[AuthService] Usuario encontrado con rolId=${usuario.rolId}');
      }
      if (usuario != null) {
        await _saveApiUser(usuario);
      }
      return usuario;
    } catch (e) {
      print('[AuthService] Error obteniendo usuario desde API: $e');
      return null;
    }
  }

  Future<void> _saveApiUser(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(usuario.toJson()));
  }
}
