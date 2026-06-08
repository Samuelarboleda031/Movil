import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/credito_barbero_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/app_role.dart';

class CreditoNotificationBell extends StatefulWidget {
  final AppRole role;

  const CreditoNotificationBell({super.key, required this.role});

  @override
  State<CreditoNotificationBell> createState() =>
      _CreditoNotificationBellState();
}

class _CreditoNotificationBellState extends State<CreditoNotificationBell> {
  final CreditoBarberoService _service = CreditoBarberoService();
  final UserContextService _userContext = UserContextService();
  final AuthService _authService = AuthService();

  // Admin/Manager: lista de créditos con atención requerida
  List<CreditoBarberoInfo> _alertas = [];

  // Barbero: su propio crédito
  CreditoBarberoInfo? _miCredito;
  int? _miBarberoId;

  // ID del usuario autenticado en la API (para acciones de admin)
  int? _usuarioApiId;

  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == AppRole.client) return;
    _init();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Obtener usuario de la API (para el usuarioId en acciones de admin)
    final apiUser = await _authService.getCurrentUser();
    if (mounted) _usuarioApiId = apiUser?.id;

    if (widget.role == AppRole.barber) {
      final barbero = await _userContext.obtenerBarberoActual();
      if (barbero?.id != null) _miBarberoId = barbero!.id;
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_isLoading || !mounted) return;
    _isLoading = true;
    try {
      if (widget.role == AppRole.barber) {
        if (_miBarberoId == null) return;
        final credito = await _service.obtenerPorBarbero(_miBarberoId!);
        if (mounted) setState(() => _miCredito = credito);
      } else {
        final todos = await _service.obtenerBloqueados();
        if (mounted) setState(() => _alertas = todos);
      }
    } catch (_) {
    } finally {
      _isLoading = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Vista admin / manager
  // ──────────────────────────────────────────────────────────────────────────

  void _mostrarModalAdmin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ModalAdminCredito(
        alertas: _alertas,
        service: _service,
        usuarioId: _usuarioApiId,
        onRefresh: _fetch,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Vista barbero
  // ──────────────────────────────────────────────────────────────────────────

  void _mostrarModalBarbero() {
    if (_miCredito == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ModalBarberoCredito(credito: _miCredito!),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.role == AppRole.client) return const SizedBox.shrink();

    if (widget.role == AppRole.barber) {
      final mostrar =
          (_miCredito?.estaBloqueado ?? false) ||
          (_miCredito?.estaVencido ?? false) ||
          (_miCredito?.venceProximo ?? false);
      if (!mostrar) return const SizedBox.shrink();

      final color = (_miCredito?.estaBloqueado ?? false) ||
              (_miCredito?.estaVencido ?? false)
          ? AppColors.red
          : Colors.orange;

      return Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.credit_card_off_outlined),
            color: color,
            tooltip: 'Alerta de crédito',
            onPressed: _mostrarModalBarbero,
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      );
    }

    // Admin / Manager
    final count = _alertas.length;
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.credit_card_outlined),
          color: count > 0 ? AppColors.red : AppColors.white,
          tooltip: count > 0
              ? '$count barbero${count == 1 ? '' : 's'} con crédito bloqueado'
              : 'Créditos de barberos',
          onPressed: _mostrarModalAdmin,
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Modal para Admin / Manager
// ════════════════════════════════════════════════════════════════════════════

class _ModalAdminCredito extends StatefulWidget {
  final List<CreditoBarberoInfo> alertas;
  final CreditoBarberoService service;
  final int? usuarioId;
  final Future<void> Function() onRefresh;

  const _ModalAdminCredito({
    required this.alertas,
    required this.service,
    required this.usuarioId,
    required this.onRefresh,
  });

  @override
  State<_ModalAdminCredito> createState() => _ModalAdminCreditoState();
}

class _ModalAdminCreditoState extends State<_ModalAdminCredito> {
  late List<CreditoBarberoInfo> _lista;
  bool _refrescando = false;

  @override
  void initState() {
    super.initState();
    _lista = List.from(widget.alertas);
  }

