import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:parte_movil/core/themes/app_theme.dart';
import 'package:parte_movil/presentation/routes/app_routes.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/repositories/auth_repository_impl.dart';
import 'package:parte_movil/domain/usecases/login_usecase.dart';
import 'package:parte_movil/domain/usecases/google_login_usecase.dart';
import 'package:parte_movil/domain/usecases/logout_usecase.dart';
import 'package:parte_movil/presentation/pages/reset_password_screen.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_bloc.dart';
import 'package:parte_movil/core/utils/logger.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    _linkSub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Obtener el link que abrió la app (si fue abierta desde un link)
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      logD('Error obteniendo link inicial: $e');
    }
  }

  /// Maneja el deep link entrante
  void _handleDeepLink(Uri uri) {
    logD('Deep link recibido: $uri');

    // Manejar reset de contraseña
    // Formato: https://manitobarbershop.vercel.app/reset-password?code=xxx&email=xxx
    // Firebase usa: ?oobCode=xxx&mode=resetPassword
    if (uri.path == '/reset-password' || uri.path.contains('/reset-password')) {
      // Soporte para ambos: 'code' (nuestro sistema) y 'oobCode' (Firebase)
      final code = uri.queryParameters['code'] ?? uri.queryParameters['oobCode'];
      final email = uri.queryParameters['email'];

      if (code != null) {
        // Navegar a la pantalla de reset de contraseña
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              email: email ?? '', // Email puede ser null si viene de Firebase
              code: code,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inyección de Dependencias Manual (idealmente esto va en un archivo get_it)
    final authRepository = AuthRepositoryImpl(
      authService: _authService,
      clienteService: ClienteService(),
      barberoService: BarberoService(),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            loginUseCase: LoginUseCase(authRepository),
            googleLoginUseCase: GoogleLoginUseCase(authRepository),
            logoutUseCase: LogoutUseCase(authRepository),
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'MANITO BARBERSHOP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: AppRoutes.initialRoute,
        routes: AppRoutes.routes,
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Página no encontrada', style: TextStyle(fontSize: 18))),
          ),
        ),

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('es', ''), // Spanish, no country code
      ],
    ),
    );
  }
}
