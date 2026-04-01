import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class EmailJsService {
  static const String _baseUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  
  // Credenciales obtenidas del front
  static const String _serviceId = 'service_6lfoq1q';
  static const String _templateIdCancel = 'template_hyn4ypr';
  static const String _publicKey = 'joqUUxGG_ub2Q__4C';

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
      // Formatear la fecha exactamente como en el front: toLocaleString('es-ES', ...)
      // JS: lunes, 27 de marzo, 02:00 PM (aprox)
      String fechaFormateada = fechaOriginal;
      try {
        // El front recibe "YYYY-MM-DD HH:mm" o ISO. 
        // DateTime.parse maneja "YYYY-MM-DD HH:mm".
        final DateTime date = DateTime.parse(fechaOriginal.replaceAll(' ', 'T'));
        fechaFormateada = DateFormat('EEEE, d \'de\' MMMM, hh:mm a', 'es_ES').format(date);
      } catch (e) {
        print('Error formateando fecha en EmailJsService: $e');
      }

      final String sugerenciasStr = (sugerenciasReprogramacion != null && sugerenciasReprogramacion.isNotEmpty)
          ? sugerenciasReprogramacion.join(' | ')
          : 'No disponibles';

      final Map<String, dynamic> payload = {
        'service_id': _serviceId,
        'template_id': _templateIdCancel,
        'user_id': _publicKey,
        'template_params': {
          'to_name': clienteNombre,
          'to_email': clienteEmail,
          'barbero_name': barberoNombre,
          'fecha_hora': fechaFormateada,
          'motivo': motivo, // Coincide con el front: 'motivo'
          'sugerencias': sugerenciasStr, // Coincide con el front: 'sugerencias'
          'app_name': 'Barbería App', // Coincide con VITE_APP_NAME
        },
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('✅ Email enviado exitosamente vía EmailJS');
        return true;
      } else {
        print('❌ Error al enviar email vía EmailJS: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Excepción al enviar email vía EmailJS: $e');
      return false;
    }
  }
}
