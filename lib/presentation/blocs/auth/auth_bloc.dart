import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

import 'auth_event.dart';
import 'auth_state.dart';
import 'package:parte_movil/domain/usecases/login_usecase.dart';
import 'package:parte_movil/domain/usecases/google_login_usecase.dart';
import 'package:parte_movil/domain/usecases/logout_usecase.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final GoogleLoginUseCase _googleLoginUseCase;
  final LogoutUseCase _logoutUseCase;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required GoogleLoginUseCase googleLoginUseCase,
    required LogoutUseCase logoutUseCase,
  })  : _loginUseCase = loginUseCase,
        _googleLoginUseCase = googleLoginUseCase,
        _logoutUseCase = logoutUseCase,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final session = await _loginUseCase(event.email, event.password);
      emit(AuthAuthenticated(session.role));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-not-found':
          emit(AuthError('Correo o contraseña incorrectos. Verifica tus datos.'));
        case 'user-disabled':
          emit(AuthError('Esta cuenta ha sido desactivada. Contacta al administrador.'));
        case 'too-many-requests':
          emit(AuthError('Demasiados intentos fallidos. Espera unos minutos e intenta de nuevo.'));
        case 'network-request-failed':
          emit(AuthError('Sin conexión a internet. Verifica tu red e intenta de nuevo.'));
        case 'invalid-email':
          emit(AuthError('El formato del correo electrónico no es válido.'));
        default:
          emit(AuthError(e.message ?? 'Error en autenticación. Intenta de nuevo.'));
      }
    } catch (e) {
      emit(AuthError(limpiarError(e)));
    }
  }

  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final session = await _googleLoginUseCase();
      emit(AuthAuthenticated(session.role));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Error en autenticación con Google'));
    } catch (e) {
      emit(AuthError(limpiarError(e)));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _logoutUseCase();
      emit(AuthInitial());
    } catch (e) {
      emit(AuthError(limpiarError(e)));
    }
  }
}
