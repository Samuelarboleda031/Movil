class ApiConfig {
  static const String baseUrl = 'https://barberiaapi-em5q.onrender.com/api';
  
  // Endpoints de Autenticación
  static const String login = '/Usuarios/login';
  static const String usuarios = '/Usuarios';
  
  // Endpoints de Ventas
  static const String ventas = '/Ventas';
  static const String detalleVenta = '/DetallesVenta';
  
  static const String agendamientos = '/Agendamientos';
  
  // Endpoints de Horarios
  static const String horariosBarberos = '/HorariosBarberos';
  
  // Endpoints auxiliares
  static const String clientes = '/Clientes';
  static const String barberos = '/Barberos';
  static const String servicios = '/Servicios';
  static const String paquetes = '/Paquetes';
  static const String detallePaquetes = '/DetallePaquetes';
  static const String productos = '/Productos';
  static const String solicitudesCambioHorario = '/SolicitudesCambioHorario';
}

