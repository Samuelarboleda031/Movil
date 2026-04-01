import 'package:parte_movil/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<SessionData> call(String email, String password) async {
    return await repository.loginWithEmail(email, password);
  }
}
