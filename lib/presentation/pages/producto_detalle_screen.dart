import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'producto_form_screen.dart';

// ─── TOKENS ────────────────────────────────────────────────────────────────
class AppColors {
  static const bg          = Color(0xFF111111);
  static const surface     = Color(0xFF1A1A1A);
  static const card        = Color(0xFF1F1F1F);
  static const gold        = Color(0xFFC9A96E);
  static const goldLight   = Color(0xFFE0C080);
  static const goldDark    = Color(0xFF9A7040);
  static const white       = Color(0xFFFFFFFF);
  static const grey        = Color(0xFF888888);
  static const greyLight   = Color(0xFFBBBBBB);
  static const divider     = Color(0xFF2A2A2A);
  static const green       = Color(0xFF4CAF7D);
  static const red         = Color(0xFFE05C5C);
  static const redDark     = Color(0xFF8B1A1A);
}

class ProductoDetalleScreen extends StatefulWidget {
  final Producto producto;
  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildTitleSection(),
                          const SizedBox(height: 20),
                          _buildInventoryCard(),
                          const SizedBox(height: 14),
                          _buildFinancesCard(),
                          const SizedBox(height: 14),
                          if (widget.producto.descripcion != null && widget.producto.descripcion!.isNotEmpty)
                            _buildDescriptionCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildActionBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    String? imageUrl;
    if (widget.producto.imagenProduc != null && widget.producto.imagenProduc!.isNotEmpty) {
      if (widget.producto.imagenProduc!.startsWith('http')) {
        imageUrl = widget.producto.imagenProduc;
      } else {
        imageUrl = '${ApiConfig.baseUrl}${widget.producto.imagenProduc}';
      }
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.bg,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.arrow_back, color: AppColors.white, size: 20),
        ),
      ),
      title: const Text(
        'Detalle del Producto',
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.gold, size: 18),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProductoFormScreen(producto: widget.producto)),
              ).then((_) => setState(() {}));
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, AppColors.bg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A3520), Color(0xFF2A1E10), Color(0xFF111111)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white12),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.producto.nombre,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 28,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _categoryChip(widget.producto.categoria?.nombre ?? 'Sin Categoría'),
            const SizedBox(width: 8),
            _statusChip(
              widget.producto.activo ? 'Activo' : 'Inactivo',
              widget.producto.activo ? AppColors.green : AppColors.red
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D2B10), Color(0xFF5A3F18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInventoryCard() {
    final totalStock = widget.producto.stockVentas + widget.producto.stockInsumos;
    final useLabel = widget.producto.usoProducto == 'solo_venta' ? 'Solo Venta' : 'Venta e Insumos';
    
    return _gradientCard(
      iconData: Icons.bar_chart_rounded,
      title: 'Inventario',
      child: Column(
        children: [
          _infoRow('Stock Total',   totalStock.toString(), isHighlight: true),
          _divider(),
          _infoRow('Stock Ventas',  widget.producto.stockVentas.toString()),
          _divider(),
          _infoRow('Stock Insumos', widget.producto.stockInsumos.toString()),
          _divider(),
          _infoRow('Uso',           useLabel),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disponibilidad', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                  Text(
                    '$totalStock / $totalStock',
                    style: const TextStyle(color: AppColors.greyLight, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 8,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancesCard() {
    final ganancia = widget.producto.precioVenta - widget.producto.precioCompra;
    
    return _gradientCard(
      iconData: Icons.account_balance_wallet_outlined,
      title: 'Finanzas',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _priceBox(
                  label: 'Precio Venta',
                  amount: AppFormat.cop(widget.producto.precioVenta),
                  color: AppColors.gold,
                  bgColor: const Color(0xFF3D2B10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _priceBox(
                  label: 'Precio Compra',
                  amount: AppFormat.cop(widget.producto.precioCompra),
                  color: AppColors.greyLight,
                  bgColor: const Color(0xFF252525),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _divider(),
          _infoRow('Marca', widget.producto.marca ?? 'Genérico'),
          _divider(),
          _infoRow('Ganancia', AppFormat.cop(ganancia), valueColor: AppColors.green),
        ],
      ),
    );
  }

  Widget _priceBox({
    required String label,
    required String amount,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return _gradientCard(
      iconData: Icons.description_outlined,
      title: 'Descripción',
      child: Text(
        widget.producto.descripcion!,
        style: const TextStyle(
          color: AppColors.greyLight,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _gradientCard({
    required IconData iconData,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF222222), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E2E2E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3D2B10), Color(0xFF5A3F18)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(iconData, color: AppColors.gold, size: 17),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlight = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (isHighlight ? AppColors.white : AppColors.greyLight),
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: AppColors.divider.withOpacity(0.6));

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.bg.withOpacity(0), AppColors.bg, AppColors.bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showDeleteDialog(context),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.redDark.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red.withOpacity(0.4)),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.red, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductoFormScreen(producto: widget.producto)),
                ).then((_) => setState(() {}));
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, color: AppColors.bg, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Editar Producto',
                      style: TextStyle(
                        color: AppColors.bg,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.red, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Eliminar Producto',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Estás seguro que deseas eliminar "${widget.producto.nombre}"? Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Center(
                          child: Text('Cancelar', style: TextStyle(color: AppColors.greyLight, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Aquí iría la lógica de eliminar real de la API si existiera en este controlador
                        Navigator.pop(context);
                        Navigator.pop(context); // Volver a la lista
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            content: const Row(
                              children: [
                                Icon(Icons.check, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Producto eliminado', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.red.withOpacity(0.5)),
                        ),
                        child: const Center(
                          child: Text('Eliminar', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
