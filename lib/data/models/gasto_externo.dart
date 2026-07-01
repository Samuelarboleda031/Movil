class GastoExterno {
  final int id;
  final String descripcion;
  final double monto;
  final String categoria;
  final String fecha;
  final int usuarioId;
  final String usuarioNombre;
  final String? notas;
  final String? createdAt;
  final String? updatedAt;

  GastoExterno({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.categoria,
    required this.fecha,
    required this.usuarioId,
    required this.usuarioNombre,
    this.notas,
    this.createdAt,
    this.updatedAt,
  });

  factory GastoExterno.fromJson(Map<String, dynamic> json) {
    return GastoExterno(
      id: json['id'] ?? 0,
      descripcion: json['descripcion'] ?? '',
      monto: (json['monto'] ?? 0).toDouble(),
      categoria: json['categoria'] ?? '',
      fecha: json['fecha'] ?? '',
      usuarioId: json['usuarioId'] ?? 0,
      usuarioNombre: json['usuarioNombre'] ?? '',
      notas: json['notas'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'descripcion': descripcion,
      'monto': monto,
      'categoria': categoria,
      'fecha': fecha,
      'notas': notas,
      'usuarioId': usuarioId,
    };
  }
}

class ResumenDia {
  final String fecha;
  final double ingresosVentas;
  final double ingresosAgendamientos;
  final double ingresosTotal;
  final double gastosExternos;
  final double gananciaNeta;
  final int cantidadGastos;
  final List<GastoExterno> gastos;

  ResumenDia({
    required this.fecha,
    required this.ingresosVentas,
    required this.ingresosAgendamientos,
    required this.ingresosTotal,
    required this.gastosExternos,
    required this.gananciaNeta,
    required this.cantidadGastos,
    required this.gastos,
  });

  factory ResumenDia.fromJson(Map<String, dynamic> json) {
    return ResumenDia(
      fecha: json['fecha'] ?? '',
      ingresosVentas: (json['ingresosVentas'] ?? 0).toDouble(),
      ingresosAgendamientos: (json['ingresosAgendamientos'] ?? 0).toDouble(),
      ingresosTotal: (json['ingresosTotal'] ?? 0).toDouble(),
      gastosExternos: (json['gastosExternos'] ?? 0).toDouble(),
      gananciaNeta: (json['gananciaNeta'] ?? 0).toDouble(),
      cantidadGastos: json['cantidadGastos'] ?? 0,
      gastos: (json['gastos'] as List<dynamic>?)
              ?.map((g) => GastoExterno.fromJson(g))
              .toList() ??
          [],
    );
  }
}

class ResumenRango {
  final String desde;
  final String hasta;
  final double ingresosVentas;
  final double ingresosAgendamientos;
  final double ingresosTotal;
  final double gastosExternos;
  final double gananciaNeta;
  final int cantidadGastos;
  final List<GastoExterno> gastos;

  ResumenRango({
    required this.desde,
    required this.hasta,
    required this.ingresosVentas,
    required this.ingresosAgendamientos,
    required this.ingresosTotal,
    required this.gastosExternos,
    required this.gananciaNeta,
    required this.cantidadGastos,
    required this.gastos,
  });

  factory ResumenRango.fromJson(Map<String, dynamic> json) {
    return ResumenRango(
      desde: json['desde'] ?? '',
      hasta: json['hasta'] ?? '',
      ingresosVentas: (json['ingresosVentas'] ?? 0).toDouble(),
      ingresosAgendamientos: (json['ingresosAgendamientos'] ?? 0).toDouble(),
      ingresosTotal: (json['ingresosTotal'] ?? 0).toDouble(),
      gastosExternos: (json['gastosExternos'] ?? 0).toDouble(),
      gananciaNeta: (json['gananciaNeta'] ?? 0).toDouble(),
      cantidadGastos: json['cantidadGastos'] ?? 0,
      gastos: (json['gastos'] as List<dynamic>?)
              ?.map((g) => GastoExterno.fromJson(g))
              .toList() ??
          [],
    );
  }
}

const List<String> categoriasGasto = [
  'Servicios',
  'Suministros',
  'Mantenimiento',
  'Utilities',
  'Alquiler',
  'Personal',
  'Otros',
];
