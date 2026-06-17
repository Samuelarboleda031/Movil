import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/data/models/app_role.dart';

class PaqueteFormScreen extends StatefulWidget {
  final Paquete? paquete;

  const PaqueteFormScreen({super.key, this.paquete});

  @override
  State<PaqueteFormScreen> createState() => _PaqueteFormScreenState();
}

class _PaqueteFormScreenState extends State<PaqueteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();
  final _minutosCtrl = TextEditingController();

  final PaqueteService _paqueteService = PaqueteService();
  final ServicioService _servicioService = ServicioService();

  List<Servicio> _serviciosDisponibles = [];
  List<Servicio> _serviciosAgregados = [];

  // Buscador de servicios
  final _buscarServicioCtrl = TextEditingController();
  String _busquedaServicio = '';
  bool _mostrarResultados = false;

  bool _loading = false;
  bool _loadingServicios = true;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _isNew = widget.paquete == null;
    _cargarServiciosYDetalles();
  }

  Future<void> _cargarServiciosYDetalles() async {
    setState(() => _loadingServicios = true);
    try {
      // 1. Cargar servicios activos del sistema
      final servicios = await _servicioService.obtenerServicios();
      _serviciosDisponibles = servicios.where((s) => s.estado ?? true).toList();

      if (!_isNew) {
        // Modo Edición
        _nombreCtrl.text = widget.paquete!.nombre;
        _descripcionCtrl.text = widget.paquete!.descripcion ?? '';
        _precioCtrl.text = widget.paquete!.precio.toStringAsFixed(0);
        _descuentoCtrl.text = widget.paquete!.descuento.toStringAsFixed(0);

        final totalMinutos = widget.paquete!.duracionMinutos;
        final h = totalMinutos ~/ 60;
        final m = totalMinutos % 60;
        _horasCtrl.text = h > 0 ? h.toString() : '0';
        _minutosCtrl.text = m > 0 ? m.toString() : '0';

        // 2. Cargar detalles del paquete existente
        final detalles = await _paqueteService.obtenerDetallesPorPaquete(widget.paquete!.id!);
        final List<Servicio> temporales = [];
        
        for (var d in detalles) {
          // Intentar obtener el servicio embebido o buscarlo en los activos
          final int servicioId = d['servicioId'] ?? d['ServicioId'] ?? 0;
          
          Servicio? svc;
          if (d['servicio'] != null) {
            svc = Servicio.fromJson(d['servicio']);
          } else {
            // Buscar por ID en los cargados
            final idx = _serviciosDisponibles.indexWhere((s) => s.id == servicioId);
            if (idx != -1) {
              svc = _serviciosDisponibles[idx];
            }
          }

          if (svc != null) {
            temporales.add(svc);
          }
        }

        setState(() {
          _serviciosAgregados = temporales;
        });
      } else {
        // Modo Creación
        _horasCtrl.text = '0';
        _minutosCtrl.text = '0';
        _descuentoCtrl.text = '0';
        _precioCtrl.text = '0';
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, limpiarError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingServicios = false);
      }
    }
  }

  void _agregarServicio(Servicio servicio) {
    final existe = _serviciosAgregados.any((s) => s.id == servicio.id);
    if (existe) {
      AppToast.showError(context, 'Este servicio ya está incluido en el paquete.');
      return;
    }
    setState(() {
      _serviciosAgregados.add(servicio);
      _buscarServicioCtrl.clear();
      _busquedaServicio = '';
      _mostrarResultados = false;
      _recalcularTotalesYDuracion();
    });
  }

  void _eliminarServicio(int index) {
    setState(() {
      _serviciosAgregados.removeAt(index);
      _recalcularTotalesYDuracion();
    });
  }

  void _recalcularTotalesYDuracion() {
    // 1. Recalcular precio base (Subtotal)
    final subtotal = _serviciosAgregados.fold<double>(0.0, (sum, s) => sum + s.precio);
    
    // 2. Recalcular duración en base a los servicios
    final totalMinutos = _serviciosAgregados.fold<int>(0, (sum, s) => sum + s.duracionMinutos);
    final h = totalMinutos ~/ 60;
    final m = totalMinutos % 60;

    _horasCtrl.text = h.toString();
    _minutosCtrl.text = m.toString();

    // 3. Aplicar descuento actual si está en creación
    if (_isNew) {
      final dctoPct = double.tryParse(_descuentoCtrl.text) ?? 0.0;
      final dctoValor = subtotal * (dctoPct / 100.0);
      final precioFinal = subtotal - dctoValor;
      _precioCtrl.text = precioFinal.toStringAsFixed(0);
    }
  }

  double get _subtotal {
    return _serviciosAgregados.fold<double>(0.0, (sum, s) => sum + s.precio);
  }

  double get _descuentoValor {
    final pct = double.tryParse(_descuentoCtrl.text) ?? 0.0;
    return _subtotal * (pct / 100.0);
  }

  double get _precioTotalCalculado {
    return _subtotal - _descuentoValor;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_serviciosAgregados.isEmpty) {
      AppToast.showError(context, 'Debes agregar al menos un servicio al paquete.');
      return;
    }

    setState(() => _loading = true);

    try {
      final int horas = int.tryParse(_horasCtrl.text) ?? 0;
      final int minutos = int.tryParse(_minutosCtrl.text) ?? 0;
      final int duracionTotal = (horas * 60) + minutos;

      final double precioFinal = double.tryParse(_precioCtrl.text) ?? 0.0;

      final double descuento = double.tryParse(_descuentoCtrl.text) ?? 0.0;

      if (_isNew) {
        // 1. Crear Paquete Completo con Detalles
        final success = await _paqueteService.crearPaqueteCompleto(
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
          precio: precioFinal,
          duracionMinutos: duracionTotal,
          detalles: _serviciosAgregados.map((s) => {'servicioId': s.id, 'cantidad': 1}).toList(),
          descuento: descuento,
        );

        if (success && mounted) {
          final nombre = _nombreCtrl.text.trim();
          AppToast.showSuccess(context, 'El paquete "$nombre" ha sido creado correctamente con todos sus servicios en una sola operación.');
          Navigator.pop(context, true);
        }
      } else {
        // 2. Editar Paquete (General y Detalles por separado)
        final p = Paquete(
          id: widget.paquete!.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
          precio: precioFinal,
          duracionMinutos: duracionTotal,
          estado: widget.paquete!.estado ?? true,
          descuento: descuento,
        );

        final successGral = await _paqueteService.actualizarPaquete(p);
        final successDetalles = await _paqueteService.actualizarPaqueteDetalles(
          widget.paquete!.id!,
          _serviciosAgregados.map((s) => {'servicioId': s.id, 'cantidad': 1}).toList(),
        );

        if (successGral && successDetalles && mounted) {
          final nombre = _nombreCtrl.text.trim();
          AppToast.showSuccess(context, 'El paquete "$nombre" ha sido actualizado correctamente con la nueva información.');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, limpiarError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _descuentoCtrl.dispose();
    _horasCtrl.dispose();
    _minutosCtrl.dispose();
    _buscarServicioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(_isNew ? 'Crear Nuevo Paquete' : 'Editar Paquete'),
          backgroundColor: AppColors.bg,
          elevation: 0,
        ),
        body: _loadingServicios
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nombre del Paquete
                      TextFormField(
                        controller: _nombreCtrl,
                        style: const TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          labelText: 'Nombre del Paquete *',
                          labelStyle: const TextStyle(color: AppColors.greyLight),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.gold),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                      ),
                      const SizedBox(height: 16),

                      // Descripción
                      TextFormField(
                        controller: _descripcionCtrl,
                        style: const TextStyle(color: AppColors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descripción (Opcional)',
                          labelStyle: const TextStyle(color: AppColors.greyLight),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.gold),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Configuración de Servicios
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Servicios Incluidos',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_serviciosAgregados.length} servicios',
                                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Buscador de servicios
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _buscarServicioCtrl,
                                  style: const TextStyle(color: AppColors.white, fontSize: 13),
                                  onChanged: (val) {
                                    setState(() {
                                      _busquedaServicio = val;
                                      _mostrarResultados = true;
                                    });
                                  },
                                  onTap: () {
                                    setState(() => _mostrarResultados = true);
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Buscar servicio...',
                                    hintStyle: const TextStyle(color: AppColors.greyLight, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                                    suffixIcon: _buscarServicioCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18, color: AppColors.grey),
                                            onPressed: () {
                                              setState(() {
                                                _buscarServicioCtrl.clear();
                                                _busquedaServicio = '';
                                                _mostrarResultados = false;
                                              });
                                            },
                                          )
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: AppColors.divider),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: AppColors.gold),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.bg,
                                  ),
                                ),
                                // Resultados de búsqueda
                                if (_mostrarResultados) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 220),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Builder(builder: (_) {
                                      final query = _busquedaServicio.toLowerCase();
                                      final agregadosIds = _serviciosAgregados.map((s) => s.id).toSet();
                                      final resultados = _serviciosDisponibles
                                          .where((s) => query.isEmpty || s.nombre.toLowerCase().contains(query))
                                          .toList();

                                      if (resultados.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No se encontraron servicios',
                                            style: TextStyle(color: AppColors.grey, fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }

                                      return ListView.builder(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        itemCount: resultados.length,
                                        itemBuilder: (context, i) {
                                          final s = resultados[i];
                                          final yaIncluido = agregadosIds.contains(s.id);
                                          return InkWell(
                                            onTap: yaIncluido ? null : () => _agregarServicio(s),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              child: Row(
                                                children: [
                                                  // Imagen solo si NO está incluido
                                                  if (!yaIncluido) ...[
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.card,
                                                        borderRadius: BorderRadius.circular(8),
                                                        image: s.imagen != null && s.imagen!.isNotEmpty
                                                            ? DecorationImage(
                                                                image: NetworkImage(s.imagen!),
                                                                fit: BoxFit.cover,
                                                              )
                                                            : null,
                                                      ),
                                                      child: s.imagen == null || s.imagen!.isEmpty
                                                          ? const Icon(Icons.content_cut, color: AppColors.gold, size: 18)
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  // Si ya está incluido, un pequeño spacer para alinear
                                                  if (yaIncluido) const SizedBox(width: 50),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          s.nombre,
                                                          style: TextStyle(
                                                            color: yaIncluido ? AppColors.grey : AppColors.white,
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          yaIncluido
                                                              ? 'Ya está incluido en el paquete'
                                                              : AppFormat.cop(s.precio),
                                                          style: TextStyle(
                                                            color: yaIncluido ? AppColors.gold.withOpacity(0.6) : AppColors.greyLight,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (yaIncluido)
                                                    const Icon(Icons.check_circle, color: AppColors.gold, size: 18)
                                                  else
                                                    const Icon(Icons.add_circle_outline, color: AppColors.gold, size: 18),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Lista de servicios añadidos
                            _serviciosAgregados.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Column(
                                        children: [
                                          Icon(Icons.content_cut, color: AppColors.grey.withOpacity(0.3), size: 36),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Selecciona un servicio para comenzar',
                                            style: TextStyle(color: AppColors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _serviciosAgregados.length,
                                    itemBuilder: (context, idx) {
                                      final s = _serviciosAgregados[idx];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.bg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.divider.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            // Imagen del servicio
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppColors.card,
                                                borderRadius: BorderRadius.circular(10),
                                                image: s.imagen != null && s.imagen!.isNotEmpty
                                                    ? DecorationImage(
                                                        image: NetworkImage(s.imagen!),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child: s.imagen == null || s.imagen!.isEmpty
                                                  ? const Icon(Icons.content_cut, color: AppColors.gold, size: 20)
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(s.nombre, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                                  Text('Base: ${AppFormat.cop(s.precio)}', style: const TextStyle(color: AppColors.greyLight, fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                                              onPressed: () => _eliminarServicio(idx),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Configuración de Duración
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duración del Paquete',
                              style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _horasCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: AppColors.white),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: 'Horas',
                                      labelStyle: const TextStyle(color: AppColors.greyLight),
                                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.divider), borderRadius: BorderRadius.circular(10)),
                                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.gold), borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (_) => _recalcularTotalesYDuracion(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _minutosCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: AppColors.white),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: 'Minutos',
                                      labelStyle: const TextStyle(color: AppColors.greyLight),
                                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.divider), borderRadius: BorderRadius.circular(10)),
                                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.gold), borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (val) {
                                      final m = int.tryParse(val) ?? 0;
                                      if (m > 59) {
                                        _minutosCtrl.text = '59';
                                      }
                                      _recalcularTotalesYDuracion();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('TOTAL', style: TextStyle(color: AppColors.greyLight, fontSize: 9)),
                                      Text(
                                        '${(int.tryParse(_horasCtrl.text) ?? 0) * 60 + (int.tryParse(_minutosCtrl.text) ?? 0)} min',
                                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Precio y Descuento
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _precioCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.white),
                              enabled: !_isNew, // Solo editable en edición
                              decoration: InputDecoration(
                                labelText: 'Precio (\$)',
                                labelStyle: const TextStyle(color: AppColors.greyLight),
                                disabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.divider),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.divider),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.gold),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                fillColor: _isNew ? AppColors.bg.withOpacity(0.4) : null,
                                filled: _isNew,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Requerido';
                                if (double.tryParse(val) == null) return 'Inválido';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _descuentoCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.white),
                              decoration: InputDecoration(
                                labelText: 'Descuento (%)',
                                labelStyle: const TextStyle(color: AppColors.greyLight),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.divider),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.gold),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                final d = double.tryParse(val ?? '0') ?? 0;
                                if (d < 0 || d > 100) {
                                  return 'Entre 0 y 100';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                final d = double.tryParse(val) ?? 0;
                                if (d > 100) {
                                  _descuentoCtrl.text = '100';
                                }
                                _recalcularTotalesYDuracion();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Resumen de Totales
                      if (_serviciosAgregados.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.receipt_long, color: AppColors.gold, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Resumen de Totales',
                                    style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Divider(color: AppColors.divider, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal Servicios:', style: TextStyle(color: AppColors.greyLight, fontSize: 13)),
                                  Text(AppFormat.cop(_subtotal), style: const TextStyle(color: AppColors.white, fontSize: 13)),
                                ],
                              ),
                              if (_descuentoValor > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Descuento (${_descuentoCtrl.text}%):', style: const TextStyle(color: AppColors.greyLight, fontSize: 13)),
                                    Text('- ${AppFormat.cop(_descuentoValor)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                                  ],
                                ),
                              ],
                              const Divider(color: AppColors.divider, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Final:', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text(
                                    AppFormat.cop(_isNew ? _precioTotalCalculado : (double.tryParse(_precioCtrl.text) ?? 0.0)),
                                    style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Botón Guardar
                      GestureDetector(
                        onTap: _loading ? null : _guardar,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC9A96E).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(color: Color(0xFF111111), strokeWidth: 2.5),
                                  )
                                : Text(
                                    _isNew ? 'Crear Paquete' : 'Guardar Cambios',
                                    style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
