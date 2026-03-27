class Servicio {
  final int? id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int duracionMinutos;
  final bool? estado;

  Servicio({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.duracionMinutos,
    this.estado,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: json['id'] ?? json['ID'],
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      descripcion: json['descripcion'] ?? json['Descripcion'],
      precio: (json['precio'] ?? json['Precio'] ?? 0).toDouble(),
      duracionMinutos: json['duracionMinutos'] ?? json['DuracionMinutos'] ?? 0,
      estado: json['estado'] ?? json['Estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id != 0) 'Id': id,
      'Nombre': nombre,
      'Descripcion': descripcion,
      'Precio': precio,
      'DuracionMinutos': duracionMinutos,
      'Estado': estado,
    };
  }
}
