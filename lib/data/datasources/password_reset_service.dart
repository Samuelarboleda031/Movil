import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class PasswordResetService {
  static const String _endpointPath = '/Notificaciones/password-reset';
  static const String _verifyCodePath = '/Auth/verify-reset-code';
  static const String _resetPasswordPath = '/Auth/reset-password';
  final AuthService _authService = AuthService();

  /// URL de la app web en Vercel (para el link del email)
  static const String webAppUrl = 'https://manitobarbershop.vercel.app';

  /// Genera un código de reset seguro
  String _generateResetCode() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Envía un email de recuperación de contraseña con link de Vercel
  /// El link apunta a la web pero puede abrir la app móvil si está instalada
  Future<bool> sendPasswordResetEmail({
    required String email,
    required String nombre,
  }) async {
    try {
      final token = await _authService.getToken();
      final resetCode = _generateResetCode();

      // URL que abrirá la app móvil (si está instalada) o la web (si no)
      // El formato sigue el patrón: https://manitobarbershop.vercel.app/reset-password?code=xxx&email=xxx
      final resetLink = '$webAppUrl/reset-password?code=$resetCode&email=${Uri.encodeComponent(email)}';

      final uri = Uri.parse('${ApiConfig.baseUrl}$_endpointPath');

      final Map<String, dynamic> payload = {
        'email': email,
        'nombre': nombre,
        'resetCode': resetCode,
        'resetLink': resetLink,
        'appName': 'Manito BarberShop',
        'expirationMinutes': 60,
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('✅ Email de recuperación enviado exitosamente');
        return true;
      } else {
        print('❌ Error al enviar email de recuperación: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Excepción al enviar email de recuperación: $e');
      return false;
    }
  }

  /// Verifica si un código de reset es válido
  Future<bool> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$_verifyCodePath');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error verificando código: $e');
      return false;
    }
  }

  /// Resetea la contraseña usando el código
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$_resetPasswordPath');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error reseteando contraseña: $e');
      return false;
    }
  }

  /// Usa Firebase para enviar el email de reset (alternativa simple)
  /// Este método usa el enfoque tradicional de Firebase sin custom links
  Future<bool> sendFirebasePasswordReset(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      print('❌ Error enviando reset de Firebase: $e');
      return false;
    }
  }
}
