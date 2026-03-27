class ApiConfig {
  static const String baseUrl = 'https://manitobarbershop.up.railway.app/api';
  
  // Endpoints de Autenticación
  static const String login = '/Usuarios/login';
  static const String usuarios = '/Usuarios';
  
  // Endpoints de Ventas
  static const String ventas = '/Ventas';
  static const String detalleVenta = '/DetallesVenta';
  
  // Endpoints de Agendamientos
  static const String agendamientos = '/Agendamientos';
  
  // Endpoints auxiliares
  static const String clientes = '/Clientes';
  static const String barberos = '/Barberos';
  static const String servicios = '/Servicios';
  static const String paquetes = '/Paquetes';
  static const String productos = '/Productos';
}