  Future<void> _refresh() async {
    setState(() => _refrescando = true);
    await widget.onRefresh();
    if (mounted) setState(() => _refrescando = false);
  }

  Future<void> _extenderPlazo(CreditoBarberoInfo info) async {
    final uid = widget.usuarioId;
    if (uid == null) {
      _snack('No se pudo identificar al usuario admin.');
      return;
    }
    final confirmar = await _dialogConfirm(
      titulo: 'Extender plazo',
      mensaje:
          '¿Extender el plazo de crédito de ${info.barberoNombre ?? 'este barbero'}?\n'
          'Solo se puede usar una vez por ciclo.',
    );
    if (!confirmar) return;

    final ok = await widget.service.extenderPlazo(info.barberoId, uid);
    if (ok) {
      _snack('Plazo extendido correctamente.');
      await _refresh();
    } else {
      _snack('No se pudo extender el plazo.', error: true);
    }
  }

  Future<void> _nuevoCiclo(CreditoBarberoInfo info) async {
    final uid = widget.usuarioId;
    if (uid == null) {
      _snack('No se pudo identificar al usuario admin.');
      return;
    }
    final confirmar = await _dialogConfirm(
      titulo: 'Nuevo ciclo',
      mensaje:
          '¿Iniciar un nuevo ciclo de crédito para ${info.barberoNombre ?? 'este barbero'}?\n'
          'Esto cerrará el ciclo actual.',
    );
    if (!confirmar) return;

    final ok = await widget.service.nuevoCiclo(
      info.barberoId,
      uid,
      plazoDias: info.plazoDias,
    );
    if (ok) {
      _snack('Nuevo ciclo iniciado.');
      await _refresh();
    } else {
      _snack('No se pudo iniciar el nuevo ciclo.', error: true);
    }
  }

