import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_bloc.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_event.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_state.dart';
import 'forgot_password_screen.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _homeRouteForRole(AppRole role) {
    switch (role) {
      case AppRole.manager:
      case AppRole.admin:
        return '/main-admin';
      case AppRole.barber:
        return '/main-barber';
      case AppRole.client:
        return '/main-client';
    }
  }

  void _login() {
    context.read<AuthBloc>().add(
      LoginRequested(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      ),
    );
  }

  void _googleLogin() {
    context.read<AuthBloc>().add(GoogleLoginRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            AppToast.showError(context, state.message);
          } else if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(
              context,
              _homeRouteForRole(state.role),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  const Color(0xFFD8B081).withOpacity(0.05),
                  AppColors.bg,
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 50),
                    // Logo Circular
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD8B081).withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                        border: Border.all(
                            color: const Color(0xFFD8B081).withOpacity(0.3), width: 2),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/Manito.jpeg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Formulario
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscureText,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _obscureText = !_obscureText),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(color: Color(0xFFD8B081)),
                        ),
                      ),
                    ),
                    // Botones
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 8,
                          shadowColor: const Color(0xFFD8B081).withOpacity(0.4),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text(
                                'INICIAR SESIÓN',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, letterSpacing: 1.5),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white10)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('o continúa con',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: Colors.white10)),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _googleLogin,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        label: const Text('Google',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      child: RichText(
                        text: const TextSpan(
                          text: '¿No tienes una cuenta? ',
                          style: TextStyle(color: Colors.grey),
                          children: [
                            TextSpan(
                              text: 'Regístrate aquí',
                              style: TextStyle(
                                  color: Color(0xFFD8B081),
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
