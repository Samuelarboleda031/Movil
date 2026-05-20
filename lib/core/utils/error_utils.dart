/// Extrae solo el mensaje útil de una cadena de excepciones anidadas.
/// "Exception: Error de conexión: Exception: Error 400: Mensaje" → "Mensaje"
String limpiarError(Object e) {
  var msg = e.toString();
  final prefijos = ['Exception:', 'Error de conexión:', 'Error:'];
  bool cambio = true;
  while (cambio) {
    cambio = false;
    for (final p in prefijos) {
      final idx = msg.indexOf(p);
      if (idx != -1) {
        final despues = msg.substring(idx + p.length).trim();
        if (despues.isNotEmpty) {
          msg = despues;
          cambio = true;
        }
      }
    }
  }
  // Quitar código HTTP al inicio (ej. "400: ")
  msg = msg.replaceFirst(RegExp(r'^\d{3}:\s*'), '');
  return msg.trim();
}
