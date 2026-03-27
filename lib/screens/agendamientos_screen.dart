import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agendamiento.dart';
import '../services/agendamiento_service.dart';
import '../services/emailjs_service.dart';
import '../services/auxiliar_service.dart';
import '../models/cliente.dart';
import '../models/barbero.dart';
import '../utils/estado_cita.dart';
import 'agendamiento_form_screen.dart';
import '../models/app_role.dart';
import '../widgets/session_guard.dart';

class AgendamientosScreen extends StatefulWidget {
  const AgendamientosScreen({super.key});

  @override
  State<AgendamientosScreen> createState() => _AgendamientosScreenState();
}

class _AgendamientosScreenState extends State<AgendamientosScreen> {
  final AgendamientoService _agendamientoService = AgendamientoService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final EmailJsService _emailJsService = EmailJsService();
  List<Agendamiento> _agendamientos = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filtroEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarAgendamientos();
  }

  Future<void> _cargarAgendamientos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final agendamientos = await _agendamientoService.obtenerAgendamientos();
      setState(() {
        _agendamientos = agendamientos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar agendamientos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Agendamiento> get _agendamientosFiltrados {
    var filtrados = _agendamientos;

    if (_filtroEstado != 'Todos') {
      filtrados = filtrados.where((a) => a.estadoCita == _filtroEstado).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtrados = filtrados.where((agendamiento) {
        final cliente = agendamiento.cliente?.nombreCompleto.toLowerCase() ?? '';
        final barbero = agendamiento.barbero?.nombreCompleto.toLowerCase() ?? '';
        final servicio = agendamiento.servicio?.nombre.toLowerCase() ?? '';
        final paquete = agendamiento.paquete?.nombre.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return cliente.contains(query) ||
            barbero.contains(query) ||
            servicio.contains(query) ||
            paquete.contains(query);
      }).toList();
    }

    return filtrados;
  }

  Future<void> _verDetallesAgendamiento(Agendamiento agendamientoResumen) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final agendamiento = await _agendamientoService.obtenerAgendamientoPorId(agendamientoResumen.id!);

      String clienteNombre = agendamiento.cliente?.nombreCompleto ?? 'N/A';
      String barberoNombre = agendamiento.barbero?.nombreCompleto ?? 'N/A';

      if (agendamiento.cliente == null || agendamiento.barbero == null) {
        try {
          if (agendamiento.cliente == null) {
            final clientes = await _auxiliarService.obtenerClientes();
            final cliente = clientes.firstWhere(
              (c) => c.id == agendamiento.clienteId,
              orElse: () => Cliente(id: 0, documento: '', nombre: 'Desconocido', apellido: '', telefono: '', email: '', direccion: '', estado: true),
            );
            clienteNombre = cliente.nombreCompleto;
          }
          if (agendamiento.barbero == null) {
            final barberos = await _auxiliarService.obtenerBarberos();
            final barbero = barberos.firstWhere(
              (b) => b.id == agendamiento.barberoId,
              orElse: () => Barbero(id: 0, documento: '', nombre: 'Desconocido', apellido: '', telefono: '', email: '', direccion: '', estado: true),
            );
            barberoNombre = barbero.nombreCompleto;
          }
        } catch (e) {
          print('Error recuperando datos auxiliares: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Detalles Cita'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Tipo:', agendamiento.servicio != null ? 'Servicio' : 'Paquete'),
                _buildDetailRow('Nombre:', agendamiento.servicio?.nombre ?? agendamiento.paquete?.nombre ?? 'N/A'),
                const Divider(),
                _buildDetailRow('Cliente:', clienteNombre),
                _buildDetailRow('Barbero:', barberoNombre),
                const Divider(),
                _buildDetailRow('Fecha:', DateFormat('dd/MM/yyyy').format(DateTime.parse(agendamiento.fechaCita ?? DateTime.now().toIso8601String()))),
                _buildDetailRow('Hora:', '${agendamiento.horaInicio ?? ''} - ${agendamiento.horaFin ?? ''}'),
                _buildDetailRow('Estado:', agendamiento.estadoCita ?? 'Pendiente'),
                if (agendamiento.monto != null)
                  _buildDetailRow('Monto:', '\$${agendamiento.monto!.toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar detalles: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Future<void> _eliminarAgendamiento(Agendamiento agendamiento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Agendamiento'),
        content: Text('¿Está seguro que desea eliminar el agendamiento del ${agendamiento.fechaCita}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _agendamientoService.eliminarAgendamiento(agendamiento.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agendamiento eliminado exitosamente'), backgroundColor: Colors.green),
          );
          _cargarAgendamientos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar agendamiento: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _cancelarAgendamiento(Agendamiento agendamiento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Agendamiento'),
        content: Text('¿Está seguro que desea cancelar el agendamiento del ${agendamiento.fechaCita}? se enviará una notificación por correo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final agendamientoCancelado = agendamiento.copyWith(estadoCita: EstadoCita.cancelada);
        await _agendamientoService.actualizarAgendamiento(agendamientoCancelado);
        
        if (agendamiento.cliente != null && agendamiento.cliente!.email != null) {
          try {
            await _emailJsService.notificarCancelacion(
              clienteNombre: agendamiento.cliente!.nombreCompleto,
              clienteEmail: agendamiento.cliente!.email!,
              barberoNombre: agendamiento.barbero?.nombreCompleto ?? 'Tu barbero',
              fechaOriginal: '${agendamiento.fechaCita}T${agendamiento.horaInicio}',
            );
          } catch (e) {
            print('Error al enviar notificación por correo: $e');
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agendamiento cancelado exitosamente y correo enviado'), backgroundColor: Colors.green),
          );
          _cargarAgendamientos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cancelar agendamiento: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _cancelarDiaCompleto() async {
    // ── PASO 1: Cargar barberos y elegir cuál afecta ─────────────────────────
    List<Barbero> barberos = [];
    try {
      barberos = await _auxiliarService.obtenerBarberos();
    } catch (_) {}

    if (!mounted) return;

    // null = todos los barberos
    Barbero? barberoElegido;

    final barberoResult = await showDialog<Object>(
      context: context,
      builder: (ctx) {
        Barbero? seleccion;
        return StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'CANCELAR DÍAS — Paso 1 de 2',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿A qué barbero aplica la cancelación?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                // Opción: Todos
                GestureDetector(
                  onTap: () => setDs(() => seleccion = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: seleccion == null
                          ? const Color(0xFFD8B081).withOpacity(0.15)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccion == null
                            ? const Color(0xFFD8B081)
                            : const Color(0xFF3A3A3A),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: seleccion == null
                              ? const Color(0xFFD8B081)
                              : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Todos los barberos',
                          style: TextStyle(
                            color: seleccion == null
                                ? const Color(0xFFD8B081)
                                : Colors.white,
                            fontWeight: seleccion == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Opciones: barbero individual
                ...barberos.map((b) => GestureDetector(
                      onTap: () => setDs(() => seleccion = b),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: seleccion?.id == b.id
                              ? const Color(0xFFD8B081).withOpacity(0.15)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: seleccion?.id == b.id
                                ? const Color(0xFFD8B081)
                                : const Color(0xFF3A3A3A),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: seleccion?.id == b.id
                                  ? const Color(0xFFD8B081)
                                  : Colors.white54,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                b.nombreCompleto,
                                style: TextStyle(
                                  color: seleccion?.id == b.id
                                      ? const Color(0xFFD8B081)
                                      : Colors.white,
                                  fontWeight: seleccion?.id == b.id
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B081),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(ctx, seleccion ?? 'todos'),
                child: const Text('SIGUIENTE →'),
              ),
            ],
          ),
        );
      },
    );

    if (barberoResult == null) return; // canceló
    barberoElegido = barberoResult is Barbero ? barberoResult : null;

    // ── PASO 2: Elegir los días ───────────────────────────────────────────────
    final DateTime hoy = DateTime.now();
    final List<DateTime> proximosDias = List.generate(14, (i) => hoy.add(Duration(days: i)));
    final List<DateTime> seleccionados = [];

    final String tituloBarbero = barberoElegido != null
        ? barberoElegido.nombreCompleto
        : 'Todos los barberos';

    final result = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CANCELAR DÍAS — Paso 2 de 2',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8B081).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_pin, size: 13, color: Color(0xFFD8B081)),
                        const SizedBox(width: 4),
                        Text(
                          tituloBarbero,
                          style: const TextStyle(
                            color: Color(0xFFD8B081),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: proximosDias.length,
                  itemBuilder: (context, index) {
                    final dia = proximosDias[index];
                    final dateStr = DateFormat('EEEE, d MMMM', 'es_ES').format(dia);
                    final isSelected = seleccionados.any(
                      (d) => d.day == dia.day && d.month == dia.month,
                    );
                    return CheckboxListTile(
                      activeColor: const Color(0xFFD8B081),
                      checkColor: Colors.black,
                      title: Text(dateStr, style: const TextStyle(color: Colors.white)),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            seleccionados.add(dia);
                          } else {
                            seleccionados.removeWhere(
                              (d) => d.day == dia.day && d.month == dia.month,
                            );
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B081),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: seleccionados.isEmpty
                      ? null
                      : () => Navigator.pop(context, seleccionados),
                  child: Text('PROCEDER (${seleccionados.length})'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return;

    // ── PASO 3: Filtrar y confirmar ───────────────────────────────────────────
    final List<String> fechasStr =
        result.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

    final citasACancelar = _agendamientos.where((a) {
      final fechaMatch = fechasStr.any((f) => a.fechaCita?.contains(f) == true);
      final estadoOk = a.estadoCita != EstadoCita.cancelada;
      // Filtrar por barbero si fue seleccionado uno específico
      final barberoMatch = barberoElegido == null || a.barberoId == barberoElegido.id;
      return fechaMatch && estadoOk && barberoMatch;
    }).toList();

    if (citasACancelar.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No hay citas activas para $tituloBarbero en los días seleccionados.',
            ),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'CONFIRMAR CANCELACIÓN MASIVA',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '🎯 Barbero: $tituloBarbero\n'
          '📅 Días: ${fechasStr.join(", ")}\n'
          '📋 Citas a cancelar: ${citasACancelar.length}\n\n'
          'Se enviará correo de notificación a cada cliente.',
          style: const TextStyle(color: Colors.white70, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('SÍ, CANCELAR TODO'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    int canceladasCount = 0;
    try {
      for (var ag in citasACancelar) {
        final cancelado = ag.copyWith(estadoCita: EstadoCita.cancelada);
        await _agendamientoService.actualizarAgendamiento(cancelado);

        if (ag.cliente?.email != null) {
          try {
            await _emailJsService.notificarCancelacion(
              clienteNombre: ag.cliente!.nombreCompleto,
              clienteEmail: ag.cliente!.email!,
              barberoNombre: ag.barbero?.nombreCompleto ?? tituloBarbero,
              fechaOriginal: '${ag.fechaCita}T${ag.horaInicio}',
              motivo: 'Cierre de la barbería por días programados.',
            );
          } catch (e) {
            print('Error en correo masivo: $e');
          }
        }
        canceladasCount++;
      }

      if (!mounted) return;
      Navigator.pop(context); // Importante: Cerrar el loading dialog
      _mostarNotificacion(
        '✅ ¡ÉXITO! Se cancelaron $canceladasCount citas de $tituloBarbero.',
        esError: false,
      );
      _cargarAgendamientos();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _mostarNotificacion('ERROR: $e', esError: true);
      }
    }
  }

  void _mostarNotificacion(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
        duration: Duration(seconds: esError ? 5 : 3),
      ),
    );
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
              tooltip: 'Cancelar todo un día',
              onPressed: _cancelarDiaCompleto,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por cliente, barbero o servicio...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _filtroEstado,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por estado',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    ),
                    items: EstadoCita.todosConFiltro.map((estado) => DropdownMenuItem(value: estado, child: Text(estado))).toList(),
                    onChanged: (value) => setState(() => _filtroEstado = value!),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _agendamientosFiltrados.isEmpty
                      ? Center(child: Text('No hay agendamientos'))
                      : RefreshIndicator(
                          onRefresh: _cargarAgendamientos,
                          child: ListView.builder(
                            itemCount: _agendamientosFiltrados.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final ag = _agendamientosFiltrados[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(ag.servicio?.nombre ?? ag.paquete?.nombre ?? 'Cita'),
                                  subtitle: Text('Cliente: ${ag.cliente?.nombreCompleto ?? 'N/A'}\nFecha: ${ag.fechaCita}'),
                                  trailing: PopupMenuButton(
                                    onSelected: (value) {
                                      if (value == 'details') _verDetallesAgendamiento(ag);
                                      if (value == 'edit') Navigator.push(context, MaterialPageRoute(builder: (context) => AgendamientoFormScreen(agendamiento: ag))).then((_) => _cargarAgendamientos());
                                      if (value == 'cancel') _cancelarAgendamiento(ag);
                                      if (value == 'delete') _eliminarAgendamiento(ag);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'details', child: Text('Ver Detalles')),
                                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      const PopupMenuItem(value: 'cancel', child: Text('Cancelar Cita')),
                                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendamientoFormScreen())).then((_) => _cargarAgendamientos()),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
