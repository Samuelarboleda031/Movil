import 'categoria.dart';

class Producto {
  final int? id;
  final String nombre;
  final String? descripcion;
  final Categoria? categoria;
  final int categoriaId;
  final String? tipo;
  final double precioBase;
  final double precio;
  final double precioVenta;
  final double precioCompra;
  final int stockVentas;
  final int stockInsumos;
  final int cantidad;
  final int minCantidad;
  final String? marca;
  final String? imagenProduc;
  final bool activo;
  final String usoProducto;

  Producto({
    this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    this.categoriaId = 0,
    this.tipo,
    this.precioBase = 0,
    this.precio = 0,
    this.precioVenta = 0,
    this.precioCompra = 0,
    this.stockVentas = 0,
    this.stockInsumos = 0,
    this.cantidad = 0,
    this.minCantidad = 0,
    this.marca,
    this.imagenProduc,
    this.activo = true,
    this.usoProducto = 'venta_e_insumo',
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    // Resolver categoría
    final catRaw = json['Categoria'] ?? json['categoria'];
    final catIdRaw = json['CategoriaId'] ?? json['categoriaId'] ?? json['IdCategoria'] ?? json['idCategoria'];
    
    final catNombreRaw = json['CategoriaNombre'] ?? json['categoriaNombre'] ?? '';
    
    Categoria? categoriaNormalizada;
    if (catRaw != null && catRaw is Map<String, dynamic>) {
      categoriaNormalizada = Categoria.fromJson(catRaw);
    } else if (catRaw != null && (catRaw is int || catRaw is String)) {
      categoriaNormalizada = Categoria(id: int.tryParse(catRaw.toString()), nombre: catNombreRaw);
    } else if (catIdRaw != null) {
      categoriaNormalizada = Categoria(id: int.tryParse(catIdRaw.toString()), nombre: catNombreRaw);
    }

    final estadoRaw = json['Estado'] ?? json['estado'] ?? json['Activo'] ?? json['activo'];
    final bool activoNormalizado = estadoRaw != null ? (estadoRaw == true || estadoRaw == 1 || estadoRaw == 'true') : true;

    final double pBase = (json['PrecioBase'] ?? json['precioBase'] ?? json['precioVenta'] ?? json['precioCompra'] ?? 0).toDouble();
    final double p = (json['Precio'] ?? json['precio'] ?? json['precioVenta'] ?? json['precioCompra'] ?? 0).toDouble();

    final tipoOriginal = json['Tipo'] ?? json['tipo'] ?? json['TipoProducto'] ?? json['tipoProducto'] ?? '';
    final usoOriginal = json['UsoProducto'] ?? json['usoProducto'] ?? json['Uso'] ?? json['uso'];
    
    String usoProdLocal = 'venta_e_insumo';
    String strToCheck = (usoOriginal ?? tipoOriginal).toString().toLowerCase().trim();
    
    if (strToCheck.contains('solo_venta') || strToCheck.contains('solo venta') || strToCheck == '1') {
      usoProdLocal = 'solo_venta';
    } else if (strToCheck.contains('venta_e_insumo') || strToCheck.contains('venta e insumo') || strToCheck == '2') {
      usoProdLocal = 'venta_e_insumo';
    } else {
      // Inferencia dinámica basada en el nombre de la categoría (como en el Frontend web)
      final catNameStr = categoriaNormalizada?.nombre.toLowerCase().trim() ?? '';
      final normalizedCat = catNameStr.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
      final saleOnlyCategories = ['accesorios', 'gafas', 'audifonos', 'cadenas'];
      
      if (saleOnlyCategories.contains(normalizedCat)) {
        usoProdLocal = 'solo_venta';
      }
    }

    return Producto(
      id: json['id'] ?? json['Id'],
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      descripcion: json['descripcion'] ?? json['Descripcion'],
      categoria: categoriaNormalizada,
      categoriaId: categoriaNormalizada?.id ?? int.tryParse(catIdRaw?.toString() ?? '0') ?? 0,
      tipo: tipoOriginal,
      precioBase: pBase,
      precio: p,
      precioVenta: (json['PrecioVenta'] ?? json['precioVenta'] ?? pBase).toDouble(),
      precioCompra: (json['PrecioCompra'] ?? json['precioCompra'] ?? pBase).toDouble(),
      stockVentas: (json['StockVentas'] ?? json['stockVentas'] ?? json['CantidadVentas'] ?? json['cantidadVentas'] ?? 0).toInt(),
      stockInsumos: (json['StockInsumos'] ?? json['stockInsumos'] ?? json['CantidadInsumos'] ?? json['cantidadInsumos'] ?? 0).toInt(),
      cantidad: (json['Cantidad'] ?? json['cantidad'] ?? json['StockTotal'] ?? json['stockTotal'] ?? json['Stock'] ?? json['stock'] ?? 0).toInt(),
      minCantidad: (json['MinCantidad'] ?? json['minCantidad'] ?? json['stockMinimo'] ?? json['StockMinimo'] ?? 0).toInt(),
      marca: json['Marca'] ?? json['marca'],
      imagenProduc: json['ImagenProduc'] ?? json['imagenProduc'],
      activo: activoNormalizado,
      usoProducto: usoProdLocal,
    );
  }

  Producto copyWith({bool? activo}) {
    return Producto(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      categoria: categoria,
      categoriaId: categoriaId,
      tipo: tipo,
      precioBase: precioBase,
      precio: precio,
      precioVenta: precioVenta,
      precioCompra: precioCompra,
      stockVentas: stockVentas,
      stockInsumos: stockInsumos,
      cantidad: cantidad,
      minCantidad: minCantidad,
      marca: marca,
      imagenProduc: imagenProduc,
      activo: activo ?? this.activo,
      usoProducto: usoProducto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id != 0) 'Id': id,
      'Nombre': nombre,
      if (descripcion != null) 'Descripcion': descripcion,
      'CategoriaId': categoriaId != 0 ? categoriaId : (categoria?.id ?? 0),
      'Tipo': usoProducto,
      'PrecioVenta': precioVenta,
      'PrecioCompra': precioCompra,
      'StockVentas': stockVentas,
      'StockInsumos': stockInsumos,
      'StockTotal': cantidad,
      if (marca != null) 'Marca': marca,
      if (imagenProduc != null) 'ImagenProduc': imagenProduc,
      'Estado': activo,
    };
  }
}
