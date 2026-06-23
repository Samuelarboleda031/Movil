import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_bloc.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_event.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/media_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';

// ─── TOKENS ────────────────────────────────────────────────────────────────
// Colores centralizados — ver core/themes/app_colors.dart
import 'package:parte_movil/core/themes/app_colors.dart';


// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN 1 — MI PERFIL
// ══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  final AppRole role;
  const ProfileScreen({super.key, required this.role});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _clienteService = ClienteService();
  final _barberoService = BarberoService();
  final _mediaService = MediaService();

  dynamic _entidadActual; // Barbero o Cliente
  bool _isLoading = true;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _isLoading = true);
    try {
      final firebaseUser = _authService.currentUser;
      final correo = firebaseUser?.email;

      if (correo == null) {
        throw Exception('No se pudo obtener el correo del usuario actual.');
      }
      _email = correo;

      if (widget.role == AppRole.barber) {
        final barberos = await _barberoService.obtenerBarberos();
        try {
          _entidadActual = barberos.firstWhere((b) => (b.email ?? '').toLowerCase() == correo.toLowerCase());
        } catch (_) { _entidadActual = null; }
      } else if (widget.role == AppRole.client) {
        final clientes = await _clienteService.obtenerClientes();
        try {
          _entidadActual = clientes.firstWhere((c) => (c.email ?? '').toLowerCase() == correo.toLowerCase());
        } catch (_) { _entidadActual = null; }
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, limpiarError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDocumento() {
    String? doc;
    if (_entidadActual is Barbero) doc = (_entidadActual as Barbero).documento;
    if (_entidadActual is Cliente) doc = (_entidadActual as Cliente).documento;
    if (doc == null || doc.isEmpty || doc == 'No ingresado') return 'No ingresado';
    return doc;
  }

  String _getNombre() {
    if (_entidadActual is Barbero) return (_entidadActual as Barbero).nombre ?? 'Usuario';
    if (_entidadActual is Cliente) return (_entidadActual as Cliente).nombre ?? 'Usuario';
    return 'Usuario';
  }

  String _getApellido() {
    if (_entidadActual is Barbero) return (_entidadActual as Barbero).apellido ?? '';
    if (_entidadActual is Cliente) return (_entidadActual as Cliente).apellido ?? '';
    return '';
  }

  String _getTelefono() {
    if (_entidadActual is Barbero) return (_entidadActual as Barbero).telefono ?? 'No ingresado';
    if (_entidadActual is Cliente) return (_entidadActual as Cliente).telefono ?? 'No ingresado';
    return 'No ingresado';
  }

  String _getDireccion() {
    if (_entidadActual is Barbero) return (_entidadActual as Barbero).direccion ?? 'No ingresada';
    if (_entidadActual is Cliente) return (_entidadActual as Cliente).direccion ?? 'No ingresada';
    return 'No ingresada';
  }

  String? _getFotoPerfil() {
    String? foto;
    if (_entidadActual is Barbero) foto = (_entidadActual as Barbero).fotoPerfil;
    if (_entidadActual is Cliente) foto = (_entidadActual as Cliente).fotoPerfil;
    if (foto != null && foto.isNotEmpty) {
      if (foto.startsWith('http')) return foto;
      // Las imágenes se sirven desde la raíz, no desde /api
      final rootUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      final separator = foto.startsWith('/') ? '' : '/';
      return '$rootUrl$separator$foto';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != AppRole.barber && widget.role != AppRole.client) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: Text("Perfil no disponible.", style: TextStyle(color: AppColors.white))));
    }

    return SessionGuard(
      allowedRoles: const [AppRole.barber, AppRole.client],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : SafeArea(
                child: Column(
                  children: [
                    // ── AppBar ─────────────────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mi Perfil',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // ── Body ───────────────────────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildProfileCard(),
                            const SizedBox(height: 12),
                            _buildDataCard(),
                            const SizedBox(height: 32), // extra space
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Avatar Card ───────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final fotoUrl = _getFotoPerfil();
    
    Future<void> _irAActualizarPerfil() async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UpdateProfileScreen(
          role: widget.role, 
          entidadActual: _entidadActual,
          email: _email,
        )),
      );
      if (result == true) _cargarPerfil();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Circle avatar as a button
          GestureDetector(
            onTap: _irAActualizarPerfil,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.greyLight, width: 2.5),
                color: const Color(0xFF3A2E25),
                image: fotoUrl != null 
                    ? DecorationImage(image: NetworkImage(fotoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: fotoUrl == null 
                ? ClipOval(
                    child: Container(
                      color: const Color(0xFF3A2E25),
                      child: const Icon(Icons.person, size: 60, color: Colors.white30),
                    ),
                  )
                : null,
            ),
          ),
          const SizedBox(height: 16),
          // "Cambiar foto de perfil" as a button
          GestureDetector(
            onTap: _irAActualizarPerfil,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: const Text(
                'Cambiar foto de perfil',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getNombre().toUpperCase(),
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Data Card ─────────────────────────────────────────────────────────────
  Widget _buildDataCard() {
    final _profileItems = [
      {'icon': Icons.badge_outlined,       'label': 'Documento',  'value': _getDocumento()},
      {'icon': Icons.person_outline,        'label': 'Nombre',     'value': _getNombre()},
      {'icon': Icons.person_2_outlined,     'label': 'Apellido',   'value': _getApellido().isEmpty ? '-' : _getApellido()},
      {'icon': Icons.phone_outlined,        'label': 'Teléfono',   'value': _getTelefono()},
      {'icon': Icons.mail_outline,          'label': 'Email',      'value': _email},
      {'icon': Icons.location_on_outlined,  'label': 'Dirección',  'value': _getDireccion()},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Text(
              'Datos personales',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          ..._profileItems.asMap().entries.map((e) {
            final isLast = e.key == _profileItems.length - 1;
            return Column(
              children: [
                _profileRow(e.value),
                if (!isLast)
                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 56,
                  ),
              ],
            );
          }),
          // Update button
          Padding(
            padding: const EdgeInsets.all(16),
            child: _goldButton(
              icon: Icons.edit_outlined,
              label: 'Actualizar perfil',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UpdateProfileScreen(
                      role: widget.role,
                      entidadActual: _entidadActual,
                      email: _email,
                    ),
                  ),
                );
                // Si guardó exitosamente, recargamos los datos
                if (result == true) {
                  _cargarPerfil();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(Map<String, dynamic> item) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UpdateProfileScreen(
              role: widget.role,
              entidadActual: _entidadActual,
              email: _email,
            ),
          ),
        );
        // Si guardó exitosamente, recargamos los datos
        if (result == true) {
          _cargarPerfil();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item['icon'] as IconData, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['label'] as String,
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['value'] as String,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _goldButton({IconData? icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.bg, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AppColors.bg,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN 2 — ACTUALIZAR PERFIL
// ══════════════════════════════════════════════════════════════════════════════
class UpdateProfileScreen extends StatefulWidget {
  final AppRole role;
  final dynamic entidadActual;
  final String email;

  const UpdateProfileScreen({
    super.key, 
    required this.role, 
    required this.entidadActual,
    required this.email
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _clienteService = ClienteService();
  final _barberoService = BarberoService();
  final _mediaService = MediaService();
  
  late final TextEditingController _documentoCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _barrioCtrl;
  late final TextEditingController _fechaNacimientoCtrl;

  bool _saving = false;
  bool _documentoEditable = true;
  String _tipoDocumento = 'CC';
  String? _fotoPerfil;
  File? _nuevaFotoFile;

  static const _tiposDocumento = ['CC', 'CE', 'TI', 'NIT', 'PP'];

  static ({String tipo, String numero}) _parsearDocumento(String raw) {
    for (final t in ['CC', 'CE', 'TI', 'NIT', 'PP']) {
      if (raw.startsWith('$t ')) {
        return (tipo: t, numero: raw.substring(t.length + 1).trim());
      }
    }
    return (tipo: 'CC', numero: raw);
  }

  // ── Helpers de fecha: formato visible dd/MM/aaaa <-> ISO yyyy-MM-dd ──────────
  static String _isoADisplay(String iso) {
    if (iso.isEmpty) return '';
    final p = iso.split('-');
    if (p.length == 3) {
      return '${p[2].padLeft(2, '0')}/${p[1].padLeft(2, '0')}/${p[0]}';
    }
    return iso;
  }

  /// Convierte "dd/MM/aaaa" a DateTime, o null si no es una fecha real.
  static DateTime? _parseDisplay(String s) {
    final p = s.split('/');
    if (p.length != 3) return null;
    if (p[2].length != 4) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    final dt = DateTime(y, m, d);
    // Rechaza fechas imposibles como 31/02 (DateTime las "desborda" al mes siguiente).
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  static int _edadEnAnios(DateTime nacimiento, DateTime ref) {
    int edad = ref.year - nacimiento.year;
    if (ref.month < nacimiento.month ||
        (ref.month == nacimiento.month && ref.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }

  @override
  void initState() {
    super.initState();
    String rawDoc = '';
    String nom = '';
    String ape = '';
    String tel = '';
    String dir = '';
    String bar = '';
    String fec = '';

    if (widget.entidadActual != null) {
      if (widget.role == AppRole.barber) {
        final b = widget.entidadActual as Barbero;
        rawDoc = b.documento ?? '';
        nom = b.nombre ?? '';
        ape = b.apellido ?? '';
        tel = b.telefono ?? '';
        dir = b.direccion ?? '';
        _fotoPerfil = b.fotoPerfil;
      } else if (widget.role == AppRole.client) {
        final c = widget.entidadActual as Cliente;
        rawDoc = c.documento ?? '';
        nom = c.nombre ?? '';
        ape = c.apellido ?? '';
        tel = c.telefono ?? '';
        dir = c.direccion ?? '';
        bar = c.barrio ?? '';
        fec = c.fechaNacimiento != null
            ? _isoADisplay(c.fechaNacimiento!.split('T')[0])
            : '';
        _fotoPerfil = c.fotoPerfil;
      }
    }

    final parsed = _parsearDocumento(rawDoc.trim());
    _tipoDocumento = parsed.tipo;

    _documentoCtrl        = TextEditingController(text: parsed.numero);
    _nombreCtrl           = TextEditingController(text: nom);
    _apellidoCtrl         = TextEditingController(text: ape);
    _telefonoCtrl         = TextEditingController(text: tel);
    _emailCtrl            = TextEditingController(text: widget.email);
    _direccionCtrl        = TextEditingController(text: dir);
    _barrioCtrl           = TextEditingController(text: bar);
    _fechaNacimientoCtrl  = TextEditingController(text: fec);

    _documentoEditable = rawDoc.isEmpty || rawDoc.startsWith('TMP') || rawDoc.startsWith('G-') || rawDoc.startsWith('PASO-');
  }

  @override
  void dispose() {
    _documentoCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _barrioCtrl.dispose();
    _fechaNacimientoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validaciones basicas
    if (_documentoCtrl.text.trim().isEmpty || _nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty) {
      AppToast.showError(context, 'Documento, Nombre y Apellido son obligatorios');
      return;
    }

    // El documento debe tener entre 4 y 18 dígitos (igual que la web/backend).
    // El máximo (18) ya lo limita el inputFormatter; aquí validamos el mínimo.
    final docNumero = _documentoCtrl.text.trim();
    if (docNumero.length < 4) {
      AppToast.showError(context, 'El número de documento debe tener al menos 4 dígitos');
      return;
    }

    // Fecha de nacimiento (solo clientes): valida formato y rango 8-70 años,
    // y la convierte a ISO (yyyy-MM-dd) que es lo que espera el backend.
    String? fechaNacimientoIso;
    if (widget.role == AppRole.client) {
      final fechaRaw = _fechaNacimientoCtrl.text.trim();
      if (fechaRaw.isNotEmpty) {
        final dt = _parseDisplay(fechaRaw);
        if (dt == null) {
          AppToast.showError(context, 'La fecha de nacimiento no es válida. Usa el formato dd/mm/aaaa');
          return;
        }
        final edad = _edadEnAnios(dt, DateTime.now());
        if (edad < 8) {
          AppToast.showError(context, 'El usuario debe tener al menos 8 años');
          return;
        }
        if (edad > 70) {
          AppToast.showError(context, 'La fecha de nacimiento ingresada no es válida');
          return;
        }
        fechaNacimientoIso =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }

    setState(() => _saving = true);

    try {
      final docCombinado = '$_tipoDocumento ${_documentoCtrl.text.trim()}';

      if (widget.role == AppRole.barber) {
        final currentBarber = widget.entidadActual as Barbero?;
        final barbero = Barbero(
          id: currentBarber?.id,
          usuarioId: currentBarber?.usuarioId,
          documento: docCombinado,
          nombre: _nombreCtrl.text.trim(),
          apellido: _apellidoCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          fechaIngreso: currentBarber?.fechaIngreso,
          estado: true,
        );

        if (currentBarber == null || currentBarber.id == null) {
          await _barberoService.crearBarbero(barbero);
        } else {
          await _barberoService.actualizarBarbero(barbero);
        }
      } else if (widget.role == AppRole.client) {
        final currentClient = widget.entidadActual as Cliente?;
        final cliente = Cliente(
          id: currentClient?.id,
          usuarioId: currentClient?.usuarioId,
          documento: docCombinado,
          nombre: _nombreCtrl.text.trim(),
          apellido: _apellidoCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          barrio: _barrioCtrl.text.trim().isEmpty ? null : _barrioCtrl.text.trim(),
          fechaNacimiento: fechaNacimientoIso,
          estado: true,
        );

        if (currentClient == null || currentClient.id == null) {
          await _clienteService.crearCliente(cliente);
        } else {
          await _clienteService.actualizarCliente(cliente);
        }
      }

      if (mounted) {
        setState(() => _saving = false);
        AppToast.showSuccess(context, 'Tus cambios se han guardado correctamente.');
        Navigator.pop(context, true); // true indica exito para recargar
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.showError(context, limpiarError(e));
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() => _saving = true);
      try {
        int? userId;
        if (widget.role == AppRole.barber && widget.entidadActual is Barbero) {
          userId = (widget.entidadActual as Barbero).usuarioId;
        } else if (widget.role == AppRole.client && widget.entidadActual is Cliente) {
          userId = (widget.entidadActual as Cliente).usuarioId;
        }
        
        if (userId != null) {
          final resFoto = await _mediaService.subirFotoPerfil(userId, image.path);
          if (mounted) {
            AppToast.showSuccess(context, 'La imagen se ha subido correctamente.');
            setState(() {
              _nuevaFotoFile = File(image.path);
              _fotoPerfil = resFoto; // En caso de que la API devuelva la URL
            });
            // Opcional: _save() aqui para guardar todo
          }
        } else {
          if (mounted) AppToast.showError(context, 'No se pudo obtener el ID de usuario.');
        }
      } catch (e) {
        if (mounted) AppToast.showError(context, limpiarError(e));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.white, size: 18),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Actualizar perfil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 38), // balance spacer
                ],
              ),
            ),
            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Avatar
                    Center(child: _buildAvatar()),
                    const SizedBox(height: 22),
                    // Section title
                    const Text(
                      'Datos personales',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Fields
                    if (_documentoEditable) _tipoDocumentoDropdown(),
                    _inputField(
                      label: _documentoEditable ? 'Número de documento *' : 'Documento (Protegido)',
                      ctrl: _documentoCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: !_documentoEditable,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(18),
                      ],
                    ),
                    _inputField(label: 'Nombre *',     ctrl: _nombreCtrl),
                    _inputField(label: 'Apellido *',   ctrl: _apellidoCtrl),
                    _inputField(label: 'Teléfono',     ctrl: _telefonoCtrl, keyboardType: TextInputType.phone),
                    _inputField(label: 'Email *',      ctrl: _emailCtrl,    keyboardType: TextInputType.emailAddress, readOnly: true), // Email read only usually, but allowed by their backend maybe
                    _inputField(
                      label: 'Dirección',
                      ctrl: _direccionCtrl,
                      hint: 'Ej: Calle 10 # 5-20',
                      isLast: widget.role != AppRole.client,
                    ),
                    if (widget.role == AppRole.client) ...[
                      _inputField(
                        label: 'Barrio',
                        ctrl: _barrioCtrl,
                        hint: 'Ej: El Centro',
                      ),
                      _dateField(
                        label: 'Fecha de nacimiento',
                        ctrl: _fechaNacimientoCtrl,
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Save button
                    _saveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar with camera ────────────────────────────────────────────────────
  Widget _buildAvatar() {
    String? networkFotoUrl;
    if (_fotoPerfil != null && _fotoPerfil!.isNotEmpty) {
      if (_fotoPerfil!.startsWith('http')) {
        networkFotoUrl = _fotoPerfil;
      } else {
        final rootUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        final separator = _fotoPerfil!.startsWith('/') ? '' : '/';
        networkFotoUrl = '$rootUrl$separator$_fotoPerfil';
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _saving ? null : _pickAndUploadImage,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.greyLight, width: 2.5),
              color: const Color(0xFF3A2E25),
              image: _nuevaFotoFile != null 
                  ? DecorationImage(image: FileImage(_nuevaFotoFile!), fit: BoxFit.cover)
                  : (networkFotoUrl != null 
                      ? DecorationImage(image: NetworkImage(networkFotoUrl), fit: BoxFit.cover)
                      : null),
            ),
            child: _nuevaFotoFile == null && networkFotoUrl == null
              ? ClipOval(
                  child: Container(
                    color: const Color(0xFF3A2E25),
                    child: const Icon(Icons.person, size: 54, color: Colors.white30),
                  ),
                )
              : null,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _saving ? null : _pickAndUploadImage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: const Text(
              'Cambiar foto de perfil',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'JPG o PNG. Máx. 5MB',
          style: TextStyle(color: AppColors.grey, fontSize: 11),
        ),
      ],
    );
  }

  // ── Tipo de documento dropdown ────────────────────────────────────────────
  Widget _tipoDocumentoDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _tipoDocumento,
        dropdownColor: AppColors.card,
        style: const TextStyle(color: AppColors.white, fontSize: 15),
        iconEnabledColor: AppColors.grey,
        decoration: InputDecoration(
          labelText: 'Tipo de documento',
          labelStyle: const TextStyle(color: AppColors.grey, fontSize: 12),
          filled: true,
          fillColor: AppColors.inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
        items: _tiposDocumento.map((t) => DropdownMenuItem(
          value: t,
          child: Text(t, style: const TextStyle(color: AppColors.white)),
        )).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _tipoDocumento = val);
        },
      ),
    );
  }

  // ── Date field ────────────────────────────────────────────────────────────
  Widget _dateField({
    required String label,
    required TextEditingController ctrl,
  }) {
    Future<void> abrirCalendario() async {
      // Rango permitido: entre 8 y 70 años (igual que la web/backend).
      final now = DateTime.now();
      final DateTime firstDate = DateTime(now.year - 70, now.month, now.day);
      final DateTime lastDate = DateTime(now.year - 8, now.month, now.day);
      DateTime initial = DateTime(now.year - 18, now.month, now.day);
      final actual = _parseDisplay(ctrl.text.trim());
      if (actual != null) initial = actual;
      // Aseguramos que initialDate quede dentro del rango para evitar el assert de Flutter.
      if (initial.isBefore(firstDate)) initial = firstDate;
      if (initial.isAfter(lastDate)) initial = lastDate;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        // Solo calendario: evita el modo de texto que exige "/" y muestra "formato no válido".
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        locale: const Locale('es', 'CO'),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.bg,
              surface: AppColors.card,
              onSurface: AppColors.white,
            ),
            dialogBackgroundColor: AppColors.card,
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        ctrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        setState(() {});
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        // Inserta las barras automáticamente mientras se escribe: 18012007 -> 18/01/2007
        inputFormatters: [_FechaInputFormatter()],
        style: const TextStyle(color: AppColors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'dd/mm/aaaa',
          labelStyle: const TextStyle(color: AppColors.grey, fontSize: 12),
          hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
          filled: true,
          fillColor: AppColors.inputBg,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: AppColors.grey, size: 18),
            onPressed: abrirCalendario,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Input field ───────────────────────────────────────────────────────────
  Widget _inputField({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool isLast = false,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            readOnly: readOnly,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            style: TextStyle(color: readOnly ? AppColors.grey : AppColors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: const TextStyle(color: AppColors.grey, fontSize: 12),
              hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
              filled: true,
              fillColor: readOnly ? AppColors.inputBg.withOpacity(0.5) : AppColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: readOnly ? AppColors.inputBorder : AppColors.gold, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _saveButton() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _saving ? AppColors.gold.withOpacity(0.6) : AppColors.gold,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.bg,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Guardar cambios',
                  style: TextStyle(
                    color: AppColors.bg,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Inserta automáticamente las barras para que la fecha quede como dd/MM/aaaa
/// mientras el usuario escribe solo dígitos (ej: 18012007 -> 18/01/2007).
class _FechaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      // Barra después del día (i==1) y del mes (i==3), sin dejarla colgando al final.
      if ((i == 1 || i == 3) && i != limited.length - 1) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
