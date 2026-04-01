import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/barbero.dart'; // Import Barbero model
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart'; // Import AuxiliarService
import 'package:parte_movil/core/utils/estado_cita.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
// import 'client_agendamiento_form_screen.dart'; // No longer needed


class ClientAgendamientosScreen extends StatefulWidget {
  const ClientAgendamientosScreen({super.key});

  @override
  State<ClientAgendamientosScreen> createState() => _ClientAgendamientosScreenState();
}

class _ClientAgendamientosScreenState extends State<ClientAgendamientosScreen> {
  final AgendamientoService _agendamientoService = AgendamientoService();
  final UserContextService _userContextService = UserContextService();
  final AuxiliarService _auxiliarService = AuxiliarService(); // Initialize Service
  List<Agendamiento> _agendamientos = [];
  bool _isLoading = true;
  bool _isDateFormatInitialized = false;
  String _filtroEstado = 'Todos';
  String? _clienteError;

  Future<void> _cambiarEstado(Agendamiento ag) async {
    final estados = ['Pendiente', 'Cancelado']; // Clients can usually only cancel
    
    final nuevoEstado = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Cambiar Estado de Cita'),
        children: estados.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, e),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(e, style: TextStyle(
              color: ag.estadoCita == e ? const Color(0xFFD8B081) : Colors.white,
            )),
          ),
        )).toList(),
      ),
    );

    if (nuevoEstado != null && nuevoEstado != ag.estadoCita && mounted) {
      try {
        final updated = ag.copyWith(estadoCita: nuevoEstado);
        await _agendamientoService.actualizarAgendamiento(updated);
        AppToast.showSuccess(context, 'Estado actualizado');
        _cargarAgendamientosCliente();
      } catch (e) {
        AppToast.showError(context, 'Error: $e');
      }
    }
  }


  @override
  void initState() {
    super.initState();
    // Initialize date formatting for Spanish
    initializeDateFormatting('es_ES', null).then((_) {
      if (mounted) {
        setState(() {
          _isDateFormatInitialized = true;
        });
      }
    });
    _cargarAgendamientosCliente();
  }

  Future<void> _cargarAgendamientosCliente() async {
    setState(() {
      _isLoading = true;
      _clienteError = null;
    });

    try {
      final cliente = await _userContextService.obtenerClienteActual();

      if (!mounted) return;

      if (cliente == null || cliente.id == null) {
        setState(() {
          _agendamientos = [];
          _clienteError =
              'No se encontró un perfil de cliente asociado a tu cuenta. Completa tu perfil o contacta al administrador.';
          _isLoading = false;
        });
        return;
      }

      final agendamientos =
          await _agendamientoService.obtenerAgendamientosPorCliente(cliente.id!);

      setState(() {
        _agendamientos = agendamientos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AppToast.showError(context, 'Error al cargar tus citas: $e');
      }
    }
  }

  List<Agendamiento> get _agendamientosFiltrados {
    var filtrados = _agendamientos;

    if (_filtroEstado != 'Todos') {
      filtrados = filtrados
          .where((a) => a.estadoCita == _filtroEstado)
          .toList();
    }

    return filtrados;
  }

  Future<void> _verDetallesAgendamiento(Agendamiento ag) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch full appointment details
      final full = await _agendamientoService.obtenerAgendamientoPorId(ag.id!);
      
      String barberoNombre = full.barbero?.nombreCompleto ?? 'N/A';

      // Fallback: If barber name is missing, try to fetch it from auxiliary service
      if (full.barbero == null) {
        try {
          final barberos = await _auxiliarService.obtenerBarberos();
          final barbero = barberos.firstWhere(
            (b) => b.id == full.barberoId,
            orElse: () => Barbero(
              id: 0,
              documento: '',
              nombre: 'Barbero',
              apellido: 'Desconocido',
              telefono: '',
              email: '',
              direccion: '',
              estado: true,
            ),
          );
          barberoNombre = barbero.nombreCompleto;
        } catch (_) {
          // Ignore error, keep "N/A"
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Detalles de tu Cita'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Tipo:', full.servicio != null ? 'Servicio' : 'Paquete'),
                _buildDetailRow('Nombre:', full.servicio?.nombre ?? full.paquete?.nombre ?? 'N/A'),
                const Divider(),
                _buildDetailRow('Barbero:', barberoNombre), // Display retrieved barber name
                const Divider(),
                _buildDetailRow('Fecha:', DateFormat('dd/MM/yyyy').format(DateTime.parse(full.fechaCita ?? DateTime.now().toIso8601String()))),
                _buildDetailRow('Hora:', '${full.horaInicio ?? ''} - ${full.horaFin ?? ''}'),
                _buildDetailRow('Estado:', full.estadoCita ?? 'Pendiente'),
                if (full.monto != null)
                  _buildDetailRow('Monto:', '\$${full.monto!.toStringAsFixed(2)}', isBold: true),
                if (full.observaciones != null && full.observaciones!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(full.observaciones!),
                    ],
                  ),
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
      Navigator.pop(context); // Close loading dialog
      AppToast.showError(context, 'Error al cargar detalles: $e');
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (!_isDateFormatInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SessionGuard(
      requiredRole: AppRole.client,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Mis Citas'),
      ),
      body: _clienteError != null
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
          : Column(
              children: [
                // Filtro de estado
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _filtroEstado,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por estado',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: EstadoCita.todosConFiltro
                        .map((estado) {
                      return DropdownMenuItem(
                        value: estado,
                        child: Text(estado),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _filtroEstado = value!;
                      });
                    },
                  ),
                ),
                // Lista de agendamientos
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _agendamientosFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _filtroEstado == 'Todos'
                                        ? 'No tienes citas agendadas'
                                        : 'No hay citas con este estado',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _cargarAgendamientosCliente,
                              child: ListView.builder(
                                itemCount: _agendamientosFiltrados.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (context, index) {
                                  final agendamiento = _agendamientosFiltrados[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              agendamiento.servicio != null
                                                  ? 'Servicio: ${agendamiento.servicio!.nombre}'
                                                  : agendamiento.paquete != null
                                                      ? 'Paquete: ${agendamiento.paquete!.nombre}'
                                                      : 'Cita General',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: EstadoCita.getColor(agendamiento.estadoCita ?? 'Pendiente')
                                                  .withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: EstadoCita.getColor(agendamiento.estadoCita ?? 'Pendiente'),
                                              ),
                                            ),
                                            child: Text(
                                              agendamiento.estadoCita ?? 'Pendiente',
                                              style: TextStyle(
                                                color: EstadoCita.getColor(agendamiento.estadoCita ?? 'Pendiente'),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          if (agendamiento.barbero != null)
                                            Row(
                                              children: [
                                                const Icon(Icons.content_cut, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Barbero: ${agendamiento.barbero!.nombreCompleto}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(agendamiento.fechaCita ?? DateTime.now().toIso8601String()))}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Hora: ${agendamiento.horaInicio} - ${agendamiento.horaFin}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (agendamiento.monto != null)
                                            const SizedBox(height: 4),
                                          if (agendamiento.monto != null)
                                            Text(
                                              'Monto: \$${agendamiento.monto!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: PopupMenuButton(
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Row(
                                              children: [
                                                Icon(Icons.visibility, size: 20, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Ver Detalles'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'status',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_calendar, size: 20, color: Color(0xFFD8B081)),
                                                SizedBox(width: 8),
                                                Text('Cambiar Estado'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'details') {
                                            _verDetallesAgendamiento(agendamiento);
                                          } else if (value == 'status') {
                                            _cambiarEstado(agendamiento);
                                          }
                                        },
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
}
