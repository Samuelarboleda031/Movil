import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_bloc.dart';
import 'package:parte_movil/presentation/blocs/ventas/ventas_event.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_bloc.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_event.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_bloc.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_event.dart';
import 'package:parte_movil/data/datasources/horario_barbero_service.dart';

import 'package:parte_movil/presentation/pages/login_screen.dart';
import 'package:parte_movil/presentation/pages/register_screen.dart';
import 'package:parte_movil/presentation/pages/splash_screen.dart';
import 'package:parte_movil/presentation/pages/ventas_screen.dart';
import 'package:parte_movil/presentation/pages/agendamientos_screen.dart';
import 'package:parte_movil/presentation/pages/mis_compras_screen.dart';

import 'package:parte_movil/presentation/pages/servicios_gestion_screen.dart';
import 'package:parte_movil/presentation/pages/productos_gestion_screen.dart';
import 'package:parte_movil/presentation/pages/horarios_gestion_screen.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/main_layout.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';

class AppRoutes {
  static const String initialRoute = '/splash';

  static Map<String, WidgetBuilder> get routes {
    return {
      '/splash': (context) => const SplashScreen(),
      '/login': (context) => const LoginScreen(),
      '/': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/home': (context) => const MainLayout(role: AppRole.client),
      '/ventas': (context) => SessionGuard(
            allowedRoles: const [AppRole.admin, AppRole.manager],
            child: BlocProvider(
              create: (context) => VentasBloc(
                ventaService: VentaService(),
                clienteService: ClienteService(),
                barberoService: BarberoService(),
                authService: AuthService(),
              )..add(const LoadVentasRequested(page: 1)),
              child: const VentasScreen(role: AppRole.admin),
            ),
          ),
      '/mis-compras': (context) => const MisComprasScreen(),
      '/agendamiento': (context) => SessionGuard(
            allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
            child: BlocProvider(
              create: (context) => AgendamientosBloc(
                agendamientoService: AgendamientoService(),
                emailJsService: EmailJsService(),
                authService: AuthService(),
                userContextService: UserContextService(),
              )..add(const LoadAgendamientosRequested(page: 1, estaSemana: false)),
              child: const AgendamientosScreen(role: AppRole.admin),
            ),
          ),
      '/servicios': (context) => const SessionGuard(
            allowedRoles: [AppRole.admin, AppRole.manager],
            child: ServiciosGestionScreen(),
          ),
      '/productos': (context) => const SessionGuard(
            allowedRoles: [AppRole.admin, AppRole.manager],
            child: ProductosGestionScreen(),
          ),
      '/horarios': (context) => SessionGuard(
            allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
            child: BlocProvider(
              create: (context) => HorariosBloc(
                horarioService: HorarioBarberoService(),
                barberoService: BarberoService(),
                authService: AuthService(),
                userContextService: UserContextService(),
                role: AppRole.admin,
              )..add(LoadHorariosRequested()),
              child: const HorariosGestionScreen(role: AppRole.admin),
            ),
          ),
      '/main-admin': (context) => const MainLayout(role: AppRole.admin),
      '/main-barber': (context) => const MainLayout(role: AppRole.barber),
      '/main-client': (context) => const MainLayout(role: AppRole.client),
    };
  }
}
