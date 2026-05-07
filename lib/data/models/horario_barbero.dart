class HorarioBarbero {
  final int? id;
  final int barberoId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final bool estado;

  HorarioBarbero({
    this.id,
    required this.barberoId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
  });

  factory HorarioBarbero.fromJson(Map<String, dynamic> j) {
    int dia = 0;
    final rawDia = j['diaSemana'] ?? j['DiaSemana'] ?? j['dia'] ?? j['Dia'];
    if (rawDia is int) {
      dia = rawDia;
    } else if (rawDia is String) {
      const nombres = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      dia = nombres.indexOf(rawDia);
      if (dia < 0) dia = 0;
    }

    String parseHora(dynamic val) {
      if (val == null) return '09:00';
      final s = val.toString();
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    return HorarioBarbero(
      id: j['id'] ?? j['Id'],
      barberoId: j['barberoId'] ?? j['BarberoId'] ?? 0,
      diaSemana: dia,
      horaInicio: parseHora(j['horaInicio'] ?? j['HoraInicio']),
      horaFin: parseHora(j['horaFin'] ?? j['HoraFin']),
      estado: j['estado'] ?? j['Estado'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barberoId': barberoId,
      'diaSemana': diaSemana,
      'horaInicio': _toTimeSpan(horaInicio),
      'horaFin': _toTimeSpan(horaFin),
      'estado': estado,
    };
  }

  static String _toTimeSpan(String t) {
    if (t.length == 5) return '$t:00';
    return t;
  }
}
