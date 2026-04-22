import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:parte_movil/domain/repositories/auth_repository.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/usuario.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final ClienteService _clienteService;
  final BarberoService _barberoService;

  AuthRepositoryImpl({
    required AuthService authService,
    required ClienteService clienteService,
    required BarberoService barberoService,
  })  : _authService = authService,
        _clienteService = clienteService,
        _barberoService = barberoService;

  @override
  Future<SessionData> loginWithEmail(String email, String password) async {
    await _authService.signIn(email, password);
    return await _verificarAcceso();
  }

  @override
  Future<SessionData> loginWithGoogle() async {
    final user = await _authService.signInWithGoogle();
    if (user == null) {
      throw Exception('No se pudo completar el login con Google.');
    }
    return await _verificarAcceso();
  }

  @override
  Future<void> logout() async {
    await _authService.signOut();
  }

  Future<SessionData> _verificarAcceso() async {
    final firebaseUser = _authService.currentUser;
    final emailActual = firebaseUser?.email ?? '(sin correo)';
    
    Usuario? usuarioApi = await _authService.fetchUsuarioDesdeApi();

    if (usuarioApi == null && firebaseUser?.email != null) {
      final cached = await _authService.getCurrentUser();
      if (cached != null && cached.correo.toLowerCase() == firebaseUser!.email!.toLowerCase()) {
        usuarioApi = cached;
      }
    }

    if (usuarioApi == null) {
      usuarioApi = await _authService.syncUsuarioConApi(rolId: 3);
    }

    if (usuarioApi == null || usuarioApi.rolId == null) {
      await _authService.signOut();
      throw Exception('No fue posible validar tu rol. Contacta al administrador.');
    }

    final AppRole role = roleForRolId(usuarioApi.rolId) ?? AppRole.client;

    try {
      if (role == AppRole.client) {
        final clienteExistente = await _clienteService.obtenerClientePorUsuarioId(usuarioApi.id!);
        if (clienteExistente == null) {
          final nuevoCliente = Cliente(
            documento: 'G-${DateTime.now().millisecondsSinceEpoch}',
            nombre: firebaseUser?.displayName?.split(' ').first ?? 'Usuario',
            apellido: firebaseUser?.displayName?.split(' ').skip(1).join(' ') ?? 'Google',
            email: usuarioApi.correo,
            fotoPerfil: firebaseUser?.photoURL,
            usuarioId: usuarioApi.id,
            estado: true,
          );
          await _clienteService.crearCliente(nuevoCliente);
        }
      } else if (role == AppRole.barber) {
        final barberoExistente = await _barberoService.obtenerBarberoPorUsuarioId(usuarioApi.id!);
        if (barberoExistente == null) {
          final nuevoBarbero = Barbero(
            documento: 'G-${DateTime.now().millisecondsSinceEpoch}',
            nombre: firebaseUser?.displayName?.split(' ').first ?? 'Barbero',
            apellido: firebaseUser?.displayName?.split(' ').skip(1).join(' ') ?? 'Google',
            email: usuarioApi.correo,
            fotoPerfil: firebaseUser?.photoURL,
            usuarioId: usuarioApi.id,
            estado: true,
            fechaIngreso: DateTime.now().toIso8601String().split('T').first, 
          );
          await _barberoService.crearBarbero(nuevoBarbero);
        }
      }
    } catch (e) {
      // Ignore profile creation error
    }

    return SessionData(usuario: usuarioApi, role: role);
  }
}
