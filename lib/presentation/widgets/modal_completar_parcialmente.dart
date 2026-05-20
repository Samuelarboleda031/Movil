import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';

class ModalCompletarParcialmente extends StatefulWidget {
  final Agendamiento cita;
  final VoidCallback onCompleted;

  const ModalCompletarParcialmente({
    super.key,
    required this.cita,
    required this.onCompleted,
  });

  static Future<void> show(BuildContext context, Agendamiento cita, VoidCallback onCompleted) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModalCompletarParcialmente(cita: cita, onCompleted: onCompleted),
    );
  }

  @override
  State<ModalCompletarParcialmente> createState() => _ModalCompletarParcialmenteState();
}

class _ModalCompletarParcialmenteState extends State<ModalCompletarParcialmente> {
  final Set<int> _serviciosSeleccionados = {};
  final Set<int> _productosSeleccionados = {};
  
  List<Servicio> _servicios = [];
  List<Producto> _productos = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ServicioService().obtenerServicios(),
        ProductoService().getProductos(pageSize: 1000),
      ]);

      if (!mounted) return;

      setState(() {
        final allServicios = results[0] as List<Servicio>;
        final allProductos = results[1] as List<Producto>;

        // Filtrar solo los que están en la cita
        _servicios = allServicios.where((s) => widget.cita.servicioIds.contains(s.id)).toList();
        if (widget.cita.servicio != null && !_servicios.any((s) => s.id == widget.cita.servicio!.id)) {
          _servicios.add(widget.cita.servicio!);
        }
        // Los servicios del paquete ya vienen incluidos en widget.cita.servicioIds por el backend.

        _productos = allProductos.where((p) => widget.cita.productoIds.contains(p.id)).toList();

        // Por defecto, todo seleccionado
        _serviciosSeleccionados.addAll(_servicios.map((s) => s.id!));
        _productosSeleccionados.addAll(widget.cita.productoIds); // Para mantener duplicados en la lista visual, usamos el Set de IDs

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Error cargando datos');
      Navigator.pop(context);
    }
  }

  Future<void> _handleSubmit() async {
    if (_serviciosSeleccionados.isEmpty && _productosSeleccionados.isEmpty) {
      AppToast.showError(context, 'Selecciona al menos un servicio o producto para cobrar');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Reconstruir lista de productos permitiendo múltiples cantidades si estaban en la cita original
      List<int> productosACobrar = [];
      for (int pid in widget.cita.productoIds) {
        if (_productosSeleccionados.contains(pid)) {
          productosACobrar.add(pid);
        }
      }

      final ventaId = await AgendamientoService().completarParcialmente(
        widget.cita.id!,
        _serviciosSeleccionados.toList(),
        productosACobrar,
      );

      // Sincronizar NumeroRecibo con el número de la venta generada
      if (ventaId != null) {
        await VentaService().fijarNumeroRecibo(ventaId);
      }

      if (!mounted) return;
      AppToast.showSuccess(context, 'Cita completada parcialmente. Se ha generado la venta.');
      widget.onCompleted();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Error al procesar: $e');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completar Parcialmente',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona qué servicios y productos se realizaron realmente para generar la venta.',
            style: TextStyle(color: AppColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.gold)))
          else ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_servicios.isNotEmpty) ...[
                      const Text('Servicios', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ..._servicios.map((s) => _buildCheckItem(
                            title: s.nombre,
                            isSelected: _serviciosSeleccionados.contains(s.id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _serviciosSeleccionados.add(s.id!);
                                } else {
                                  _serviciosSeleccionados.remove(s.id);
                                }
                              });
                            },
                          )),
                      const SizedBox(height: 20),
                    ],
                    if (_productos.isNotEmpty) ...[
                      const Text('Productos', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ..._productos.map((p) {
                         // Para visualización simple, mostramos 1 checkbox por producto único.
                         final count = widget.cita.productoIds.where((id) => id == p.id).length;
                         final title = count > 1 ? '\${p.nombre} (x\$count)' : p.nombre;
                         return _buildCheckItem(
                            title: title,
                            isSelected: _productosSeleccionados.contains(p.id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _productosSeleccionados.add(p.id!);
                                } else {
                                  _productosSeleccionados.remove(p.id);
                                }
                              });
                            },
                          );
                      }),
                    ],
                    if (_servicios.isEmpty && _productos.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No hay servicios ni productos para cobrar.', style: TextStyle(color: AppColors.grey)),
                        ),
                      )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting || (_servicios.isEmpty && _productos.isEmpty) ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text(
                        'CONFIRMAR COBRO',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckItem({required String title, required bool isSelected, required ValueChanged<bool?> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? AppColors.gold.withOpacity(0.5) : Colors.transparent),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onChanged,
        activeColor: AppColors.gold,
        checkColor: Colors.black,
        title: Text(title, style: const TextStyle(color: AppColors.white, fontSize: 14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