  Future<bool> _dialogConfirm(
      {required String titulo, required String mensaje}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(titulo,
            style: const TextStyle(color: AppColors.white, fontSize: 16)),
        content: Text(mensaje,
            style: const TextStyle(color: AppColors.grey, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Confirmar', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.red : AppColors.gold,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_card_off,
                        color: AppColors.red, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Créditos bloqueados',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_lista.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.red.withOpacity(0.4)),
                        ),
                        child: Text(
                          '${_lista.length}',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _refrescando ? null : _refresh,
                      child: Icon(
                        Icons.refresh,
                        color: _refrescando ? AppColors.grey : AppColors.gold,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Barberos que superaron su cupo de crédito',
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _lista.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48,
                              color: AppColors.grey.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'Todo en orden',
                            style:
                                TextStyle(color: AppColors.white, fontSize: 15),
                          ),
                          const Text(
                            'Ningún barbero tiene crédito bloqueado',
                            style: TextStyle(
                                color: AppColors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _lista.length,
                      itemBuilder: (_, i) => _TarjetaBloqueadoAdmin(
                        info: _lista[i],
                        onExtender: () => _extenderPlazo(_lista[i]),
                        onNuevoCiclo: () => _nuevoCiclo(_lista[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaBloqueadoAdmin extends StatelessWidget {
  final CreditoBarberoInfo info;
  final VoidCallback onExtender;
  final VoidCallback onNuevoCiclo;

  const _TarjetaBloqueadoAdmin({
    required this.info,
    required this.onExtender,
    required this.onNuevoCiclo,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (info.porcentajeUso * 100).toStringAsFixed(0);
    final dias = info.diasParaVencer;
    final String vencimientoLabel = info.fechaVencimiento != null
        ? 'Vence: ${DateFormat('dd/MM/yy').format(info.fechaVencimiento!)}'
        : '';
    final String diasLabel = dias == null
        ? ''
        : dias < 0
            ? 'Venció hace ${(-dias)} día${(-dias) == 1 ? '' : 's'}'
            : dias == 0
                ? 'Vence hoy'
                : 'Vence en $dias día${dias == 1 ? '' : 's'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.person, color: AppColors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.barberoNombre ?? 'Barbero #${info.barberoId}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        _Chip(label: info.estado, color: AppColors.red),
                        if (info.extensionUsada)
                          _Chip(label: 'Extensión usada', color: Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${_fmt(info.saldoDeuda)}',
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'de \$${_fmt(info.cupoMaximo)}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fechas y plazo
          if (vencimientoLabel.isNotEmpty || diasLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (vencimientoLabel.isNotEmpty)
                    Text(
                      vencimientoLabel,
                      style:
                          const TextStyle(color: AppColors.grey, fontSize: 11),
                    ),
                  if (vencimientoLabel.isNotEmpty && diasLabel.isNotEmpty)
                    const Text('  ·  ',
                        style:
                            TextStyle(color: AppColors.grey, fontSize: 11)),
                  if (diasLabel.isNotEmpty)
                    Text(
                      diasLabel,
                      style: TextStyle(
                        color: (dias != null && dias < 0)
                            ? AppColors.red
                            : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: info.porcentajeUso,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.red),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$pct% del cupo utilizado',
              style: const TextStyle(color: AppColors.grey, fontSize: 11),
            ),
          ),

          // Acciones
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Extender plazo',
                  icon: Icons.more_time,
                  color: Colors.orange,
                  enabled: !info.extensionUsada &&
                      info.estado == 'BloqueadoVencimiento',
                  onTap: onExtender,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Nuevo ciclo',
                  icon: Icons.refresh,
                  color: AppColors.gold,
                  enabled: info.saldoDeuda == 0,
                  onTap: onNuevoCiclo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : AppColors.grey;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: effectiveColor.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveColor, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Modal para Barbero
// ════════════════════════════════════════════════════════════════════════════

class _ModalBarberoCredito extends StatelessWidget {
  final CreditoBarberoInfo credito;

  const _ModalBarberoCredito({required this.credito});

  @override
  Widget build(BuildContext context) {
    final pct = (credito.porcentajeUso * 100).toStringAsFixed(0);
    final dias = credito.diasParaVencer;

    String titulo = 'Tu crédito está bloqueado';
    String subtitulo =
        'Has superado tu cupo máximo de crédito.\nContacta al administrador para realizar un abono.';
    Color accentColor = AppColors.red;
    IconData icono = Icons.credit_card_off;

    if (credito.estaVencido && !credito.estaBloqueado) {
      titulo = 'Tu crédito está vencido';
      subtitulo =
          'El plazo de pago venció. Contacta al administrador para regularizar.';
    } else if (credito.venceProximo) {
      titulo = 'Tu crédito vence pronto';
      subtitulo = dias == 0
          ? 'Tu crédito vence hoy. Realiza un abono cuanto antes.'
          : 'Tu crédito vence en $dias día${dias == 1 ? '' : 's'}. Realiza un abono.';
      accentColor = Colors.orange;
      icono = Icons.access_time_outlined;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Ícono
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Icon(icono, color: accentColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.grey, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Detalle del crédito
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _fila('Saldo de deuda', '\$${_fmt(credito.saldoDeuda)}',
                      valueColor: AppColors.red),
                  const SizedBox(height: 8),
                  _fila('Cupo máximo', '\$${_fmt(credito.cupoMaximo)}'),
                  const SizedBox(height: 8),
                  _fila('Cupo disponible', '\$${_fmt(credito.cupoDisponible)}'),
                  const SizedBox(height: 8),
                  _fila('Plazo', '${credito.plazoDias} días'),
                  if (credito.fechaVencimiento != null) ...[
                    const SizedBox(height: 8),
                    _fila(
                      'Vencimiento',
                      DateFormat('dd MMM yyyy').format(credito.fechaVencimiento!),
                      valueColor: (dias != null && dias <= 2)
                          ? Colors.orange
                          : AppColors.white,
                    ),
                  ],
                  if (credito.extensionUsada) ...[
                    const SizedBox(height: 8),
                    _fila('Extensión', 'Ya utilizada',
                        valueColor: Colors.orange),
                  ],
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: credito.porcentajeUso,
                      backgroundColor: AppColors.divider,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$pct% del cupo utilizado',
                      style:
                          const TextStyle(color: AppColors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.grey, fontSize: 13)),
        Text(
          valor,
          style: TextStyle(
            color: valueColor ?? AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      return s.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    }
    return v.toStringAsFixed(0);
  }
}
