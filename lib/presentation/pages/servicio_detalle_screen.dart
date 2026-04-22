import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/pages/servicio_form_screen.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/network/api_config.dart';

class ServicioDetalleScreen extends StatefulWidget {
  final Servicio servicio;
  final AppRole role;

  const ServicioDetalleScreen({
    Key? key,
    required this.servicio,
    required this.role,
  }) : super(key: key);

  @override
  State<ServicioDetalleScreen> createState() => _ServicioDetalleScreenState();
}

class _ServicioDetalleScreenState extends State<ServicioDetalleScreen> {
  bool _isExpanded = false;
  late Servicio _currentServicio;

  @override
  void initState() {
    super.initState();
    _currentServicio = widget.servicio;
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
            _currentServicio.nombre,
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
                    _buildServiceImage(),
                    const SizedBox(height: 24),

                    _buildInfoGrid(),
                    const SizedBox(height: 24),

                    _buildStatusBadge(),
                    const SizedBox(height: 24),

                    _buildDescription(),
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

  Widget _buildServiceImage() {
    final String? img = _currentServicio.imagen;
    final bool hasImage = img != null && img.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[900]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasImage
            ? Image.network(
                img.startsWith('http') ? img : '${ApiConfig.baseUrl.replaceAll('/api', '')}$img',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
              )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.content_cut,
            size: 64,
            color: const Color(0xFFD8B081).withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin imagen disponible',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildInfoCard('Precio', AppFormat.cop(_currentServicio.precio)),
        _buildInfoCard('Duración', '${_currentServicio.duracionMinutos} min'),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
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
              fontSize: 18,
              color: Color(0xFFD8B081),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final bool isActive = _currentServicio.estado ?? true;
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
            isActive ? 'Disponible' : 'No Disponible',
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
    final String description = _currentServicio.descripcion ?? 'No hay descripción disponible para este servicio.';
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
            color: const Color(0xFF111111),
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
                  fontSize: 14,
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
                      color: Color(0xFFD8B081),
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
          backgroundColor: const Color(0xFFD8B081),
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
              builder: (_) => ServicioFormScreen(servicio: _currentServicio),
            ),
          );
          if (result == true) {
            // Aquí se podría recargar el servicio desde la API si fuera necesario, 
            // por ahora cerramos para que se refresque la lista principal.
            if (mounted) Navigator.pop(context, true);
          }
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 22),
            SizedBox(width: 8),
            Text(
              'EDITAR SERVICIO',
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
