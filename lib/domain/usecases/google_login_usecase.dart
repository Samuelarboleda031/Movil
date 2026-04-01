import 'package:parte_movil/domain/repositories/auth_repository.dart';

class GoogleLoginUseCase {
  final AuthRepository repository;

  GoogleLoginUseCase(this.repository);

  Future<SessionData> call() async {
    return await repository.loginWithGoogle();
  }
}
