import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agendamiento.dart';
import '../models/paginacion.dart';
import '../services/agendamiento_service.dart';
import '../services/emailjs_service.dart';
import 'agendamiento_form_screen.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';
import '../utils/app_format.dart';
import '../models/barbero.dart';
import '../services/auxiliar_service.dart';
import '../services/auth_service.dart';
import '../widgets/searchable_selector.dart';
import '../utils/app_snackbar.dart';

class AgendamientosScreen extends StatefulWidget {
  const AgendamientosScreen({super.key});

  @override
  State<AgendamientosScreen> createState() => _AgendamientosScreenState();
}

class _AgendamientosScreenState extends State<AgendamientosScreen> {
  final AgendamientoService _agendamientoService = AgendamientoService();
  final EmailJsService _emailJsService = EmailJsService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final AuthService _authService = AuthService();
  
  List<Agendamiento> _agendamientos = [];
  Paginacion<Agendamiento>? _ultimaPaginacion;
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 15;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarAgendamientos(1);
  }

  Future<void> _cargarAgendamientos(int page) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });
    try {
      final paginacion = await _agendamientoService.obtenerAgendamientos(page: page, pageSize: _pageSize);
      if (mounted) {
        setState(() {
          _agendamientos = paginacion.items;
          _ultimaPaginacion = paginacion;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Error al cargar agendamientos: $e');
      }
    }
  }

  List<Agendamiento> get _agendamientosFiltrados {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _agendamientos;
    return _agendamientos.where((a) {
      final cliente = a.cliente?.nombreCompleto.toLowerCase() ?? '';
      final barbero = a.barbero?.nombreCompleto.toLowerCase() ?? '';
      final servicio = a.servicio?.nombre.toLowerCase() ?? '';
      return cliente.contains(query) || barbero.contains(query) || servicio.contains(query);
    }).toList();
  }

  Future<void> _verDetalles(Agendamiento ag) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final detail = await _agendamientoService.obtenerAgendamientoPorId(ag.id!);
      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Detalles de la Cita'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow('Cliente:', detail.cliente?.nombreCompleto ?? 'N/A'),
                  _detailRow('Barbero:', detail.barbero?.nombreCompleto ?? 'N/A'),
                  _detailRow('Servicio:', detail.servicio?.nombre ?? detail.paquete?.nombre ?? 'N/A'),
                  _detailRow('Fecha:', detail.fechaCita ?? 'N/A'),
                  _detailRow('Hora:', '${detail.horaInicio} - ${detail.horaFin}'),
                  _detailRow('Monto:', AppFormat.cop(detail.monto ?? 0)),
                  _detailRow('Estado:', detail.estadoCita ?? 'Pendiente'),
                  const Divider(),
                  const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(detail.observaciones ?? 'Sin observaciones'),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      AppToast.showError(context, 'Error: $e');
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _cancelarAgendamiento(Agendamiento ag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Cita'),
        content: const Text('¿Está seguro de que desea cancelar esta cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _agendamientoService.cancelarAgendamiento(ag.id!);
        if (ag.cliente?.email != null) {
          await _emailJsService.notificarCancelacion(
            clienteEmail: ag.cliente!.email!,
            clienteNombre: ag.cliente!.nombreCompleto,
            barberoNombre: ag.barbero?.nombreCompleto ?? 'Tu barbero',
            fechaOriginal: ag.fechaCita ?? '',
          );
        }
        AppToast.showSuccess(context, 'Cita cancelada');
        _cargarAgendamientos(_currentPage);
      } catch (e) {
        AppToast.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _cancelarAgendas() async {
    Barbero? barberoSeleccionado;
    final barberosRaw = await _auxiliarService.obtenerBarberos();
    
    // Añadimos la opción "Todos los barberos" al inicio
    final List<Barbero> opcionesBarberos = [
      Barbero(id: -1, nombre: 'Todos los barberos', apellido: '', documento: '', telefono: '', email: '', direccion: '', estado: true),
      ...barberosRaw
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final esGlobal = barberoSeleccionado?.id == -1;
            return AlertDialog(
              backgroundColor: const Color(0xFF161616),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD8B081), width: 0.5)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(esGlobal ? 'CANCELACIÓN GLOBAL' : 'CANCELAR POR BARBERO', 
                    style: TextStyle(color: esGlobal ? Colors.orange : const Color(0xFFD8B081), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Selecciona barbero y días:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableSelector<Barbero>(
                      label: 'Barbero',
                      hint: 'Seleccionar...',
                      items: opcionesBarberos,
                      selectedItem: barberoSeleccionado,
                      displayText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                      searchText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                      onSelected: (b) => setStateDialog(() => barberoSeleccionado = b),
                    ),
                    const SizedBox(height: 16),
                    _DaySelectorWidget(
                      isGlobal: esGlobal,
                      onDatesSelected: (dates, motivo) {
                         if (barberoSeleccionado != null && dates.isNotEmpty) {
                           Navigator.pop(context, {'barbero': barberoSeleccionado, 'fechas': dates, 'motivo': motivo});
                         } else {
                           AppToast.showError(context, 'Selecciona un barbero y al menos un día');
                         }
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );

    if (result == null) return;
    final Barbero b = result['barbero'];
    final List<DateTime> dates = result['fechas'];
    final String motivo = result['motivo'];
    final bool esGlobal = b.id == -1;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(esGlobal ? '¿CANCELAR TODO EL LOCAL?' : '¿CANCELAR CITAS DE ${b.nombreCompleto}?'),
        content: Text(
          esGlobal 
            ? 'Esta acción cancelará las citas de TODOS los barberos en los ${dates.length} día(s) seleccionados.'
            : 'Se cancelarán todas las citas de ${b.nombreCompleto} para los ${dates.length} día(s) seleccionados.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: esGlobal ? Colors.orange : Colors.red),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = await _authService.getCurrentUser();

    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      for (var d in dates) {
        final fechaStr = DateFormat('yyyy-MM-dd').format(d);
        if (esGlobal) {
          await _agendamientoService.cancelarDiaCompleto(
            fechaStr,
            motivo: motivo.isNotEmpty ? motivo : 'El local cerrará este día por motivos administrativos.'
          );
        } else {
          await _agendamientoService.cancelarDiaBarbero(
            barberoId: b.id!,
            fecha: fechaStr,
            usuarioSolicitanteId: user!.id!,
            motivo: motivo.isNotEmpty ? motivo : 'Cancelado por Administrador desde App Móvil',
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
        AppToast.showSuccess(context, 'Citas canceladas exitosamente');
        _cargarAgendamientos(_currentPage);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      AppToast.showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agendamientos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.event_busy, color: Colors.orange), 
              onPressed: _cancelarAgendas, 
              tooltip: 'Cancelar Citas / Días'
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar en esta página...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _agendamientosFiltrados.isEmpty
                      ? const Center(child: Text('No hay agendamientos'))
                      : RefreshIndicator(
                          onRefresh: () => _cargarAgendamientos(1),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            itemCount: _agendamientosFiltrados.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _agendamientosFiltrados.length) {
                                if (_ultimaPaginacion != null && _ultimaPaginacion!.totalPages > 1) {
                                  return Padding(padding: const EdgeInsets.only(top: 20, bottom: 40), child: _buildPaginationControls());
                                }
                                return const SizedBox(height: 80);
                              }
                              final ag = _agendamientosFiltrados[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(ag.cliente?.nombreCompleto ?? 'Cita #${ag.id}'),
                                  subtitle: Text('${ag.fechaCita} | ${ag.horaInicio}\nBarbero: ${ag.barbero?.nombreCompleto ?? "N/A"} | ${AppFormat.cop(ag.monto ?? 0)}'),
                                  trailing: PopupMenuButton(
                                    onSelected: (val) {
                                      if (val == 'details') _verDetalles(ag);
                                      if (val == 'edit') {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => AgendamientoFormScreen(agendamiento: ag))).then((_) => _cargarAgendamientos(_currentPage));
                                      }
                                      if (val == 'cancel') _cancelarAgendamiento(ag);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'details', child: Text('Detalles')),
                                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      const PopupMenuItem(value: 'cancel', child: Text('Cancelar', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _ultimaPaginacion!.totalPages;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(icon: Icons.chevron_left, onTap: _currentPage > 1 ? () => _cargarAgendamientos(_currentPage - 1) : null),
          const SizedBox(width: 8),
          ..._buildPageNumbers(totalPages),
          const SizedBox(width: 8),
          _buildPageButton(icon: Icons.chevron_right, onTap: _currentPage < totalPages ? () => _cargarAgendamientos(_currentPage + 1) : null),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> widgets = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 || i == totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1)) {
        widgets.add(_buildPageNumberButton(i));
      } else if (i == _currentPage - 2 || i == _currentPage + 2) {
        widgets.add(const Text('...', style: TextStyle(color: Colors.grey)));
      }
    }
    return widgets;
  }

  Widget _buildPageNumberButton(int page) {
    bool isSelected = page == _currentPage;
    return GestureDetector(
      onTap: isSelected ? null : () => _cargarAgendamientos(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD8B081) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Text(page.toString(), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
        child: Icon(icon, color: onTap == null ? Colors.grey : Colors.white, size: 20),
      ),
    );
  }
}

class _DaySelectorDialog extends StatefulWidget {
  final String title;
  final bool isGlobal;

  const _DaySelectorDialog({required this.title, required this.isGlobal});

  @override
  State<_DaySelectorDialog> createState() => __DaySelectorDialogState();
}

class __DaySelectorDialogState extends State<_DaySelectorDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD8B081), width: 0.5)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: TextStyle(color: widget.isGlobal ? Colors.orange : const Color(0xFFD8B081), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Selecciona los días:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _DaySelectorWidget(
          onDatesSelected: (dates, _) => Navigator.pop(context, dates),
          isGlobal: widget.isGlobal,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
      ],
    );
  }
}

class _DaySelectorWidget extends StatefulWidget {
  final Function(List<DateTime>, String) onDatesSelected;
  final bool isGlobal;

  const _DaySelectorWidget({required this.onDatesSelected, required this.isGlobal});

  @override
  State<_DaySelectorWidget> createState() => __DaySelectorWidgetState();
}

class __DaySelectorWidgetState extends State<_DaySelectorWidget> {
  String _selectedWeek = 'Semana actual';
  final List<DateTime> _selectedDates = [];
  final TextEditingController _motivoController = TextEditingController();

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  List<DateTime> _getWeekDays(String weekType) {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    if (weekType == 'Siguiente semana') {
      monday = monday.add(const Duration(days: 7));
    }
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays(_selectedWeek);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8B081), width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedWeek,
              dropdownColor: const Color(0xFF1E1E1E),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD8B081)),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: ['Semana actual', 'Siguiente semana'].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedWeek = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weekDays.map((date) {
            final isPast = date.isBefore(today);
            final isSelected = _selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
            final name = DateFormat('EEEE', 'es_ES').format(date);
            final capitalized = name[0].toUpperCase() + name.substring(1);

            return FilterChip(
              label: Text(capitalized),
              selected: isSelected,
              onSelected: isPast ? null : (val) {
                setState(() {
                  if (val) _selectedDates.add(date);
                  else _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
                });
              },
              backgroundColor: const Color(0xFF2A2A2A),
              selectedColor: const Color(0xFFD8B081),
              labelStyle: TextStyle(
                color: isPast ? Colors.white24 : (isSelected ? Colors.black : Colors.white70),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _motivoController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Motivo (opcional)...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8B081))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8B081))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8B081), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        if (widget.isGlobal)
          const Text(
            '* Nota: Esta acción cancelará las citas de TODOS los barberos en los días seleccionados.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _selectedDates.isEmpty ? null : () => widget.onDatesSelected(_selectedDates, _motivoController.text.trim()),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
            backgroundColor: const Color(0xFFD8B081),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('CONFIRMAR SELECCIÓN'),
        ),
      ],
    );
  }
}
