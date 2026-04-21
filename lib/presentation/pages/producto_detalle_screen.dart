import 'package:flutter/material.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'producto_form_screen.dart';

class ProductoDetalleScreen extends StatelessWidget {
  final Producto producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    final useLabel = producto.usoProducto == 'solo_venta' ? 'Solo Venta' : 'Venta e Insumos';
    final totalStock = producto.stockVentas + producto.stockInsumos;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Producto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProductoFormScreen(producto: producto)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del Producto
            Center(
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  image: producto.imagenProduc != null && producto.imagenProduc!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(producto.imagenProduc!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: producto.imagenProduc == null || producto.imagenProduc!.isEmpty
                    ? Icon(Icons.inventory, size: 80, color: isDark ? Colors.white30 : Colors.black26)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // Información Principal
            Text(
              producto.nombre,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD8B081),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                producto.categoria?.nombre ?? 'Sin Categoría',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Card de Inventario
            _buildInfoCard(
              context,
              title: 'Inventario',
              icon: Icons.analytics_outlined,
              children: [
                _buildRowInfo('Stock Total', totalStock.toString(), isBold: true),
                _buildRowInfo('Stock Ventas', producto.stockVentas.toString()),
                _buildRowInfo('Stock Insumos', producto.stockInsumos.toString()),
                _buildRowInfo('Uso', useLabel),
                _buildRowInfo('Estado', producto.activo ? 'Activo' : 'Inactivo', 
                  color: producto.activo ? Colors.green : Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // Card de Precios
            _buildInfoCard(
              context,
              title: 'Finanzas',
              icon: Icons.payments_outlined,
              children: [
                _buildRowInfo('Precio Venta', AppFormat.cop(producto.precioVenta), isBold: true, color: const Color(0xFFD8B081)),
                _buildRowInfo('Precio Compra', AppFormat.cop(producto.precioCompra)),
                _buildRowInfo('Marca', producto.marca ?? 'Genérico'),
              ],
            ),
            const SizedBox(height: 16),

            // Descripción
            if (producto.descripcion != null && producto.descripcion!.isNotEmpty) ...[
              const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                producto.descripcion!,
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD8B081), size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD8B081))),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRowInfo(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
