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
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';

import 'package:parte_movil/presentation/pages/home_screen.dart';
import 'package:parte_movil/presentation/pages/login_screen.dart';
import 'package:parte_movil/presentation/pages/register_screen.dart';
import 'package:parte_movil/presentation/pages/ventas_screen.dart';
import 'package:parte_movil/presentation/pages/agendamientos_screen.dart';
import 'package:parte_movil/presentation/pages/client_home_screen.dart';
import 'package:parte_movil/presentation/pages/mis_compras_screen.dart';
import 'package:parte_movil/presentation/pages/client_agendamiento_form_screen.dart';
import 'package:parte_movil/presentation/pages/barber_home_screen.dart';

import 'package:parte_movil/presentation/pages/client_profile_screen.dart';
import 'package:parte_movil/presentation/pages/barber_profile_screen.dart';
import 'package:parte_movil/presentation/pages/servicios_gestion_screen.dart';
import 'package:parte_movil/presentation/pages/productos_gestion_screen.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/main_layout.dart';

class AppRoutes {
  static const String initialRoute = '/';

  static Map<String, WidgetBuilder> get routes {
    return {
      '/': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/home': (context) => const HomeScreen(),
      '/ventas': (context) => BlocProvider(
            create: (context) => VentasBloc(
              ventaService: VentaService(),
              auxiliarService: AuxiliarService(),
              authService: AuthService(),
            )..add(const LoadVentasRequested(page: 1)),
            child: const VentasScreen(),
          ),
      '/mis-compras': (context) => const MisComprasScreen(),

      '/agendamiento': (context) => BlocProvider(
            create: (context) => AgendamientosBloc(
              agendamientoService: AgendamientoService(),
              emailJsService: EmailJsService(),
              authService: AuthService(),
              userContextService: UserContextService(),
              auxiliarService: AuxiliarService(),
            )..add(const LoadAgendamientosRequested(page: 1)),
            child: const AgendamientosScreen(),
          ),

      '/client_home': (context) => const ClientHomeScreen(),
      '/cliente/agendamiento': (context) => const ClientAgendamientoFormScreen(),

      '/cliente/mis-compras': (context) => const MisComprasScreen(),
      '/barber_home': (context) => const BarberHomeScreen(),

      '/cliente/perfil': (context) => const ClientProfileScreen(),
      '/barbero/perfil': (context) => const BarberProfileScreen(),
      '/servicios': (context) => const ServiciosGestionScreen(),
      '/productos': (context) => const ProductosGestionScreen(),
      '/main-admin': (context) => const MainLayout(role: AppRole.admin),
      '/main-barber': (context) => const MainLayout(role: AppRole.barber),
      '/main-client': (context) => const MainLayout(role: AppRole.client),
    };
  }
}
