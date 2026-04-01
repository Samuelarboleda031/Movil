import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/core/utils/estado_cita.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';

class ClientAgendamientoFormScreen extends StatefulWidget {
  final Agendamiento? agendamiento;
  
  const ClientAgendamientoFormScreen({
    super.key,
    this.agendamiento,
  });

  @override
  State<ClientAgendamientoFormScreen> createState() => _ClientAgendamientoFormScreenState();
}

class _ClientAgendamientoFormScreenState extends State<ClientAgendamientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AgendamientoService _agendamientoService = AgendamientoService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final UserContextService _userContextService = UserContextService();

  List<Barbero> _barberos = [];
  List<Servicio> _servicios = [];
  List<Paquete> _paquetes = [];
  List<Producto> _productos = [];
  List<Agendamiento> _todasLasCitas = [];

  Cliente? _clienteActual;
  String? _clienteError;
  Barbero? _barberoSeleccionado;
  List<Servicio> _serviciosSeleccionados = [];
  Paquete? _paqueteSeleccionado;
  Map<int, int> _productoCantidades = {};
  DateTime _fechaSeleccionada = DateTime.now();
  TimeOfDay _horaInicio = TimeOfDay.now();
  TimeOfDay _horaFin = TimeOfDay.now();
  String _estadoCita = 'Pendiente';
  double? _monto;
  String? _observaciones;
  bool _esServicio = true;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }
  
  void _cargarDatosAgendamiento(Agendamiento agendamiento) {
    Barbero? barberoSeleccionado;
    try {
      barberoSeleccionado =
          _barberos.firstWhere((barbero) => barbero.id == agendamiento.barberoId);
    } catch (_) {
      barberoSeleccionado = agendamiento.barbero ??
          Barbero(
            id: agendamiento.barberoId,
            documento: '0',
            nombre: 'Barbero',
            apellido: 'Temporal',
          );
    }

    Servicio? servicioSeleccionado;
    Paquete? paqueteSeleccionado;
    bool esServicio = _esServicio;

    if (agendamiento.servicioId != null) {
      try {
        servicioSeleccionado =
            _servicios.firstWhere((servicio) => servicio.id == agendamiento.servicioId);
      } catch (_) {
        servicioSeleccionado = agendamiento.servicio ??
            Servicio(
              id: agendamiento.servicioId,
              nombre: 'Servicio',
              precio: 0,
              duracionMinutos: 30,
            );
      }
      esServicio = true;
    } else if (agendamiento.paqueteId != null) {
      try {
        paqueteSeleccionado =
            _paquetes.firstWhere((paquete) => paquete.id == agendamiento.paqueteId);
      } catch (_) {
        paqueteSeleccionado = agendamiento.paquete ??
            Paquete(
              id: agendamiento.paqueteId,
              nombre: 'Paquete',
              precio: 0,
              duracionMinutos: 30,
            );
      }
      esServicio = false;
    }

    final fecha = DateTime.parse(agendamiento.fechaCita ?? DateTime.now().toIso8601String());
    final horaInicioParts = (agendamiento.horaInicio ?? '00:00').split(':');
    final horaFinParts = (agendamiento.horaFin ?? '00:00').split(':');
    final horaInicio = TimeOfDay(
      hour: int.parse(horaInicioParts[0]),
      minute: int.parse(horaInicioParts[1]),
    );
    final horaFin = TimeOfDay(
      hour: int.parse(horaFinParts[0]),
      minute: int.parse(horaFinParts[1]),
    );

    setState(() {
      if (barberoSeleccionado != null &&
          !_barberos.any((b) => b.id == barberoSeleccionado!.id)) {
        _barberos = [..._barberos, barberoSeleccionado];
      }
      if (servicioSeleccionado != null &&
          !_servicios.any((s) => s.id == servicioSeleccionado!.id)) {
        _servicios = [..._servicios, servicioSeleccionado];
      }
      if (paqueteSeleccionado != null &&
          !_paquetes.any((p) => p.id == paqueteSeleccionado!.id)) {
        _paquetes = [..._paquetes, paqueteSeleccionado];
      }

      _barberoSeleccionado = barberoSeleccionado;
      if (servicioSeleccionado != null) {
        _serviciosSeleccionados = [servicioSeleccionado];
      }
      _paqueteSeleccionado = paqueteSeleccionado;
      _esServicio = esServicio;
      _fechaSeleccionada = fecha;
      _horaInicio = horaInicio;
      _horaFin = horaFin;
      _estadoCita = (agendamiento.estadoCita ?? 'Pendiente') == 'Confirmado' ? 'Confirmada' : (agendamiento.estadoCita ?? 'Pendiente');
      _monto = agendamiento.monto;
      _observaciones = agendamiento.observaciones;
    });
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoadingData = true;
      });

      final barberos = await _auxiliarService.obtenerBarberos();
      final servicios = await _auxiliarService.obtenerServicios();
      final paquetes = await _auxiliarService.obtenerPaquetes();
      final clienteSesion = await _userContextService.obtenerClienteActual();

      if (!mounted) return;

      if (clienteSesion == null || clienteSesion.id == null) {
        setState(() {
          _clienteError =
              'No se encontró un perfil de cliente asociado a tu cuenta. Completa tu perfil antes de agendar.';
          _isLoadingData = false;
        });
        return;
      }

      setState(() {
        _barberos = barberos;
        _servicios = servicios;
        _paquetes = paquetes;
        _clienteActual = clienteSesion;
        _isLoadingData = false;
      });

      if (widget.agendamiento != null) {
        _cargarDatosAgendamiento(widget.agendamiento!);
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = _fechaSeleccionada.isBefore(now) ? _fechaSeleccionada : now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  Future<void> _selectHoraInicio() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horaInicio,
    );
    if (picked != null) {
      setState(() {
        _horaInicio = picked;
        // Ajustar hora fin si es menor que hora inicio
        if (_horaInicio.hour > _horaFin.hour ||
            (_horaInicio.hour == _horaFin.hour &&
                _horaInicio.minute >= _horaFin.minute)) {
          _horaFin = TimeOfDay(
            hour: _horaInicio.hour,
            minute: (_horaInicio.minute + 30) % 60,
          );
        }
      });
    }
  }

  Future<void> _selectHoraFin() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horaFin,
    );
    if (picked != null && picked != _horaFin) {
      // Validar que hora fin sea mayor que hora inicio
      if (picked.hour > _horaInicio.hour ||
          (picked.hour == _horaInicio.hour &&
              picked.minute > _horaInicio.minute)) {
        setState(() {
          _horaFin = picked;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La hora de fin debe ser mayor que la hora de inicio'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _calcularMonto() {
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      setState(() {
        _monto = _serviciosSeleccionados.fold<double>(
            0.0, (double sum, s) => sum + s.precio);
      });
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      setState(() {
        _monto = _paqueteSeleccionado!.precio;
      });
    } else {
      setState(() {
        _monto = null;
      });
    }
  }

  // _formatItemLabel ya no se usa con SearchableSelector


  Widget _buildPickerField({
    required String label,
    required String value,
    required VoidCallback onTap,
    IconData icon = Icons.calendar_today,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(icon, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _guardarAgendamiento() async {
    if (!_formKey.currentState!.validate()) return;

    if (_clienteActual == null || _clienteActual!.id == null || _clienteActual!.id == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo identificar tu perfil de cliente'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_barberoSeleccionado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor seleccione un barbero'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_esServicio && _serviciosSeleccionados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor seleccione un servicio'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_esServicio && _paqueteSeleccionado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor seleccione un paquete'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final clienteId = _clienteActual!.id!;

      // Formatear fechas y horas
      final fechaCita = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
      final horaInicio = '${_horaInicio.hour.toString().padLeft(2, '0')}:${_horaInicio.minute.toString().padLeft(2, '0')}';
      final horaFin = '${_horaFin.hour.toString().padLeft(2, '0')}:${_horaFin.minute.toString().padLeft(2, '0')}';

      // Crear el objeto agendamiento
      
      final agendamiento = Agendamiento(
        id: widget.agendamiento?.id,
        clienteId: _clienteActual!.id!,
        barberoId: _barberoSeleccionado!.id!,
        servicioId: _esServicio && _serviciosSeleccionados.isNotEmpty ? _serviciosSeleccionados.first.id : null,
        servicioIds: _esServicio ? _serviciosSeleccionados.map((s)=>s.id!).toList() : [],
        productoIds: _productoCantidades.entries.expand((e) => List.filled(e.value, e.key)).toList(),
        paqueteId: !_esServicio ? _paqueteSeleccionado!.id : null,
        fechaCita: DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
        horaInicio: horaInicio,
        horaFin: horaFin,
        estadoCita: _estadoCita,
        monto: _monto,
        observaciones: _observaciones,
      );

      // Guardar o actualizar el agendamiento
      if (widget.agendamiento == null) {
        await _agendamientoService.crearAgendamiento(agendamiento);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _agendamientoService.actualizarAgendamiento(agendamiento);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la cita: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.client,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.agendamiento == null ? 'Nueva Cita' : 'Editar Cita'),
        ),
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : _clienteError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _clienteError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Cliente ligado a la sesión
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        helperText: 'La cita se registrará con tu cuenta actual',
                      ),
                      child: Text(
                        _clienteActual?.nombreCompleto ?? 'Perfil no disponible',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Barbero
                    SearchableSelector<Barbero>(
                      label: 'Barbero *',
                      hint: 'Escribe el nombre del barbero...',
                      items: _barberos,
                      selectedItem: _barberoSeleccionado,
                      displayText: (b) => b.nombreCompleto,
                      searchText: (b) => '${b.nombreCompleto} ${b.documento}',
                      prefixIcon: Icons.badge,
                      required: true,
                      onSelected: (b) => setState(() => _barberoSeleccionado = b),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tipo de Cita
                    const Text(
                      'Tipo de Cita',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Servicio'),
                            value: true,
                            groupValue: _esServicio,
                            onChanged: (bool? value) {
                              setState(() {
                                _esServicio = value!;
                                _serviciosSeleccionados.clear();
                                _paqueteSeleccionado = null;
                                _monto = null;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Paquete'),
                            value: false,
                            groupValue: _esServicio,
                            onChanged: (bool? value) {
                              setState(() {
                                _esServicio = value!;
                                _serviciosSeleccionados.clear();
                                _paqueteSeleccionado = null;
                                _monto = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Servicio o Paquete
                    
                        _esServicio
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SearchableSelector<Servicio>(
                                    label: 'Añadir Servicio',
                                    hint: 'Escribe el nombre del servicio...',
                                    items: _servicios,
                                    selectedItem: null, // Siempre nulo para multi-select
                                    displayText: (s) => s.nombre,
                                    searchText: (s) => s.nombre,
                                    prefixIcon: Icons.cut,
                                    required: _serviciosSeleccionados.isEmpty,
                                    renderItem: (s) => Row(
                                      children: [
                                        Expanded(
                                          child: Text(s.nombre,
                                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        ),
                                        Text(
                                          '\$${s.precio.toStringAsFixed(0)} · ${s.duracionMinutos}min',
                                          style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    onSelected: (s) {
                                      if (s != null && !_serviciosSeleccionados.any((sel) => sel.id == s.id)) {
                                          setState(() {
                                            _serviciosSeleccionados.add(s);
                                            _paqueteSeleccionado = null;
                                            _calcularMonto();
                                          });
                                      }
                                    },
                                  ),
                                  if (_serviciosSeleccionados.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _serviciosSeleccionados.map((s) => Chip(
                                        label: Text(s.nombre),
                                        onDeleted: () {
                                          setState(() {
                                            _serviciosSeleccionados.removeWhere((sel) => sel.id == s.id);
                                            _calcularMonto();
                                          });
                                        },
                                        backgroundColor: const Color(0xFFD8B081).withOpacity(0.2),
                                        deleteIconColor: const Color(0xFFD8B081),
                                        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                                        side: const BorderSide(color: Color(0xFFD8B081)),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              )
                            : SearchableSelector<Paquete>(
                            label: 'Paquete *',
                            hint: 'Escribe el nombre del paquete...',
                            items: _paquetes,
                            selectedItem: _paqueteSeleccionado,
                            displayText: (p) => p.nombre,
                            searchText: (p) => p.nombre,
                            prefixIcon: Icons.inventory_2,
                            required: true,
                            renderItem: (p) => Row(
                              children: [
                                Expanded(
                                  child: Text(p.nombre,
                                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                                ),
                                Text('\$${p.precio.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12)),
                              ],
                            ),
                            onSelected: (p) {
                              setState(() {
                                _paqueteSeleccionado = p;
                                _serviciosSeleccionados.clear();
                                _calcularMonto();
                              });
                            },
                          ),
                    const SizedBox(height: 16),
                    
                    // Fecha y Hora Inicio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPickerField(
                            label: 'Fecha de la cita',
                            value: DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                            onTap: _selectDate,
                            icon: Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPickerField(
                            label: 'Hora de inicio',
                            value: _horaInicio.format(context),
                            onTap: _selectHoraInicio,
                            icon: Icons.access_time,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Hora Fin y Monto
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPickerField(
                            label: 'Hora de fin',
                            value: _horaFin.format(context),
                            onTap: _selectHoraFin,
                            icon: Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monto'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: TextEditingController(
                                  text: _monto != null ? '\$${_monto!.toStringAsFixed(2)}' : '',
                                ),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.attach_money, size: 20),
                                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                ),
                                readOnly: true,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Estado de la cita
                    DropdownButtonFormField<String>(
                      value: _estadoCita,
                      decoration: const InputDecoration(
                        labelText: 'Estado de la cita',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: EstadoCita.todos
                          .map((estado) => DropdownMenuItem<String>(
                                value: estado,
                                child: Text(estado),
                              ))
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _estadoCita = value;
                          });
                        }
                      },
                      validator: (value) => value == null ? 'Por favor seleccione un estado' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading || _isLoadingData || _clienteError != null
                                ? null
                                : _guardarAgendamiento,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(widget.agendamiento == null ? 'Crear Cita' : 'Actualizar Cita'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
