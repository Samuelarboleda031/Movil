import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parte_movil/data/datasources/password_reset_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/utils/logger.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? code;

  const ResetPasswordScreen({
    super.key,
    this.email,
    this.code,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordResetService = PasswordResetService();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isVerifying = true;
  bool _codeValid = false;
  String? _errorMessage;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _resetSuccess = false;

  @override
  void initState() {
    super.initState();
    // Si se recibieron parámetros por deep link, usarlos
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
    if (widget.code != null) {
      _codeController.text = widget.code!;
    }

    // Si tenemos ambos parámetros, verificar el código automáticamente
    if (widget.email != null && widget.code != null) {
      _verifyCode();
    } else {
      setState(() {
        _isVerifying = false;
        _codeValid = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Primero intentar verificar con Firebase (para oobCode de Firebase)
      final emailFromFirebase = await FirebaseAuth.instance.verifyPasswordResetCode(
        _codeController.text.trim(),
      );

      // Si Firebase verificó el código, obtenemos el email
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _codeValid = true;
          if (_emailController.text.isEmpty) {
            _emailController.text = emailFromFirebase;
          }
        });
        return;
      }
    } catch (e) {
      // No es un código de Firebase, intentar con nuestro backend
      logD('No es código Firebase, intentando backend: $e');
    }

    // Fallback: verificar con nuestro backend
    final isValid = await _passwordResetService.verifyResetCode(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _codeValid = isValid;
        if (!isValid) {
          _errorMessage = 'El código de recuperación es inválido o ha expirado.';
        }
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Primero intentar con Firebase (para oobCode de Firebase)
      await FirebaseAuth.instance.confirmPasswordReset(
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );

      // Si Firebase funcionó, éxito
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resetSuccess = true;
        });
      }
      return;
    } catch (e) {
      // No es un código de Firebase o falló, intentar con nuestro backend
      logD('Firebase reset failed, trying backend: $e');
    }

    // Fallback: intentar resetear con el backend
    final success = await _passwordResetService.resetPassword(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (success) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resetSuccess = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudo actualizar la contraseña. Por favor intente nuevamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer Contraseña'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _isVerifying
            ? _buildVerifyingView()
            : _resetSuccess
                ? _buildSuccessView()
                : _buildResetForm(),
      ),
    );
  }

  Widget _buildVerifyingView() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 60),
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text(
          'Verificando código de recuperación...',
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Contraseña actualizada!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tu contraseña ha sido restablecida exitosamente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
          child: const Text('Ir al Login'),
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset,
            size: 80,
            color: Colors.brown,
          ),
          const SizedBox(height: 24),
          const Text(
            'Restablecer Contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu nueva contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Mostrar error si existe
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Campos de email y código (ocultos si vienen por deep link, pero editables si es necesario)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingrese su correo';
              }
              if (!value.contains('@')) {
                return 'Ingrese un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Código de recuperación',
              prefixIcon: Icon(Icons.confirmation_number),
              hintText: 'Ingrese el código del email',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese el código de recuperación';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          if (!_codeValid)
            ElevatedButton.icon(
              onPressed: _verifyCode,
              icon: const Icon(Icons.verified),
              label: const Text('Verificar Código'),
            )
          else ...[
            // Nueva contraseña
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese una contraseña';
                }
                if (value.length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirmar contraseña
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirme su contraseña';
                }
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Actualizar Contraseña'),
            ),
          ],

          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
