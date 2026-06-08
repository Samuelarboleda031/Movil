import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/utils/logger.dart';

class PasswordResetService {
  static const String _endpointPath = '/Notificaciones/password-reset';
  static const String _verifyCodePath = '/Auth/verify-reset-code';
  static const String _resetPasswordPath = '/Auth/reset-password';
  final AuthService _authService = AuthService();

  static String get webAppUrl => ApiConfig.webAppUrl;

  /// Genera un código de reset seguro
  String _generateResetCode() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Envía un email de recuperación de contraseña.
  /// Se usa Firebase directamente ya que el backend no soporta endpoints personalizados aún.
  Future<bool> sendPasswordResetEmail({
    required String email,
    required String nombre,
  }) async {
    return await sendFirebasePasswordReset(email);
  }

  /// Verifica si un código de reset es válido (Legacy/No implementado en backend)
  Future<bool> verifyResetCode({
    required String email,
    required String code,
  }) async {
    logD('⚠️ verifyResetCode no está implementado en el backend.');
    return false;
  }

  /// Resetea la contraseña usando el código (Legacy/No implementado en backend)
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    logD('⚠️ resetPassword no está implementado en el backend.');
    return false;
  }

  /// Usa Firebase para enviar el email de reset (alternativa simple)
  /// Este método usa el enfoque tradicional de Firebase sin custom links
  Future<bool> sendFirebasePasswordReset(String email) async {
    try {
      final result = await _authService.resetPassword(email);
      return result.success;
    } catch (e) {
      logD('❌ Error enviando reset de Firebase: $e');
      return false;
    }
  }
}
