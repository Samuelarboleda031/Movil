import 'package:parte_movil/domain/entities/usuario_entity.dart';
import 'package:parte_movil/data/models/app_role.dart';

class SessionData {
  final UsuarioEntity usuario;
  final AppRole role;

  const SessionData({required this.usuario, required this.role});
}

abstract class AuthRepository {
  Future<SessionData> loginWithEmail(String email, String password);
  Future<SessionData> loginWithGoogle();
  Future<void> logout();
}
