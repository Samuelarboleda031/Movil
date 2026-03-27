import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/ventas_screen.dart';
import 'screens/agendamientos_screen.dart';
import 'screens/client_home_screen.dart';
import 'screens/mis_compras_screen.dart';
import 'screens/client_agendamientos_screen.dart';
import 'screens/client_agendamiento_form_screen.dart';
import 'screens/barber_home_screen.dart';
import 'screens/barber_agendamientos_screen.dart';
import 'screens/barber_ventas_screen.dart';
import 'screens/client_profile_screen.dart';
import 'screens/barber_profile_screen.dart';
import 'screens/servicios_gestion_screen.dart';
import 'screens/servicio_form_screen.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'models/app_role.dart';
import 'widgets/main_layout.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('es_ES', null);
  runApp(const MyApp());
}

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
    return MaterialApp(
      title: 'MANITO BARBERSHOP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD8B081),
          brightness: Brightness.dark,
          primary: const Color(0xFFD8B081),
          secondary: Colors.grey,
          surface: const Color(0xFF111111),
          background: Colors.black,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black, // Pure black background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111111),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.grey.shade900,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD8B081),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade800),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade900),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8B081)),
          ),
          filled: true,
          fillColor: const Color(0xFF111111),
          hintStyle: TextStyle(color: Colors.grey.shade600),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // Pantalla inicial -> Login
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/ventas': (context) => const VentasScreen(),
        '/mis-compras': (context) => const MisComprasScreen(),
        '/agendamiento': (context) => const AgendamientosScreen(),
        '/client_home': (context) => const ClientHomeScreen(),
        '/cliente/mis-citas': (context) => const ClientAgendamientosScreen(),
        '/cliente/agendamiento': (context) => const ClientAgendamientoFormScreen(),
        '/cliente/mis-compras': (context) => const MisComprasScreen(),
        '/barber_home': (context) => const BarberHomeScreen(),
        '/barbero/mis-citas': (context) => const BarberAgendamientosScreen(),
        '/barbero/mis-ventas': (context) => const BarberVentasScreen(),
        '/cliente/perfil': (context) => const ClientProfileScreen(),
        '/barbero/perfil': (context) => const BarberProfileScreen(),
        '/servicios': (context) => const ServiciosGestionScreen(),
        // Nuevas rutas con Bottom Navigation
        '/main-admin': (context) => const MainLayout(role: AppRole.admin),
        '/main-barber': (context) => const MainLayout(role: AppRole.barber),
        '/main-client': (context) => const MainLayout(role: AppRole.client),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('es', ''), // Spanish, no country code
      ],
    );
  }
}
