import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/pages/agendamiento_form_screen.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/presentation/widgets/modal_completar_parcialmente.dart';

class AgendamientoDetalleScreen extends StatefulWidget {
  final Agendamiento agendamiento;
  final AppRole role;

  const AgendamientoDetalleScreen({
    super.key,
    required this.agendamiento,
    required this.role,
  });

  @override
  State<AgendamientoDetalleScreen> createState() => _AgendamientoDetalleScreenState();
}

class _AgendamientoDetalleScreenState extends State<AgendamientoDetalleScreen> {
  late Agendamiento _currentAg;
  bool _isLoading = true;
  List<Servicio> _catalogoServicios = [];
  List<Producto> _catalogoProductos = [];

  @override
  void initState() {
    super.initState();
    _currentAg = widget.agendamiento;
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AgendamientoService().obtenerAgendamientoPorId(_currentAg.id!),
        ServicioService().obtenerServicios(),
        ProductoService().getProductos(pageSize: 1000),
      ]);

      setState(() {
        _currentAg = results[0] as Agendamiento;
        _catalogoServicios = results[1] as List<Servicio>;
        _catalogoProductos = results[2] as List<Producto>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmada':
      case 'confirmado':
        return Colors.green;
      case 'en proceso':
        return Colors.orange;
      case 'completada':
      case 'finalizado':
      case 'finalizada':
        return const Color(0xFFD8B081);
      case 'cancelada':
      case 'cancelado':
        return Colors.red;
      case 'no asistio':
        return Colors.redAccent;
      case 'pendiente':
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Detalle de Cita #${_currentAg.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8B081)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),
                  const SizedBox(height: 24),
                  _buildInfoGrid(),
                  const SizedBox(height: 24),
                  _buildItemsList(),
                  const SizedBox(height: 24),
                  _buildObservations(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildStatusHeader() {
    final color = _getStatusColor(_currentAg.estadoCita);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado Actual',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  (_currentAg.estadoCita ?? 'Pendiente').toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppFormat.cop(_currentAg.monto ?? _currentAg.precio),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _buildInfoCard(
          'Cliente', 
          _getClienteNombre(_currentAg), 
          Icons.person,
          image: _currentAg.cliente?.fotoPerfil
        ),
        _buildInfoCard(
          'Barbero', 
          _getBarberoNombre(_currentAg), 
          Icons.content_cut,
          image: _currentAg.barbero?.fotoPerfil
        ),
        _buildInfoCard('Fecha', _currentAg.fechaCita ?? 'N/A', Icons.calendar_today),
        _buildInfoCard('Horario', '${AppFormat.to12h(_currentAg.horaInicio ?? '')} - ${AppFormat.to12h(_currentAg.horaFin ?? '')}', Icons.access_time),
      ],
    );
  }

  String _getClienteNombre(Agendamiento ag) {
    if (ag.clienteNombre != null && ag.clienteNombre!.isNotEmpty) {
      return ag.clienteNombre!;
    }
    return ag.cliente?.nombreCompleto ?? 'Cliente';
  }

  String _getBarberoNombre(Agendamiento ag) {
    if (ag.barberoNombre != null && ag.barberoNombre!.isNotEmpty) {
      return ag.barberoNombre!;
    }
    return ag.barbero?.nombreCompleto ?? 'Sin asignar';
  }

  Widget _buildInfoCard(String label, String value, IconData icon, {String? image}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[900]!, width: 1),
      ),
      child: Row(
        children: [
          if (image != null && image.isNotEmpty) ...[
             CircleAvatar(
               radius: 18,
               backgroundImage: NetworkImage(image),
               backgroundColor: Colors.grey[900],
             ),
             const SizedBox(width: 10),
          ] else if (label == 'Cliente' || label == 'Barbero') ...[
             CircleAvatar(
               radius: 18,
               backgroundColor: const Color(0xFFD8B081).withOpacity(0.1),
               child: Icon(icon, color: const Color(0xFFD8B081), size: 16),
             ),
             const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_currentAg.servicioIds.isEmpty && _currentAg.productoIds.isEmpty && _currentAg.paquete == null && _currentAg.servicio == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Servicios y Productos',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[900]!, width: 1),
          ),
          child: Column(
            children: [
              if (_currentAg.paquete != null) ...[
                _buildItemRow('Paquete: ${_currentAg.paquete!.nombre}', Icons.inventory_2),
                const Divider(color: Colors.white10),
              ],
              
              // Servicios
              ..._currentAg.servicioIds.map((id) {
                String name = 'Servicio #$id';
                String? img;
                try {
                   final s = _catalogoServicios.firstWhere((x) => x.id == id);
                   name = s.nombre;
                   img = s.imagen;
                } catch(_) {}
                return _buildItemRow(name, Icons.check_circle_outline, image: img);
              }),

              if (_currentAg.servicioIds.isEmpty && _currentAg.servicio != null)
                 _buildItemRow(_currentAg.servicio!.nombre, Icons.check_circle_outline, image: _currentAg.servicio!.imagen),

              if (_currentAg.productoIds.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white10),
                ),
                ..._currentAg.productoIds.toSet().map((id) {
                   final qty = _currentAg.productoIds.where((x) => x == id).length;
                   String name = 'Producto #$id';
                   String? img;
                   try {
                      final p = _catalogoProductos.firstWhere((x) => x.id == id);
                      name = p.nombre;
                      img = p.imagenProduc;
                   } catch(_) {}
                   return _buildItemRow(qty > 1 ? '$name (x$qty)' : name, Icons.shopping_basket_outlined, image: img);
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(String text, IconData icon, {String? image}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (image != null && image.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(image, width: 32, height: 32, fit: BoxFit.cover, 
                errorBuilder: (context, error, stackTrace) => Icon(icon, color: const Color(0xFFD8B081), size: 16)),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Icon(icon, color: const Color(0xFFD8B081), size: 16),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservations() {
    if (_currentAg.observaciones == null || _currentAg.observaciones!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[900]!, width: 1),
          ),
          child: Text(
            _currentAg.observaciones!,
            style: const TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (widget.role == AppRole.client) {
       return _currentAg.estadoCita?.toLowerCase() == 'pendiente' 
        ? _buildClientCancelButton() 
        : const SizedBox.shrink();
    }

    if (widget.role == AppRole.barber) {
      final estado = (_currentAg.estadoCita ?? '').toLowerCase();
      final puedeCancelar = estado != 'cancelada' && 
                            estado != 'cancelado' && 
                            estado != 'completada' && 
                            estado != 'finalizado' && 
                            estado != 'finalizada' && 
                            estado != 'no asistio';

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (puedeCancelar)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cancelarComoCliente,
                  icon: const Icon(Icons.cancel, color: Colors.white, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'CANCELAR CITA',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (estado == 'en proceso' || estado == 'confirmado' || estado == 'confirmada') ...[
              if (puedeCancelar) const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _avisarTermino,
                  icon: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'AVISAR TÉRMINO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cambiarEstado,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: Color(0xFFD8B081)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'CAMBIAR ESTADO',
                    style: TextStyle(color: Color(0xFFD8B081), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _editarCita,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD8B081),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'EDITAR CITA',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_currentAg.estadoCita?.toLowerCase() == 'en proceso' || _currentAg.estadoCita?.toLowerCase() == 'confirmado' || _currentAg.estadoCita?.toLowerCase() == 'confirmada') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _terminarTemprano,
                icon: const Icon(Icons.timer_off, color: Colors.white, size: 20),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text(
                  'TERMINAR COMPLETO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _terminarParcial,
                icon: const Icon(Icons.checklist, color: AppColors.gold, size: 20),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text(
                  'COMPLETAR PARCIALMENTE',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientCancelButton() {
     return Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _cancelarComoCliente,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('CANCELAR MI CITA', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
     );
  }

  Future<void> _cambiarEstado() async {
    final estados = ['Pendiente', 'Confirmado', 'En Proceso', 'Finalizado', 'No Asistio', 'Cancelado'];
    
    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => Theme(
        data: ThemeData.dark(),
        child: SimpleDialog(
          title: const Text('Seleccionar Nuevo Estado', style: TextStyle(color: Color(0xFFD8B081))),
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          children: estados.map((e) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(e, style: TextStyle(
                color: _currentAg.estadoCita == e ? const Color(0xFFD8B081) : Colors.white,
                fontWeight: _currentAg.estadoCita == e ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              )),
            ),
          )).toList(),
        ),
      ),
    );

    if (nuevo != null && nuevo != _currentAg.estadoCita) {
      setState(() => _isLoading = true);
      try {
        final service = AgendamientoService();
        // Usar el endpoint específico de cambio de estado (PATCH) en lugar de actualizar todo el agendamiento (PUT)
        await service.actualizarEstadoAgendamiento(_currentAg.id!, nuevo);
        AppToast.showSuccess(context, 'Cita actualizada a $nuevo');
        _refreshData();
      } catch (e) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'No se pudo actualizar: $e');
      }
    }
  }

  void _editarCita() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgendamientoFormScreen(
          agendamiento: _currentAg,
          role: widget.role,
        ),
      ),
    ).then((val) {
      if (val == true) _refreshData();
    });
  }

  Future<void> _terminarTemprano() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Terminar Temprano', style: TextStyle(color: Colors.white)),
        content: const Text('¿Confirmas que terminaste esta cita antes de tiempo? Se marcará como Completada.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRMAR', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await AgendamientoService().actualizarEstadoAgendamiento(_currentAg.id!, 'Completada');
        AppToast.showSuccess(context, 'Cita finalizada temprano');
        _refreshData();
      } catch (e) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Error al actualizar: $e');
      }
    }
  }

  void _terminarParcial() {
    ModalCompletarParcialmente.show(context, _currentAg, () {
      _refreshData();
    });
  }

  Future<void> _avisarTermino() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Avisar Término', style: TextStyle(color: Colors.white)),
        content: const Text('¿Confirmas que terminaste la cita? Se enviará un aviso al administrador.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRMAR', style: TextStyle(color: AppColors.gold))),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await AgendamientoService().actualizarEstadoAgendamiento(_currentAg.id!, 'Terminado por Barbero');
        AppToast.showSuccess(context, 'Aviso enviado al administrador');
        _refreshData();
      } catch (e) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Error al enviar aviso: $e');
      }
    }
  }

  Future<void> _cancelarComoCliente() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: const Text('¿Estás seguro de que deseas cancelar tu cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SÍ, CANCELAR', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await AgendamientoService().cancelarAgendamiento(_currentAg.id!);
        AppToast.showSuccess(context, 'Cita cancelada correctamente');
        _refreshData();
      } catch (e) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Error al cancelar: $e');
      }
    }
  }
}
