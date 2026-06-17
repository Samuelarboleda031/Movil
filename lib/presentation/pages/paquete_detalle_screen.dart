import 'package:flutter/material.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/presentation/pages/paquete_form_screen.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/themes/app_colors.dart';

class PaqueteDetalleScreen extends StatefulWidget {
  final Paquete paquete;
  final AppRole role;

  const PaqueteDetalleScreen({
    super.key,
    required this.paquete,
    required this.role,
  });

  @override
  State<PaqueteDetalleScreen> createState() => _PaqueteDetalleScreenState();
}

class _PaqueteDetalleScreenState extends State<PaqueteDetalleScreen> {
  bool _isExpanded = false;
  late Paquete _currentPaquete;
  final PaqueteService _paqueteService = PaqueteService();
  
  List<Servicio> _serviciosIncluidos = [];
  bool _loadingServicios = true;

  @override
  void initState() {
    super.initState();
    _currentPaquete = widget.paquete;
    _cargarServicios();
  }

  Future<void> _cargarServicios() async {
    setState(() => _loadingServicios = true);
    try {
      final detalles = await _paqueteService.obtenerDetallesPorPaquete(_currentPaquete.id!);
      final List<Servicio> temporales = [];
      
      for (var d in detalles) {
        if (d['servicio'] != null) {
          temporales.add(Servicio.fromJson(d['servicio']));
        }
      }
      
      setState(() {
        _serviciosIncluidos = temporales;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener servicios: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingServicios = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber, AppRole.client],
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _currentPaquete.nombre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverIcon(),
                    const SizedBox(height: 24),

                    _buildInfoGrid(),
                    const SizedBox(height: 24),

                    _buildStatusBadge(),
                    const SizedBox(height: 24),

                    _buildDescription(),
                    const SizedBox(height: 24),

                    _buildServiciosIncluidosSection(),
                  ],
                ),
              ),
            ),

            // Solo admins y managers pueden editar
            if (widget.role == AppRole.admin || widget.role == AppRole.manager)
              _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverIcon() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[900]!, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.gold.withOpacity(0.8),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PAQUETE ESPECIAL',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    // Calcular el precio con descuento
    final double precioOriginal = _currentPaquete.precio;
    final double descuento = _currentPaquete.descuento;
    final double precioFinal = descuento > 0 
        ? precioOriginal - (precioOriginal * (descuento / 100)) 
        : precioOriginal;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildInfoCard('Precio Final', AppFormat.cop(precioFinal)),
        if (descuento > 0)
          _buildInfoCard('Descuento', '${descuento.toStringAsFixed(0)}%'),
        _buildInfoCard('Duración Total', AppFormat.duracion(_currentPaquete.duracionMinutos)),
        if (descuento > 0)
          _buildInfoCard('Precio Original', AppFormat.cop(precioOriginal)),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[900]!, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final bool isActive = _currentPaquete.estado ?? true;
    final Color color = isActive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isActive ? 'Disponible / Activo' : 'No Disponible / Inactivo',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final String description = _currentPaquete.descripcion ?? 'No hay descripción disponible para este paquete.';
    final bool canExpand = description.length > 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[900]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                  height: 1.6,
                ),
              ),
              if (canExpand) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Text(
                    _isExpanded ? 'Ver menos' : 'Leer descripción completa',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiciosIncluidosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Servicios Incluidos en el Paquete',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _loadingServicios
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            : _serviciosIncluidos.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[900]!, width: 1),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay servicios asociados a este paquete.',
                        style: TextStyle(color: AppColors.greyLight, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _serviciosIncluidos.length,
                    itemBuilder: (context, index) {
                      final s = _serviciosIncluidos[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[900]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(8),
                                image: s.imagen != null && s.imagen!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          s.imagen!.startsWith('http')
                                              ? s.imagen!
                                              : '${ApiConfig.baseUrl.replaceAll('/api', '')}${s.imagen}',
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: s.imagen == null || s.imagen!.isEmpty
                                  ? const Icon(
                                      Icons.content_cut,
                                      color: AppColors.gold,
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.nombre,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormat.duracion(s.duracionMinutos),
                                    style: const TextStyle(
                                      color: AppColors.greyLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              AppFormat.cop(s.precio),
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey[900]!, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaqueteFormScreen(paquete: _currentPaquete),
            ),
          );
          if (result == true) {
            // Recargar datos locales tras editar
            _cargarServicios();
            // Para asegurar que la cabecera se actualiza, recargamos el objeto paquete.
            try {
              final todos = await _paqueteService.obtenerPaquetes();
              final idx = todos.indexWhere((p) => p.id == _currentPaquete.id);
              if (idx != -1 && mounted) {
                setState(() {
                  _currentPaquete = todos[idx];
                });
              }
            } catch (_) {}
          }
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 22),
            SizedBox(width: 8),
            Text(
              'EDITAR PAQUETE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
