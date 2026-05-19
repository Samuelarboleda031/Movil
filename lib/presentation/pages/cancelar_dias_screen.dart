import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:parte_movil/core/themes/app_colors.dart";
import "package:parte_movil/data/models/app_role.dart";
import "package:parte_movil/data/models/barbero.dart";
import "package:parte_movil/data/datasources/barbero_service.dart";
import "package:parte_movil/data/datasources/user_context_service.dart";
import "package:parte_movil/presentation/widgets/searchable_selector.dart";
import "package:parte_movil/core/utils/app_snackbar.dart";

class CancelarDiasScreen extends StatefulWidget {
  final AppRole role;
  const CancelarDiasScreen({super.key, required this.role});

  @override
  State<CancelarDiasScreen> createState() => _CancelarDiasScreenState();
}

class _CancelarDiasScreenState extends State<CancelarDiasScreen> {
  int _currentTab = 0;
  Barbero? _barberoSeleccionado;
  bool _isLoadingBarberos = true;
  List<Barbero> _barberos = [];

  // -- estado para por hora --
  DateTime? _fechaHora;       // fecha del tab "Un Día"
  DateTime _pickerInicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0);
  DateTime _pickerFin    = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 18, 0);
  // -- estado para varios días (rango) --
  DateTime? _rangoDesde;
  DateTime? _rangoHasta;
  int _rangoFoco = 0; // 0 = seleccionando Desde, 1 = seleccionando Hasta
  late DateTime _calendarMonth;
  final TextEditingController _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _loadData();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (widget.role == AppRole.barber) {
        final barbero = await UserContextService().obtenerBarberoActual();
        if (mounted) {
          setState(() {
            _barberoSeleccionado = barbero;
            _isLoadingBarberos = false;
          });
        }
      } else {
        final barberos = await BarberoService().obtenerBarberos();
        if (mounted) {
          setState(() {
            _barberos = barberos;
            _isLoadingBarberos = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBarberos = false);
    }
  }

  bool get _esGlobal => _barberoSeleccionado?.id == -1;

  void _confirmar() {
    if (widget.role != AppRole.barber && _barberoSeleccionado == null) {
      AppToast.showError(context, "Selecciona un barbero");
      return;
    }

    List<DateTime> fechas = [];
    String? horaInicio;
    String? horaFin;

    if (_currentTab == 0) {
      // La fecha viene de _pickerInicio (mismo día para ambos)
      final fecha = DateTime(_pickerInicio.year, _pickerInicio.month, _pickerInicio.day);
      if (_pickerInicio.isAfter(_pickerFin) ||
          (_pickerInicio.hour * 60 + _pickerInicio.minute) >= (_pickerFin.hour * 60 + _pickerFin.minute)) {
        AppToast.showError(context, "La hora de inicio debe ser anterior a la hora de fin");
        return;
      }
      fechas = [fecha];
      horaInicio = "${_pickerInicio.hour.toString().padLeft(2, "0")}:${_pickerInicio.minute.toString().padLeft(2, "0")}";
      horaFin    = "${_pickerFin.hour.toString().padLeft(2, "0")}:${_pickerFin.minute.toString().padLeft(2, "0")}";
    } else if (_currentTab == 1) {
      if (_fechaHora == null) {
        AppToast.showError(context, "Selecciona una fecha");
        return;
      }
      fechas = [_fechaHora!];
    } else {
      // Varios días: generar lista de fechas del rango
      if (_rangoDesde == null) {
        AppToast.showError(context, "Selecciona la fecha de inicio");
        return;
      }
      final fin = _rangoHasta ?? _rangoDesde!;
      // Generar todos los días del rango
      final diff = fin.difference(_rangoDesde!).inDays;
      fechas = List.generate(diff + 1, (i) => _rangoDesde!.add(Duration(days: i)));
    }

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    for (final f in fechas) {
      if (f.isBefore(todayNorm)) {
        AppToast.showError(context, "No puedes seleccionar fechas del pasado");
        return;
      }
    }

    Navigator.pop(context, {
      "barbero": _barberoSeleccionado,
      "fechas": fechas,
      "motivo": _motivoController.text.trim(),
      "horaInicio": horaInicio,
      "horaFin": horaFin,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.gold, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.role == AppRole.barber ? "CANCELAR MIS CITAS" : (_esGlobal ? "CANCELACION GLOBAL" : "CANCELAR POR BARBERO"),
              style: TextStyle(
                color: _esGlobal ? Colors.orange : AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              widget.role == AppRole.barber ? "Selecciona los dias a cancelar" : "Selecciona barbero y dias",
              style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: _isLoadingBarberos
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.role != AppRole.barber) ...[
                            _buildSectionLabel("1. BARBERO"),
                            const SizedBox(height: 10),
                            SearchableSelector<Barbero>(
                              label: "Barbero",
                              hint: "Seleccionar...",
                              items: [
                                Barbero(id: -1, nombre: "Todos los barberos", apellido: "", documento: "", estado: true),
                                ..._barberos,
                              ],
                              selectedItem: _barberoSeleccionado,
                              displayText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                              searchText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                              onSelected: (b) => setState(() => _barberoSeleccionado = b),
                            ),
                            const SizedBox(height: 28),
                            _buildSectionLabel("2. TIPO DE CANCELACION"),
                          ] else ...[
                            if (_barberoSeleccionado != null)
                              _buildBarberoInfo(),
                            const SizedBox(height: 24),
                            _buildSectionLabel("TIPO DE CANCELACION"),
                          ],
                          const SizedBox(height: 12),
                          _buildTabSelector(),
                          const SizedBox(height: 20),
                          _buildTabContent(),
                          const SizedBox(height: 24),
                          _buildSectionLabel(widget.role != AppRole.barber ? "3. MOTIVO" : "MOTIVO"),
                          const SizedBox(height: 10),
                          _buildMotivoField(),
                          if (_esGlobal) ...[
                            const SizedBox(height: 12),
                            _buildGlobalWarning(),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildConfirmButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.gold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildBarberoInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Barbero", style: TextStyle(color: AppColors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                _barberoSeleccionado?.nombreCompleto ?? "Yo",
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = [
      {"icon": Icons.access_time_rounded, "label": "Por Hora"},
      {"icon": Icons.calendar_today_rounded, "label": "Un Dia"},
      {"icon": Icons.date_range_rounded, "label": "Varios Dias"},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _currentTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _currentTab = i;
                _fechaHora = null;
                _rangoDesde = null;
                _rangoHasta = null;
                _rangoFoco = 0;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.gold.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive ? Border.all(color: AppColors.gold.withOpacity(0.4)) : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      tabs[i]["icon"] as IconData,
                      color: isActive ? AppColors.gold : AppColors.grey,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[i]["label"] as String,
                      style: TextStyle(
                        color: isActive ? AppColors.gold : AppColors.grey,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildPorHoraContent();
      case 1:
        return _buildUnDiaContent();
      case 2:
        return _buildVariosDiasContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPorHoraContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(Icons.info_outline,
            "Cancela citas dentro de un rango de horas en una fecha especifica."),
        const SizedBox(height: 20),
        // -- Tarjeta Inicio --
        _buildScrollPickerCard(
          label: "Inicio",
          value: _pickerInicio,
          accentColor: AppColors.gold,
          onTap: () => _showCupertinoPickerSheet(
            initial: _pickerInicio,
            onChanged: (dt) => setState(() {
              _pickerInicio = dt;
              _pickerFin = DateTime(dt.year, dt.month, dt.day, _pickerFin.hour, _pickerFin.minute);
            }),
          ),
        ),
        const SizedBox(height: 12),
        // -- Tarjeta Fin --
        _buildScrollPickerCard(
          label: "Fin",
          value: _pickerFin,
          accentColor: Colors.redAccent,
          onTap: () => _showCupertinoPickerSheet(
            initial: DateTime(_pickerInicio.year, _pickerInicio.month, _pickerInicio.day, _pickerFin.hour, _pickerFin.minute),
            onChanged: (dt) => setState(() {
              _pickerFin = DateTime(_pickerInicio.year, _pickerInicio.month, _pickerInicio.day, dt.hour, dt.minute);
            }),
          ),
        ),
      ],
    );
  }

  // -- Tarjeta que muestra fecha + hora seleccionada -----------------------
  Widget _buildScrollPickerCard({
    required String label,
    required DateTime value,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final now = DateTime.now();
    final isToday = value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final dateLabel = isToday
        ? "Hoy"
        : DateFormat("EEE, d MMM yyyy", "es").format(value);
    final timeLabel = DateFormat("hh:mm a", "es").format(value);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(dateLabel,
                      style: const TextStyle(
                          color: AppColors.greyLight, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(timeLabel,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: accentColor.withValues(alpha: 0.6), size: 18),
          ],
        ),
      ),
    );
  }

  // -- Bottom sheet con CupertinoDatePicker --------------------------------
  void _showCupertinoPickerSheet({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  }) {
    DateTime temp = initial;
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    if (temp.isBefore(todayNorm)) {
      temp = todayNorm;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 12,
            right: 12,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header con fecha seleccionada
              StatefulBuilder(builder: (ctx, setSheet) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat("EEE, d MMM yyyy", "es").format(temp),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.dateAndTime,
                        initialDateTime: temp,
                        minimumDate: todayNorm,
                        maximumDate: todayNorm.add(const Duration(days: 365)),
                        minimumYear: todayNorm.year,
                        maximumYear: todayNorm.year + 1,
                        use24hFormat: false,
                        minuteInterval: 1,
                        backgroundColor: Colors.transparent,
                        onDateTimeChanged: (dt) {
                          temp = dt;
                          setSheet(() {});
                        },
                      ),
                    ),
                    // Botones Cancelar / Aceptar
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(
                                    color: AppColors.gold, fontSize: 17),
                              ),
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 48,
                              color: AppColors.divider.withValues(alpha: 0.5)),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                onChanged(temp);
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                "Aceptar",
                                style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              }),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildUnDiaContent() {
    final now = DateTime.now();
    final isToday = _fechaHora != null &&
        _fechaHora!.year == now.year &&
        _fechaHora!.month == now.month &&
        _fechaHora!.day == now.day;
    final dateLabel = _fechaHora == null
        ? "Seleccionar fecha"
        : isToday
            ? "Hoy"
            : DateFormat("EEEE, d MMMM yyyy", "es").format(_fechaHora!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(Icons.info_outline, "Cancela todas las citas en una fecha especifica."),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            final todayNorm = DateTime(now.year, now.month, now.day);
            DateTime temp = _fechaHora ?? todayNorm;
            if (temp.isBefore(todayNorm)) {
              temp = todayNorm;
            }
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (ctx) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  left: 12,
                  right: 12,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    StatefulBuilder(builder: (ctx, setSheet) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                DateFormat("EEE, d MMM yyyy", "es").format(temp),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 220,
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: temp,
                              minimumDate: todayNorm,
                              maximumDate: todayNorm.add(const Duration(days: 365)),
                              minimumYear: todayNorm.year,
                              maximumYear: todayNorm.year + 1,
                              backgroundColor: Colors.transparent,
                              onDateTimeChanged: (dt) {
                                temp = dt;
                                setSheet(() {});
                              },
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text(
                                      "Cancelar",
                                      style: TextStyle(color: AppColors.gold, fontSize: 17),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 48, color: AppColors.divider.withValues(alpha: 0.5)),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() => _fechaHora = temp);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      "Aceptar",
                                      style: TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _fechaHora != null
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: _fechaHora != null ? AppColors.gold : AppColors.grey, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Fecha", style: TextStyle(color: AppColors.grey, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          color: _fechaHora != null ? AppColors.white : AppColors.grey,
                          fontSize: 14,
                          fontWeight: _fechaHora != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.grey, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVariosDiasContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(Icons.info_outline, "Selecciona un rango de fechas. Todas las citas dentro del rango seran canceladas."),
        const SizedBox(height: 16),
        // -- Campos Desde / Hasta estilo LATAM --
        _buildRangeFields(),
        const SizedBox(height: 20),
        // -- Calendario inline --
        _buildInlineCalendar(),
      ],
    );
  }

  // -- Campos Desde / Hasta ------------------------------------------------
  Widget _buildRangeFields() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(child: _buildRangeField(isDesde: true)),
          Container(width: 1, height: 56, color: AppColors.divider),
          Expanded(child: _buildRangeField(isDesde: false)),
        ],
      ),
    );
  }

  Widget _buildRangeField({required bool isDesde}) {
    final isActive = _rangoFoco == (isDesde ? 0 : 1);
    final date = isDesde ? _rangoDesde : _rangoHasta;
    final label = isDesde ? "Desde" : "Hasta";

    return GestureDetector(
      onTap: () => setState(() => _rangoFoco = isDesde ? 0 : 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.horizontal(
            left: isDesde ? const Radius.circular(16) : Radius.zero,
            right: isDesde ? Radius.zero : const Radius.circular(16),
          ),
          color: isActive ? AppColors.gold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? AppColors.gold : AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date != null
                        ? DateFormat("EEE. dd MMM", "es").format(date)
                        : "Seleccionar",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: date != null ? AppColors.white : AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: isActive ? AppColors.gold : AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // -- Calendario inline ---------------------------------------------------
  Widget _buildInlineCalendar() {
    return Column(
      children: [
        // Navegación de mes
        _buildMonthNav(),
        const SizedBox(height: 12),
        // Cabecera días de semana
        _buildWeekHeader(),
        const SizedBox(height: 8),
        // Grid del mes actual
        _buildMonthGrid(_calendarMonth),
        const SizedBox(height: 24),
        // Mes siguiente
        _buildMonthGrid(DateTime(_calendarMonth.year, _calendarMonth.month + 1)),
      ],
    );
  }

  Widget _buildMonthNav() {
    final today = DateTime.now();
    final currentMonthLimit = DateTime(today.year, today.month);
    final isPrevDisabled = _calendarMonth.year < currentMonthLimit.year ||
        (_calendarMonth.year == currentMonthLimit.year && _calendarMonth.month <= currentMonthLimit.month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: isPrevDisabled ? null : () => setState(() {
            _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
          }),
          icon: Icon(
            Icons.chevron_left,
            color: isPrevDisabled ? AppColors.grey.withOpacity(0.3) : AppColors.gold,
          ),
        ),
        Text(
          _monthLabel(_calendarMonth),
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () => setState(() {
            _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
          }),
          icon: const Icon(Icons.chevron_right, color: AppColors.gold),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    const days = ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Título del mes (para el segundo mes)
    final isSecondMonth = month.month != _calendarMonth.month || month.year != _calendarMonth.year;

    // Primer día del mes (weekday: 1=lunes  7=domingo)
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // Offset: lunes=0, martes=1  domingo=6
    final offset = (firstDay.weekday - 1) % 7;

    final cells = <Widget>[];

    // Celdas vacías al inicio
    for (int i = 0; i < offset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isPast = date.isBefore(todayNorm);
      cells.add(_buildDayCell(date, isPast));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSecondMonth) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _monthLabel(month),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }

  Widget _buildDayCell(DateTime date, bool isPast) {
    final desde = _rangoDesde;
    final hasta = _rangoHasta ?? _rangoDesde;

    final isStart = desde != null && _isSameDay(date, desde);
    final isEnd = hasta != null && _isSameDay(date, hasta);
    final isInRange = desde != null &&
        hasta != null &&
        date.isAfter(desde) &&
        date.isBefore(hasta);

    Color bgColor = Colors.transparent;
    Color textColor = isPast ? AppColors.grey.withValues(alpha: 0.35) : AppColors.white;
    bool showCircle = false;

    if (isStart || isEnd) {
      bgColor = Colors.redAccent;
      textColor = Colors.white;
      showCircle = true;
    } else if (isInRange) {
      bgColor = Colors.redAccent.withValues(alpha: 0.18);
      textColor = AppColors.white;
    }

    return GestureDetector(
      onTap: isPast ? null : () => _onDayTap(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          shape: showCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: showCircle ? null : BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            "${date.day}",
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: (isStart || isEnd) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _onDayTap(DateTime date) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    if (date.isBefore(todayNorm)) return;

    setState(() {
      if (_rangoFoco == 0) {
        // Seleccionando Desde
        _rangoDesde = date;
        _rangoHasta = null;
        _rangoFoco = 1; // Mover foco a Hasta
      } else {
        // Seleccionando Hasta
        if (_rangoDesde != null && date.isBefore(_rangoDesde!)) {
          // Si elige antes del inicio, intercambiar
          _rangoHasta = _rangoDesde;
          _rangoDesde = date;
        } else {
          _rangoHasta = date;
        }
        _rangoFoco = 0;
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime month) {
    const meses = [
      "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
      "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ];
    return "${meses[month.month - 1]} ${month.year}";
  }

  Widget _buildInfoBanner(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.greyLight, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivoField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: _motivoController,
        style: const TextStyle(color: AppColors.white, fontSize: 14),
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: "Ej: Dia festivo, mantenimiento...",
          hintStyle: TextStyle(color: AppColors.grey, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildGlobalWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Esta accion cancelara las citas de TODOS los barberos en los dias seleccionados.",
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 20),
                SizedBox(width: 10),
                Text(
                  "CONFIRMAR CANCELACION",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
