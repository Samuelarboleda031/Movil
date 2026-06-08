import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:parte_movil/data/models/usuario.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/core/utils/logger.dart';

class AuthService {
  static const String _userKey = 'user_data';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── USUARIO API METHODS (Merged from UsuarioService) ───────────────────────
  
  Future<List<Usuario>> obtenerUsuarios() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}?pageSize=1000';
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        } else if (rawData is Map && rawData.containsKey('data')) {
           data = rawData['data'];
        } else {
          data = [];
        }
        return data.map((json) => Usuario.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener usuarios: $e');
    }
  }

  Future<Usuario?> obtenerUsuarioPorCorreo(String correo) async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}?q=${Uri.encodeComponent(correo)}&pageSize=10';
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        } else {
          data = [];
        }
        final usuarios = data.map((json) => Usuario.fromJson(json)).toList();
        try {
          return usuarios.firstWhere(
            (u) => u.correo.toLowerCase() == correo.toLowerCase(),
          );
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Usuario> crearUsuario(Usuario usuario) async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(usuario.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Usuario.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear usuario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear usuario: $e');
    }
  }

  Future<Usuario> actualizarUsuario(Usuario usuario) async {
    if (usuario.id == null || usuario.id == 0) {
      throw Exception('No se puede actualizar un usuario sin ID');
    }
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}/${usuario.id}';
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(usuario.toJson()),
      );
      if (response.statusCode == 200) {
        return Usuario.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return usuario;
      } else {
        throw Exception('Error al actualizar usuario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar usuario: $e');
    }
  }

  // ─── AUTH LOGIC ────────────────────────────────────────────────────────────

  // Inicia sesión con correo y contraseña
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Inicia sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      logD('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  // Registra un nuevo usuario
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<({bool success, String? error})> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => 'No existe una cuenta con ese correo electrónico.',
        'invalid-email' => 'El formato del correo electrónico no es válido.',
        'too-many-requests' => 'Demasiados intentos. Intenta de nuevo más tarde.',
        _ => 'Error al enviar el correo de recuperación.',
      };
      return (success: false, error: msg);
    } catch (_) {
      return (success: false, error: 'Error de conexión. Verifica tu internet.');
    }
  }

  /// Sincroniza la nueva contraseña con la API (tabla Usuarios) después de un
  /// reset de Firebase. Debe llamarse una vez que el usuario inicia sesión con
  /// la contraseña nueva para mantener el hash en SQL actualizado.
  Future<bool> actualizarContrasenaPropia(String nuevaContrasena) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usuarios}/contrasena-propia'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'NuevaContrasena': nuevaContrasena}),
      );
      return response.statusCode == 200;
    } catch (e) {
      logD('[AuthService] Error actualizando contraseña en API: $e');
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
      if (await _googleSignIn.isSignedIn() == true) {
        try {
          await _googleSignIn.disconnect();
        } catch (e) {
          logD('Error al desconectar Google (reintentando signOut): $e');
        }
        await _googleSignIn.signOut();
      }
    } catch (e) {
      logD('Error durante el cierre de sesión de Google: $e');
    }
    
    await _auth.signOut();
  }

  Future<String?> getToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
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
    if (_auth.currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey) != null;
  }

  User? get currentUser => _auth.currentUser;

  // Sincroniza el usuario autenticado de Firebase con la API (tabla Usuarios)
  Future<Usuario?> syncUsuarioConApi({
    required int rolId, 
    String? contrasena,
    Map<String, dynamic>? additionalData,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    final correo = user.email!;
    final passwordValue = contrasena ?? 'firebase_auth';

    try {
      Usuario? existente = await obtenerUsuarioPorCorreo(correo);
      Usuario sincronizado;

      if (existente == null) {
        String nombre = additionalData?['nombre'] ?? 'Cliente';
        String apellido = additionalData?['apellido'] ?? 'Nuevo';
        
        if (user.displayName != null && user.displayName!.trim().isNotEmpty && additionalData == null) {
          final parts = user.displayName!.split(' ');
          nombre = parts[0];
          if (parts.length > 1) {
            apellido = parts.sublist(1).join(' ');
          }
        }

        // Generar documento aleatorio si no se proporciona (como en la web)
        final rnd = Random.secure();
        final randomDoc = additionalData?['documento'] ?? (10000000 + rnd.nextInt(89999999)).toString();

        final nuevo = Usuario(
          correo: correo,
          nombre: nombre,
          apellido: apellido,
          fotoPerfil: user.photoURL,
          contrasena: passwordValue,
          rolId: rolId,
          documento: randomDoc,
          tipoDocumento: additionalData?['tipoDocumento'] ?? 'OT',
          telefono: additionalData?['telefono'],
          estado: true,
        );
        sincronizado = await crearUsuario(nuevo);
      } else {
        final rolFinal = existente.rolId ?? rolId;
        
        // Si hay datos adicionales, actualizamos el perfil del usuario
        if (existente.rolId != rolFinal || existente.estado != true || additionalData != null) {
          final actualizado = Usuario(
            id: existente.id,
            correo: existente.correo,
            nombre: additionalData?['nombre'] ?? existente.nombre,
            apellido: additionalData?['apellido'] ?? existente.apellido,
            contrasena: existente.contrasena ?? passwordValue,
            rolId: rolFinal,
            documento: additionalData?['documento'] ?? existente.documento,
            tipoDocumento: additionalData?['tipoDocumento'] ?? existente.tipoDocumento ?? 'CC',
            telefono: additionalData?['telefono'] ?? existente.telefono,
            estado: true,
          );
          sincronizado = await actualizarUsuario(actualizado);
        } else {
          sincronizado = existente;
        }
      }

      await _saveApiUser(sincronizado);
      return sincronizado;
    } catch (e) {
      logD('Error sincronizando usuario con API: $e');
      return null;
    }
  }

  Future<Usuario?> fetchUsuarioDesdeApi() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    try {
      logD('[AuthService] Consultando usuario API para ${user.email}');
      final usuario = await obtenerUsuarioPorCorreo(user.email!);
      if (usuario != null) {
        await _saveApiUser(usuario);
      }
      return usuario;
    } catch (e) {
      logD('[AuthService] Error obteniendo usuario desde API: $e');
      return null;
    }
  }

  Future<void> _saveApiUser(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final json = usuario.toJson();
    json.remove('contrasena');
    json.remove('Contrasena');
    await prefs.setString(_userKey, jsonEncode(json));
  }
}
