import 'categoria.dart';

class Producto {
  final int? id;
  final String nombre;
  final String? descripcion;
  final Categoria? categoria;
  final int categoriaId;
  final double precioVenta;
  final double precioCompra;
  final int cantidad; // mapea desde Stock en el backend
  final String? marca;
  final String? imagenProduc;
  final bool activo;

  Producto({
    this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    this.categoriaId = 0,
    this.precioVenta = 0,
    this.precioCompra = 0,
    this.cantidad = 0,
    this.marca,
    this.imagenProduc,
    this.activo = true,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    // Resolver categoría
    final catRaw = json['Categoria'] ?? json['categoria'];
    final catIdRaw = json['CategoriaId'] ?? json['categoriaId'] ??
        json['IdCategoria'] ?? json['idCategoria'];
    final catNombreRaw =
        json['CategoriaNombre'] ?? json['categoriaNombre'] ?? '';

    Categoria? categoriaNormalizada;
    if (catRaw != null && catRaw is Map<String, dynamic>) {
      categoriaNormalizada = Categoria.fromJson(catRaw);
    } else if (catRaw != null && (catRaw is int || catRaw is String)) {
      categoriaNormalizada =
          Categoria(id: int.tryParse(catRaw.toString()), nombre: catNombreRaw);
    } else if (catIdRaw != null) {
      categoriaNormalizada = Categoria(
          id: int.tryParse(catIdRaw.toString()), nombre: catNombreRaw);
    }

    final estadoRaw =
        json['Estado'] ?? json['estado'] ?? json['Activo'] ?? json['activo'];
    final bool activoNormalizado = estadoRaw != null
        ? (estadoRaw == true || estadoRaw == 1 || estadoRaw == 'true')
        : true;

    return Producto(
      id: json['id'] ?? json['Id'],
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      descripcion: json['descripcion'] ?? json['Descripcion'],
      categoria: categoriaNormalizada,
      categoriaId: categoriaNormalizada?.id ??
          int.tryParse(catIdRaw?.toString() ?? '0') ??
          0,
      precioVenta:
          (json['PrecioVenta'] ?? json['precioVenta'] ?? 0).toDouble(),
      precioCompra:
          (json['PrecioCompra'] ?? json['precioCompra'] ?? 0).toDouble(),
      // El backend usa "Stock" como campo único de inventario
      cantidad: (json['Stock'] ??
              json['stock'] ??
              json['Cantidad'] ??
              json['cantidad'] ??
              0)
          .toInt(),
      marca: json['Marca'] ?? json['marca'],
      imagenProduc: json['ImagenProduc'] ?? json['imagenProduc'],
      activo: activoNormalizado,
    );
  }

  Producto copyWith({bool? activo}) {
    return Producto(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      categoria: categoria,
      categoriaId: categoriaId,
      precioVenta: precioVenta,
      precioCompra: precioCompra,
      cantidad: cantidad,
      marca: marca,
      imagenProduc: imagenProduc,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id != 0) 'Id': id,
      'Nombre': nombre,
      if (descripcion != null) 'Descripcion': descripcion,
      'CategoriaId': categoriaId != 0 ? categoriaId : (categoria?.id ?? 0),
      'PrecioVenta': precioVenta,
      'PrecioCompra': precioCompra,
      'Stock': cantidad,
      if (marca != null) 'Marca': marca,
      if (imagenProduc != null) 'ImagenProduc': imagenProduc,
      'Estado': activo,
    };
  }
}
