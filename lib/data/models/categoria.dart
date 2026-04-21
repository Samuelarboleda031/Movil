class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final bool? estado;

  Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    this.estado,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] ?? json['Id'],
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      descripcion: json['descripcion'] ?? json['Descripcion'],
      estado: json['estado'] ?? json['Estado'] ?? json['Activo'] ?? json['activo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id != 0) 'Id': id,
      'Nombre': nombre,
      if (descripcion != null) 'Descripcion': descripcion,
      if (estado != null) 'Estado': estado,
    };
  }
}
