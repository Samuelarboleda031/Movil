import 'package:get_it/get_it.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/horario_barbero_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/data/datasources/password_reset_service.dart';
import 'package:parte_movil/data/datasources/devolucion_service.dart';
import 'package:parte_movil/data/datasources/dashboard_service.dart';
import 'package:parte_movil/data/datasources/media_service.dart';
import 'package:parte_movil/data/datasources/credito_barbero_service.dart';
import 'package:parte_movil/data/datasources/solicitud_cambio_horario_service.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  sl.registerLazySingleton<AuthService>(() => AuthService());
  sl.registerLazySingleton<AgendamientoService>(() => AgendamientoService());
  sl.registerLazySingleton<VentaService>(() => VentaService());
  sl.registerLazySingleton<BarberoService>(() => BarberoService());
  sl.registerLazySingleton<ClienteService>(() => ClienteService());
  sl.registerLazySingleton<HorarioBarberoService>(() => HorarioBarberoService());
  sl.registerLazySingleton<UserContextService>(() => UserContextService());
  sl.registerLazySingleton<EmailJsService>(() => EmailJsService());
  sl.registerLazySingleton<ServicioService>(() => ServicioService());
  sl.registerLazySingleton<ProductoService>(() => ProductoService());
  sl.registerLazySingleton<PaqueteService>(() => PaqueteService());
  sl.registerLazySingleton<PasswordResetService>(() => PasswordResetService());
  sl.registerLazySingleton<DevolucionService>(() => DevolucionService());
  sl.registerLazySingleton<DashboardService>(() => DashboardService());
  sl.registerLazySingleton<MediaService>(() => MediaService());
  sl.registerLazySingleton<CreditoBarberoService>(() => CreditoBarberoService());
  sl.registerLazySingleton<SolicitudCambioHorarioService>(() => SolicitudCambioHorarioService());
}
