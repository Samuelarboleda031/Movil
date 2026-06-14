class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://barberiaapi-em5q.onrender.com/api',
  );

  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://manitobarbershop.vercel.app',
  );

  // Usuarios
  static const String usuarios = '/Usuarios';

  // Ventas
  static const String ventas = '/Ventas';
  static const String detalleVenta = '/DetallesVenta';

  // Agendamientos
  static const String agendamientos = '/Agendamientos';

  // Descuentos por día (sincronizados con el panel web)
  static const String descuentosDia = '/DescuentosDia';

  // Horarios
  static const String horariosBarberos = '/HorariosBarberos';

  // Catálogos
  static const String clientes = '/Clientes';
  static const String barberos = '/Barberos';
  static const String servicios = '/Servicios';
  static const String paquetes = '/Paquetes';
  static const String detallePaquetes = '/DetallePaquetes';
  static const String productos = '/Productos';
  static const String categorias = '/Categorias';
  static const String solicitudesCambioHorario = '/SolicitudesCambioHorario';
  static const String dashboard = '/Dashboard';
  static const String creditoBarbero = '/credito-barbero';

  // Endpoints adicionales centralizados
  static const String devoluciones = '/Devoluciones';
  static const String subirImagen = '/images/subir';
  static String fotoUsuario(int id) => '/Usuarios/$id/foto';
  static String detallePaquetesPorPaquete(int id) => '/DetallePaquetes/paquete/$id';
}
