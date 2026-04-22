import 'package:flutter/material.dart';
import 'dart:async';
import 'package:parte_movil/core/themes/app_theme.dart';
import 'package:parte_movil/presentation/routes/app_routes.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/repositories/auth_repository_impl.dart';
import 'package:parte_movil/domain/usecases/login_usecase.dart';
import 'package:parte_movil/domain/usecases/google_login_usecase.dart';
import 'package:parte_movil/domain/usecases/logout_usecase.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_bloc.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _sessionClosedOnExit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && !_sessionClosedOnExit) {
      _sessionClosedOnExit = true;
      unawaited(_authService.signOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Inyección de Dependencias Manual (idealmente esto va en un archivo get_it)
    final authRepository = AuthRepositoryImpl(
      authService: _authService,
      auxiliarService: AuxiliarService(),
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

        title: 'MANITO BARBERSHOP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.initialRoute,
      routes: AppRoutes.routes,

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
