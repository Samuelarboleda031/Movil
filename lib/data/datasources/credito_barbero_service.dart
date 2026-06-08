import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class CreditoBarberoInfo {
  final int? id;
  final int barberoId;
  final String? barberoNombre;
  final double cupoMaximo;
  final double saldoDeuda;
  final double cupoDisponible;
  final String estado;
  final int plazoDias;
  final DateTime? fechaInicio;
  final DateTime? fechaVencimiento;
  final DateTime? fechaCierre;
  final bool extensionUsada;

  CreditoBarberoInfo({
    this.id,
    required this.barberoId,
    this.barberoNombre,
    required this.cupoMaximo,
    required this.saldoDeuda,
    required this.cupoDisponible,
    required this.estado,
    this.plazoDias = 7,
    this.fechaInicio,
    this.fechaVencimiento,
    this.fechaCierre,
    this.extensionUsada = false,
  });

  factory CreditoBarberoInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    return CreditoBarberoInfo(
      id: json['id'] ?? json['Id'],
      barberoId: (json['barberoId'] ?? json['BarberoId'] ?? 0) as int,
      barberoNombre: json['barberoNombre'] ?? json['BarberoNombre'],
      cupoMaximo: ((json['cupoMaximo'] ?? json['CupoMaximo'] ?? 200000) as num).toDouble(),
      saldoDeuda: ((json['saldoDeuda'] ?? json['SaldoDeuda'] ?? 0) as num).toDouble(),
      cupoDisponible: ((json['cupoDisponible'] ?? json['CupoDisponible'] ?? 200000) as num).toDouble(),
      estado: json['estado'] ?? json['Estado'] ?? 'Sin crédito',
      plazoDias: (json['plazoDias'] ?? json['PlazoDias'] ?? 7) as int,
      fechaInicio: parseDate(json['fechaInicio'] ?? json['FechaInicio']),
      fechaVencimiento: parseDate(json['fechaVencimiento'] ?? json['FechaVencimiento']),
      fechaCierre: parseDate(json['fechaCierre'] ?? json['FechaCierre']),
      extensionUsada: (json['extensionUsada'] ?? json['ExtensionUsada'] ?? false) as bool,
    );
  }

  bool get estaBloqueado =>
      estado == 'BloqueadoLimite' ||
      estado == 'BloqueadoVencimiento' ||
      estado == 'BloqueadoLimiteYVencimiento';

  bool get estaVencido =>
      estado == 'BloqueadoVencimiento' ||
      estado == 'BloqueadoLimiteYVencimiento';

  bool get estaActivo => estado == 'Activo';

  double get porcentajeUso => cupoMaximo > 0 ? (saldoDeuda / cupoMaximo).clamp(0.0, 1.0) : 0.0;

  /// Días que faltan para vencer (negativo = ya venció).
  int? get diasParaVencer {
    if (fechaVencimiento == null) return null;
    return fechaVencimiento!.difference(DateTime.now()).inDays;
  }

  bool get venceProximo {
    final d = diasParaVencer;
    return d != null && d >= 0 && d <= 2;
  }
}

class CreditoBarberoService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Para admin/manager: obtiene todos los créditos bloqueados.
  Future<List<CreditoBarberoInfo>> obtenerBloqueados() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.creditoBarbero}?page=1&pageSize=100';
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items =
            data is List ? data : (data['items'] ?? data['Items'] ?? []);
        return items
            .map((e) => CreditoBarberoInfo.fromJson(e as Map<String, dynamic>))
            .where((c) => c.estaBloqueado)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Para barbero: obtiene su propio crédito por barberoId.
  Future<CreditoBarberoInfo?> obtenerPorBarbero(int barberoId) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.creditoBarbero}/barbero/$barberoId';
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return CreditoBarberoInfo.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Admin: extiende el plazo del crédito de un barbero (solo se puede usar una vez).
  Future<bool> extenderPlazo(int barberoId, int usuarioId) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.creditoBarbero}/barbero/$barberoId/extender-plazo';
      final response = await http
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({'UsuarioId': usuarioId}),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Admin: inicia un nuevo ciclo de crédito para el barbero.
  Future<bool> nuevoCiclo(
    int barberoId,
    int usuarioId, {
    double? limiteCredito,
    int plazoDias = 7,
  }) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.creditoBarbero}/barbero/$barberoId/nuevo-ciclo';
      final body = <String, dynamic>{
        'UsuarioId': usuarioId,
        'PlazoDias': plazoDias,
        if (limiteCredito != null) 'LimiteCredito': limiteCredito,
      };
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
