import 'package:flutter/material.dart';

/// Constantes para los estados de las citas
/// 
/// Esta clase define los valores estándar para el campo `estadoCita`
/// del modelo `Agendamiento`, asegurando consistencia en toda la aplicación.
class EstadoCita {
  // Valores de estado
  static const String pendiente = 'Pendiente';
  static const String confirmada = 'Confirmada';
  static const String enCurso = 'En Curso';
  static const String completada = 'Completada';
  static const String cancelada = 'Cancelada';

  // Lista de todos los estados válidos
  static const List<String> todos = [
    pendiente,
    confirmada,
    enCurso,
    completada,
    cancelada,
  ];

  // Lista para filtros (incluye opción "Todos")
  static const List<String> todosConFiltro = [
    'Todos',
    pendiente,
    confirmada,
    enCurso,
    completada,
    cancelada,
  ];

  /// Obtiene el color asociado a un estado de cita
  /// 
  /// Maneja variantes de género (masculino/femenino) para compatibilidad
  /// con datos existentes en la base de datos.
  static Color getColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
      case 'confirmada':
        return Colors.blue;
      case 'en curso':
        return Colors.purple;
      case 'completado':
      case 'completada':
        return Colors.green;
      case 'cancelado':
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Prevenir instanciación
  EstadoCita._();
}
