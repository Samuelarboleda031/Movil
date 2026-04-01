class Producto {
  final int? id;
  final String nombre;
  final String? descripcion;
  final int categoriaId;
  final int proveedorId;
  final double precioCompra;
  final double precioVenta;
  final int stock;
  final int stockMinimo;
  final bool? estado;

  Producto({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.categoriaId,
    required this.proveedorId,
    required this.precioCompra,
    required this.precioVenta,
    this.stock = 0,
    this.stockMinimo = 0,
    this.estado,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] ?? json['ID'],
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      descripcion: json['descripcion'] ?? json['Descripcion'],
      categoriaId: json['categoriaId'] ?? json['CategoriaID'] ?? 0,
      proveedorId: json['proveedorId'] ?? json['ProveedorID'] ?? 0,
      precioCompra: (json['precioCompra'] ?? json['PrecioCompra'] ?? 0).toDouble(),
      precioVenta: (json['precioVenta'] ?? json['PrecioVenta'] ?? 0).toDouble(),
      stock: json['stock'] ?? json['Stock'] ?? 0,
      stockMinimo: json['stockMinimo'] ?? json['StockMinimo'] ?? 0,
      estado: json['estado'] ?? json['Estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id != 0) 'Id': id,
      'Nombre': nombre,
      'Descripcion': descripcion,
      'CategoriaId': categoriaId,
      'ProveedorId': proveedorId,
      'PrecioCompra': precioCompra,
      'PrecioVenta': precioVenta,
      'Stock': stock,
      'StockMinimo': stockMinimo,
      'Estado': estado,
    };
  }
}
