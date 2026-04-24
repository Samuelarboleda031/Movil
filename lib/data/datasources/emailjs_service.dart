import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class EmailJsService {
  static const String _endpointPath = '/Notificaciones/cancelacion-email';
  final AuthService _authService = AuthService();

  /// Envía un correo de notificación de cancelación a un cliente.
  Future<bool> notificarCancelacion({
    required String clienteNombre,
    required String clienteEmail,
    required String barberoNombre,
    required String fechaOriginal,
    String motivo = 'Cita cancelada por el administrador/barbero.',
    List<String>? sugerenciasReprogramacion,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}$_endpointPath');

      final Map<String, dynamic> payload = {
        'clienteNombre': clienteNombre,
        'clienteEmail': clienteEmail,
        'barberoNombre': barberoNombre,
        'fechaOriginal': fechaOriginal,
        'motivo': motivo,
        'sugerenciasReprogramacion': sugerenciasReprogramacion ?? <String>[],
        'appName': 'Barbería App',
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
        print('✅ Email enviado exitosamente vía backend proxy');
        return true;
      } else {
        print('❌ Error al enviar email vía backend proxy: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Excepción al enviar email vía backend proxy: $e');
      return false;
    }
  }
}
