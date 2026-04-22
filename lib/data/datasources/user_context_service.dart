import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/usuario.dart';
import 'auth_service.dart';
import 'cliente_service.dart';
import 'barbero_service.dart';

class UserContextService {
  final AuthService _authService = AuthService();
  final ClienteService _clienteService = ClienteService();
  final BarberoService _barberoService = BarberoService();

  Usuario? _cachedUsuario;
  Cliente? _cachedCliente;
  Barbero? _cachedBarbero;

  Future<Usuario?> _ensureUsuario() async {
    _cachedUsuario ??= await _authService.getCurrentUser();
    _cachedUsuario ??= await _authService.fetchUsuarioDesdeApi();
    return _cachedUsuario;
  }

  Future<AppRole?> obtenerRolActual() async {
    final usuario = await _ensureUsuario();
    if (usuario?.rolId == null) return null;
    return roleForRolId(usuario!.rolId);
  }

  Future<Cliente?> obtenerClienteActual({List<Cliente>? clientesCache}) async {
    if (_cachedCliente != null) return _cachedCliente;

    final usuario = await _ensureUsuario();
    final clientes =
        clientesCache ?? await _clienteService.obtenerClientes();

    final cliente = _matchCliente(clientes, usuario);
    if (cliente != null) {
      _cachedCliente = cliente;
    }
    return cliente;
  }

  Future<Barbero?> obtenerBarberoActual({List<Barbero>? barberosCache}) async {
    if (_cachedBarbero != null) return _cachedBarbero;

    final usuario = await _ensureUsuario();
    final barberos =
        barberosCache ?? await _barberoService.obtenerBarberos();

    final barbero = _matchBarbero(barberos, usuario);
    if (barbero != null) {
      _cachedBarbero = barbero;
    }
    return barbero;
  }

  Cliente? _matchCliente(List<Cliente> clientes, Usuario? usuario) {
    if (usuario == null) return null;

    if (usuario.id != null) {
      for (final cliente in clientes) {
        if (cliente.usuarioId == usuario.id) {
          return cliente;
        }
      }
    }

    final correo = (usuario.correo.isNotEmpty
            ? usuario.correo
            : _authService.currentUser?.email)
        ?.toLowerCase();
    if (correo != null) {
      for (final cliente in clientes) {
        final email = (cliente.email ?? '').toLowerCase();
        if (email == correo) return cliente;
      }
    }
    return null;
  }

  Barbero? _matchBarbero(List<Barbero> barberos, Usuario? usuario) {
    if (usuario == null) return null;

    if (usuario.id != null) {
      for (final barbero in barberos) {
        if (barbero.usuarioId == usuario.id) {
          return barbero;
        }
      }
    }

    final correo = (usuario.correo.isNotEmpty
            ? usuario.correo
            : _authService.currentUser?.email)
        ?.toLowerCase();
    if (correo != null) {
      for (final barbero in barberos) {
        final email = (barbero.email ?? '').toLowerCase();
        if (email == correo) return barbero;
      }
    }
    return null;
  }

  void limpiarCache() {
    _cachedUsuario = null;
    _cachedCliente = null;
    _cachedBarbero = null;
  }
}


