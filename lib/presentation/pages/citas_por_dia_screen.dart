import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/models/agendamiento.dart';

class CitasPorDiaScreen extends StatefulWidget {
  final int barberoId;
  final String barberoNombre;
  final int diaSemana; // 0=Dom, 1=Lun, ..., 6=Sab
  final String horaInicio;
  final String horaFin;
  final Color accentColor;

  const CitasPorDiaScreen({
    super.key,
    required this.barberoId,
    required this.barberoNombre,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.accentColor = AppColors.gold,
  });

  @override
  State<CitasPorDiaScreen> createState() => _CitasPorDiaScreenState();
}

class _CitasPorDiaScreenState extends State<CitasPorDiaScreen> {
  bool _isLoading = true;
  Map<DateTime, List<Agendamiento>> _citasPorFecha = {};

  static const _nombresDias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  static const _meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  int _diaSemanaToWeekday(int dia) => dia == 0 ? 7 : dia;

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final result = await AgendamientoService().obtenerAgendamientos(page: 1, pageSize: 5000);
      final hoy = DateTime.now();
      final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
      final targetWeekday = _diaSemanaToWeekday(widget.diaSemana);

      final Map<DateTime, List<Agendamiento>> grouped = {};
      for (final cita in result.items) {
        if (cita.barberoId != widget.barberoId) continue;
        final fechaStr = cita.fechaCita;
        if (fechaStr == null || fechaStr.isEmpty) continue;
        final fecha = DateTime.tryParse(fechaStr);
        if (fecha == null) continue;
        final fechaSolo = DateTime(fecha.year, fecha.month, fecha.day);
        if (fechaSolo.isBefore(hoyDate)) continue;
        if (fechaSolo.weekday != targetWeekday) continue;
        final estado = (cita.estadoCita ?? '').toLowerCase().trim();
        if (estado == 'cancelada' || estado == 'cancelado') continue;

        grouped.putIfAbsent(fechaSolo, () => []).add(cita);
      }

      for (final list in grouped.values) {
        list.sort((a, b) => (a.horaInicio ?? '').compareTo(b.horaInicio ?? ''));
      }

      final sortedKeys = grouped.keys.toList()..sort();
      final sortedMap = {for (final k in sortedKeys) k: grouped[k]!};

      if (mounted) {
        setState(() {
          _citasPorFecha = sortedMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _estadoColor(String? estado) {
    switch ((estado ?? '').toLowerCase().trim()) {
      case 'completada':
      case 'completado':
      case 'finalizado':
        return Colors.green;
      case 'confirmada':
      case 'confirmado':
        return AppColors.gold;
      case 'en proceso':
      case 'en_proceso':
        return Colors.orange;
      default:
        return const Color(0xFF7EB5F4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diaNombre = _nombresDias[widget.diaSemana];
    final totalCitas = _citasPorFecha.values.fold<int>(0, (a, b) => a + b.length);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.bg,
            iconTheme: IconThemeData(color: widget.accentColor),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accentColor.withOpacity(0.20),
                      AppColors.bg,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: widget.accentColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                'PRÓXIMOS $diaNombre'.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.accentColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          diaNombre,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.barberoNombre,
                          style: const TextStyle(fontSize: 14, color: AppColors.greyLight),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStat(Icons.access_time_filled, '${widget.horaInicio} – ${widget.horaFin}'),
                            const SizedBox(width: 10),
                            _buildStat(Icons.event_available, '$totalCitas citas'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
            )
          else if (_citasPorFecha.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 56, color: AppColors.grey.withOpacity(0.6)),
                    const SizedBox(height: 14),
                    const Text('Sin citas próximas', style: TextStyle(color: AppColors.greyLight, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('No hay $diaNombre con citas agendadas', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final fecha = _citasPorFecha.keys.elementAt(i);
                    final citas = _citasPorFecha[fecha]!;
                    return _buildFechaGroup(fecha, citas);
                  },
                  childCount: _citasPorFecha.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: widget.accentColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.whiteSecondary)),
        ],
      ),
    );
  }

  Widget _buildFechaGroup(DateTime fecha, List<Agendamiento> citas) {
    final hoy = DateTime.now();
    final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
    final diff = fecha.difference(hoyDate).inDays;

    String relativo;
    if (diff == 0) {
      relativo = 'Hoy';
    } else if (diff == 7) {
      relativo = 'En 1 semana';
    } else if (diff < 7) {
      relativo = 'En $diff días';
    } else {
      relativo = 'En ${(diff / 7).floor()} sem.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${fecha.day}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.accentColor, height: 1),
                      ),
                      Text(
                        _meses[fecha.month - 1].toUpperCase(),
                        style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: widget.accentColor.withOpacity(0.8), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fecha.day} de ${_meses[fecha.month - 1]} ${fecha.year}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
                      ),
                      Text(
                        '$relativo · ${citas.length} cita${citas.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...citas.map((c) => _buildCitaCard(c)),
        ],
      ),
    );
  }

  Widget _buildCitaCard(Agendamiento c) {
    final color = _estadoColor(c.estadoCita);
    final hora = (c.horaInicio ?? '').isNotEmpty ? c.horaInicio! : '--:--';
    final cliente = c.clienteNombre ?? c.cliente?.nombre ?? 'Cliente #${c.clienteId}';
    final servicios = c.serviciosNombres.isNotEmpty ? c.serviciosNombres.join(' · ') : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 0.6),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral de hora
            Container(
              width: 70,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hora,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w700, color: color),
                  ),
                  if ((c.horaFin ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.horaFin!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.grey),
                    ),
                  ],
                ],
              ),
            ),
            // Info de la cita
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cliente,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (c.estadoCita ?? 'Pendiente'),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      servicios,
                      style: const TextStyle(fontSize: 11, color: AppColors.greyLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((c.monto ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        AppFormat.cop(c.monto!),
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: widget.accentColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
