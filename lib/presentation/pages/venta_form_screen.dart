import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/network/api_config.dart';

// ─────────────────────────────────────────────
// PALETA DE COLORES
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// MODELO DE ITEM (Producto / Servicio / Paquete)
// ─────────────────────────────────────────────
class ItemVenta {
  final String tipo; // 'Producto' | 'Servicio' | 'Paquete'
  final int id;

  ItemVenta({required this.tipo, required this.id});

  @override
  bool operator ==(Object other) =>
      other is ItemVenta && other.tipo == tipo && other.id == id;

  @override
  int get hashCode => tipo.hashCode ^ id.hashCode;
}

// ─────────────────────────────────────────────
// DETALLE DE VENTA (estado en formulario)
// ─────────────────────────────────────────────
class DetalleVentaItem {
  int? productoId;
  int? servicioId;
  int? paqueteId;
  ItemVenta? itemSeleccionado;
  int cantidad;
  double precioUnitario;
  int? stockDisponible;
  final TextEditingController cantidadController;

  DetalleVentaItem({
    this.productoId,
    this.servicioId,
    this.paqueteId,
    this.itemSeleccionado,
    required this.cantidad,
    required this.precioUnitario,
    this.stockDisponible,
  }) : cantidadController = TextEditingController(text: cantidad.toString());

  double get subtotal => cantidad * precioUnitario;
}

// ─────────────────────────────────────────────
// SCREEN PRINCIPAL
// ─────────────────────────────────────────────
class VentaFormScreen extends StatefulWidget {
  final Venta? venta;

  const VentaFormScreen({super.key, this.venta});

  @override
  State<VentaFormScreen> createState() => _VentaFormScreenState();
}

class _VentaFormScreenState extends State<VentaFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Servicios
  final VentaService _ventaService = VentaService();
  final ClienteService _clienteService = ClienteService();
  final BarberoService _barberoService = BarberoService();
  final ServicioService _servicioService = ServicioService();
  final PaqueteService _paqueteService = PaqueteService();
  final AuthService _authService = AuthService();
  final UserContextService _userContextService = UserContextService();

  // Datos de referencia
  List<Cliente> _clientes = [];
  List<Barbero> _barberos = [];
  List<Producto> _productos = [];
  List<Servicio> _servicios = [];
  List<Paquete> _paquetes = [];
  int _totalVentasCount = 0; // ← NUEVO: para número de venta

  // Selecciones principales
  Cliente? _clienteSeleccionado;
  Barbero? _barberoSeleccionado;
  Barbero? _barberoDelUsuario;
  int? _usuarioIdActual;
  AppRole? _rolActual;

  // Campos del formulario
  String _metodoPago = 'Efectivo';
  double _porcentajeDescuento = 0.0;
  String _fechaCreacionTexto = '';
  bool _barberoBloqueado = false;
  String? _clienteNombreInvitado;
// ← NUEVO: Saldo a favor
  bool _usarSaldoAFavor = false;
  double _saldoDisponible = 0.0;

  // Detalles
  List<DetalleVentaItem> _detalles = [];
  Producto? _productoParaAgregar;
  ItemVenta? _servicioPaqueteParaAgregar;

  // Estado UI
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _mostrarSeccionProductos = true;
  bool _mostrarSeccionServicios = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _descuentoExcedido = false;

  // ─── CONTROLLERS ──────────────────────────────
  final _descuentoController = TextEditingController();
  final _reciboController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _descuentoController.text = '0';
    _reciboController.text = _numeroVentaFormateado;
    _cargarDatos();
  }

  @override
  void dispose() {
    _animController.dispose();
    _descuentoController.dispose();
    _reciboController.dispose();
    for (final d in _detalles) {
      d.cantidadController.dispose();
    }
    super.dispose();
  }

  // ─── FORMATEO ─────────────────────────────────
  String _formatearFecha(String? isoString) {
    if (isoString == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoString));
    } catch (_) {
      return isoString;
    }
  }

  String get _numeroVentaFormateado {
    if (widget.venta != null) {
      return widget.venta!.numero;
    }
    return (_totalVentasCount + 1).toString();
  }

  // ─── TIPO DE VENTA AUTOMÁTICO ─────────────────
  // ← NUEVO
  String get _tipoVenta {
    if (_clienteSeleccionado == null) return 'Venta Invitado';
    final doc = _clienteSeleccionado!.documento;
    if (doc.startsWith('PASO-')) return 'Venta Invitado';
    return 'Venta Cliente';
  }

  // ─── CÁLCULOS ─────────────────────────────────
  double get _subtotal =>
      _detalles.fold(0.0, (s, d) => s + d.precioUnitario * d.cantidad);

  double get _descuento => _subtotal * (_porcentajeDescuento / 100);

  // ← NUEVO: IVA siempre 0
  double get _iva => 0.0;

  // ← NUEVO: Saldo a favor aplicado
  double get _saldoAplicado {
    if (!_usarSaldoAFavor || _clienteSeleccionado == null) return 0.0;
    final totalSinSaldo = _subtotal + _iva - _descuento;
    return totalSinSaldo < _saldoDisponible ? totalSinSaldo : _saldoDisponible;
  }

  double get _total => (_subtotal + _iva - _descuento - _saldoAplicado).clamp(
    0.0,
    double.infinity,
  );

  // ← NUEVO: ¿El saldo cubre el total completo?
  bool get _saldoCubreTodo {
    final totalSinSaldo = _subtotal + _iva - _descuento;
    return _saldoDisponible >= totalSinSaldo;
  }

  // ─── CARGA DE DATOS ───────────────────────────
  Future<void> _cargarDatos() async {
    try {
      final results = await Future.wait([
        _clienteService.obtenerClientes(),
        _barberoService.obtenerBarberos(),
        ProductoService().getProductos(pageSize: 1000),
        _servicioService.obtenerServicios(),
        _paqueteService.obtenerPaquetes(),
        _ventaService.obtenerVentas(pageSize: 50), // ← NUEVO: para numerar ventas
      ]);

      final clientes = results[0] as List<Cliente>;
      final barberos = results[1] as List<Barbero>;
      final productos = results[2] as List<Producto>;
      final servicios = results[3] as List<Servicio>;
      final paquetes = results[4] as List<Paquete>;
      final paginacionVentas = results[5] as Paginacion<Venta>;

      final usuarioActual =
          await _authService.getCurrentUser() ??
          await _authService.fetchUsuarioDesdeApi();
      final rolActual = usuarioActual?.rolId != null
          ? roleForRolId(usuarioActual!.rolId)
          : null;
      final barberoPropio = await _userContextService.obtenerBarberoActual(
        barberosCache: barberos,
      );

      //

      // Ordenar listas
      clientes.sort(
        (a, b) => a.nombreCompleto.toLowerCase().compareTo(
          b.nombreCompleto.toLowerCase(),
        ),
      );
      barberos.sort(
        (a, b) => a.nombreCompleto.toLowerCase().compareTo(
          b.nombreCompleto.toLowerCase(),
        ),
      );
      productos.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      servicios.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );

      // Manejo modo edición
      Venta? ventaFull;
      if (widget.venta != null) {
        ventaFull = await _ventaService.obtenerVentaPorId(widget.venta!.id!);
        try {
          final detalles = await _ventaService.obtenerDetallesVenta(
            widget.venta!.id!,
          );
          if (detalles.isNotEmpty) {
            ventaFull = Venta(
              id: ventaFull.id,
              numero: ventaFull.numero,
              fechaRegistro: ventaFull.fechaRegistro,
              clienteId: ventaFull.clienteId,
              barberoId: ventaFull.barberoId,
              metodoPago: ventaFull.metodoPago,
              subtotal: ventaFull.subtotal,
              porcentajeDescuento: ventaFull.porcentajeDescuento,
              total: ventaFull.total,
              estado: ventaFull.estado,
              cliente: ventaFull.cliente,
              barbero: ventaFull.barbero,
              detalles: detalles,
            );
          }
        } catch (e) {
          debugPrint('Error al cargar detalles: $e');
        }
      }

      setState(() {
        _clientes = clientes;
        _barberos = barberos;
        _productos = productos;
        _servicios = servicios;
        _paquetes = paquetes;
        
        int maxNumVenta = 0;
        if (paginacionVentas.items.isNotEmpty) {
          for (var v in paginacionVentas.items) {
            final int idVal = v.id ?? 0;
            if (idVal > maxNumVenta) {
              maxNumVenta = idVal;
            }
            
            String clean = v.numero;
            if (clean.contains('-')) {
              clean = clean.split('-').last;
            }
            clean = clean.replaceAll(RegExp(r'\D'), '');
            if (clean.isNotEmpty) {
              final int? parsed = int.tryParse(clean);
              if (parsed != null && parsed < 100000 && parsed > maxNumVenta) {
                maxNumVenta = parsed;
              }
            }
          }
        }
        _totalVentasCount = maxNumVenta > 0 ? maxNumVenta : paginacionVentas.totalCount;

        _rolActual = rolActual;
        _usuarioIdActual = usuarioActual?.id;
        _barberoDelUsuario = barberoPropio;
        _barberoBloqueado = rolActual == AppRole.barber;

        if (_barberoBloqueado) _barberoSeleccionado = barberoPropio;

        if (ventaFull != null) {
          _inicializarCamposEdicion(ventaFull);
          _inicializarDetalles(ventaFull);
        } else {
          _fechaCreacionTexto = DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(DateTime.now());
        }

        if (ventaFull == null) {
          _reciboController.text = _numeroVentaFormateado;
        }

        _isLoadingData = false;
        _animController.forward();
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) _mostrarError(limpiarError(e));
    }
  }

  void _inicializarCamposEdicion(Venta venta) {
    if (venta.clienteId != 0) {
      try {
        _clienteSeleccionado = _clientes.firstWhere(
          (c) => c.id == venta.clienteId,
        );
        _clienteNombreInvitado = null;
        _cargarSaldoCliente(_clienteSeleccionado!);
      } catch (_) {
        _clienteNombreInvitado = venta.clienteNombre;
        _clienteSeleccionado = null;
      }
    } else {
      _clienteNombreInvitado = venta.clienteNombre;
    }

    try {
      _barberoSeleccionado = _barberos.firstWhere(
        (b) => b.id == venta.barberoId,
      );
    } catch (_) {
      _barberoSeleccionado = _barberos.isNotEmpty ? _barberos.first : null;
    }

    _metodoPago = venta.metodoPago;
    _porcentajeDescuento = venta.porcentajeDescuento;
    _descuentoController.text = venta.porcentajeDescuento.toString();
    _reciboController.text = venta.numero;
    _fechaCreacionTexto = _formatearFecha(venta.fechaRegistro);
  }

  void _inicializarDetalles(Venta venta) {
    if (venta.detalles == null) return;
    _detalles = venta.detalles!.map((d) {
      ItemVenta? item;
      int? stock;
      if (d.productoId != null) {
        item = ItemVenta(tipo: 'Producto', id: d.productoId!);
        final prod = _productos.where((p) => p.id == d.productoId).firstOrNull;
        stock = prod?.stockVentas;
      } else if (d.servicioId != null) {
        item = ItemVenta(tipo: 'Servicio', id: d.servicioId!);
      } else if (d.paqueteId != null) {
        item = ItemVenta(tipo: 'Paquete', id: d.paqueteId!);
      }
      return DetalleVentaItem(
        productoId: d.productoId,
        servicioId: d.servicioId,
        paqueteId: d.paqueteId,
        itemSeleccionado: item,
        cantidad: d.cantidad,
        precioUnitario: d.precioUnitario,
        stockDisponible: stock,
      );
    }).toList();
  }

  // ← NUEVO: Carga el saldo a favor desde la API o modelo
  Future<void> _cargarSaldoCliente(Cliente cliente) async {
    try {
      final saldo = await _clienteService.obtenerSaldoAFavor(cliente.id!);
      setState(() => _saldoDisponible = saldo);
    } catch (_) {
      setState(() => _saldoDisponible = 0.0);
    }
  }

  // ─── AGREGAR ITEMS ────────────────────────────
  void _agregarProducto() {
    if (_productoParaAgregar == null) {
      _mostrarError('Seleccione un producto para agregar.');
      return;
    }
    final prod = _productoParaAgregar!;
    if (prod.id == null) return;

    // ← NUEVO: verificar stock
    final stock = prod.stockVentas ?? 0;
    final yaAgregado = _detalles
        .where((d) => d.productoId == prod.id)
        .fold<int>(0, (s, d) => s + d.cantidad);
    if (stock <= 0 || yaAgregado >= stock) {
      _mostrarError('Stock insuficiente para "${prod.nombre}".');
      return;
    }

    setState(() {
      final existente = _detalles
          .where((d) => d.productoId == prod.id)
          .firstOrNull;
      if (existente != null) {
        existente.cantidad++;
      } else {
        _detalles.add(
          DetalleVentaItem(
            productoId: prod.id,
            itemSeleccionado: ItemVenta(tipo: 'Producto', id: prod.id!),
            cantidad: 1,
            precioUnitario: prod.precioVenta,
            stockDisponible: stock,
          ),
        );
      }
      _productoParaAgregar = null;
    });
  }

  void _agregarServicioPaquete() {
    if (_servicioPaqueteParaAgregar == null) {
      _mostrarError('Seleccione un servicio o paquete para agregar.');
      return;
    }
    final item = _servicioPaqueteParaAgregar!;
    final precio = _getPrecioItem(item);

    final existente = _detalles.where((d) => d.itemSeleccionado == item).firstOrNull;
    if (existente != null) {
      _mostrarError('Este ${item.tipo.toLowerCase()} ya fue agregado.');
      return;
    }
    setState(() {
      _detalles.add(
        DetalleVentaItem(
          productoId: item.tipo == 'Producto' ? item.id : null,
          servicioId: item.tipo == 'Servicio' ? item.id : null,
          paqueteId: item.tipo == 'Paquete' ? item.id : null,
          itemSeleccionado: item,
          cantidad: 1,
          precioUnitario: precio,
        ),
      );
      _servicioPaqueteParaAgregar = null;
    });
  }

  double _getPrecioItem(ItemVenta item) {
    return switch (item.tipo) {
      'Producto' =>
        _productos.where((p) => p.id == item.id).firstOrNull?.precioVenta ??
            0.0,
      'Servicio' =>
        _servicios.where((s) => s.id == item.id).firstOrNull?.precio ?? 0.0,
      'Paquete' =>
        _paquetes.where((p) => p.id == item.id).firstOrNull?.precio ?? 0.0,
      _ => 0.0,
    };
  }

  String? _getImagenItem(DetalleVentaItem d) {
    if (d.productoId != null) {
      return _productos.where((p) => p.id == d.productoId).firstOrNull?.imagenProduc;
    } else if (d.servicioId != null) {
      return _servicios.where((s) => s.id == d.servicioId).firstOrNull?.imagen;
    }
    return null;
  }

  IconData _getIconItem(DetalleVentaItem d) {
    if (d.productoId != null) return Icons.inventory_2_outlined;
    if (d.servicioId != null) return Icons.content_cut;
    return Icons.card_giftcard_outlined;
  }

  String _getNombreItem(DetalleVentaItem d) {
    if (d.itemSeleccionado == null) return 'Ítem desconocido';
    final item = d.itemSeleccionado!;
    return switch (item.tipo) {
      'Producto' =>
        'Producto: ${_productos.where((p) => p.id == item.id).firstOrNull?.nombre ?? "Desconocido"}',
      'Servicio' =>
        'Servicio: ${_servicios.where((s) => s.id == item.id).firstOrNull?.nombre ?? "Desconocido"}',
      'Paquete' =>
        'Paquete: ${_paquetes.where((p) => p.id == item.id).firstOrNull?.nombre ?? "Desconocido"}',
      _ => 'Ítem',
    };
  }

  // ─── GUARDAR VENTA ────────────────────────────
  Future<void> _guardarVenta() async {
    if (!_formKey.currentState!.validate()) return;

    if (_detalles.isEmpty) {
      _mostrarError('Debe agregar al menos un producto, servicio o paquete.');
      return;
    }

    final clienteOk =
        _clienteSeleccionado != null ||
        (_clienteNombreInvitado != null &&
            _clienteNombreInvitado!.trim().isNotEmpty);
    if (!clienteOk) {
      _mostrarError(
        'Debe seleccionar un cliente o ingresar el nombre del invitado.',
      );
      return;
    }

    final tieneServicios = _detalles.any((d) => d.servicioId != null);
    Barbero? barberoFinal;

    if (_rolActual == AppRole.barber) {
      if (tieneServicios && _barberoDelUsuario == null) {
        _mostrarError(
          'Tu cuenta no tiene perfil de barbero. Contacta al administrador.',
        );
        return;
      }
      barberoFinal = _barberoDelUsuario;
    } else {
      barberoFinal = _barberoSeleccionado;
      if (tieneServicios && barberoFinal == null) {
        _mostrarError(
          'Debe seleccionar un barbero cuando hay servicios en la venta.',
        );
        return;
      }
    }

    // ← NUEVO: Validar stock antes de enviar
    for (final d in _detalles) {
      if (d.productoId != null &&
          d.stockDisponible != null &&
          d.cantidad > d.stockDisponible!) {
        final nombre = _getNombreItem(d);
        _mostrarError(
          'Stock insuficiente para "$nombre". Máximo: ${d.stockDisponible}.',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final detallesVenta = _detalles
          .map(
            (d) => DetalleVenta(
              id: null,
              ventaId: widget.venta?.id ?? 0,
              productoId: d.productoId,
              servicioId: d.servicioId,
              paqueteId: d.paqueteId,
              cantidad: d.cantidad,
              precioUnitario: d.precioUnitario,
              subTotal: d.subtotal,
            ),
          )
          .toList();

      final venta = Venta(
        id: widget.venta?.id,
        numero: _reciboController.text.trim(),
        fechaRegistro:
            widget.venta?.fechaRegistro ?? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now()),
        clienteId: _clienteSeleccionado?.id ?? 0,
        clienteNombre: _clienteNombreInvitado,
        barberoId: barberoFinal?.id,
        usuarioId: _usuarioIdActual,
        metodoPago: _metodoPago,
        subtotal: _subtotal,
        porcentajeDescuento: _porcentajeDescuento,
        total: _total,
        estado: widget.venta?.estado ?? 'Completada',
        detalles: detallesVenta,
      );

      debugPrint('📤 Enviando venta: ${jsonEncode(venta.toJson())}');

      await _ventaService.crearVenta(venta);

      if (mounted) {
        AppToast.showSuccess(
          context,
          widget.venta == null
              ? '✅ Venta #$_numeroVentaFormateado creada por ${AppFormat.cop(_total)}'
              : '✅ Venta actualizada exitosamente',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _mostrarError(limpiarError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String msg) {
    debugPrint('❌ $msg');
    if (!mounted) return;
    AppToast.showError(context, msg);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: _isLoadingData
            ? _buildLoading()
            : FadeTransition(
                opacity: _fadeAnim,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      100 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    children: [
                      const SizedBox(height: 16),
                      // ── 1. CABECERA DE VENTA ───────────────────
                      _buildVentaHeader(),
                      const SizedBox(height: 16),
                      // ── 2. CLIENTE ─────────────────────────────
                      _buildSeccionCliente(),
                      const SizedBox(height: 16),
                      // ── 3. CONFIGURACIÓN ───────────────────────
                      _buildSeccionConfiguracion(),
                      const SizedBox(height: 16),
                      // ── 4. PRODUCTOS ───────────────────────────
                      _buildSeccionAgregar(
                        titulo: 'Agregar Productos',
                        icono: Icons.shopping_bag_outlined,
                        mostrar: _mostrarSeccionProductos,
                        onToggle: () => setState(
                          () => _mostrarSeccionProductos =
                              !_mostrarSeccionProductos,
                        ),
                        contenido: _buildSelectorProductos(),
                      ),
                      const SizedBox(height: 16),
                      // ── 5. SERVICIOS / PAQUETES ────────────────
                      _buildSeccionAgregar(
                        titulo: 'Agregar Servicios y Paquetes',
                        icono: Icons.content_cut,
                        mostrar: _mostrarSeccionServicios,
                        onToggle: () => setState(
                          () => _mostrarSeccionServicios =
                              !_mostrarSeccionServicios,
                        ),
                        contenido: _buildSelectorServiciosPaquetes(),
                      ),
                      const SizedBox(height: 16),
                      // ── 6. LISTA DE ITEMS AGREGADOS ────────────
                      if (_detalles.isNotEmpty) ...[
                        _buildTituloSeccion(
                          'Items en la Venta',
                          Icons.receipt_long_outlined,
                        ),
                        const SizedBox(height: 8),
                        ..._detalles.asMap().entries.map(
                          (e) => _buildDetalleCard(e.key, e.value),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // ── 7. RESUMEN FINANCIERO ──────────────────
                      _buildResumenFinanciero(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
        // Botón flotante de guardar
        bottomNavigationBar: _isLoadingData ? null : _buildBottomBar(),
      ),
    );
  }

  // ─── APP BAR ──────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.whiteSecondary,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.venta == null ? 'Nueva Venta' : 'Editar Venta',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteSecondary,
            ),
          ),
          if (!_isLoadingData)
            Text(
              'N° $_numeroVentaFormateado  ·  $_fechaCreacionTexto',
              style: const TextStyle(fontSize: 11, color: AppColors.greyLight),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.divider, height: 1),
      ),
    );
  }

  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator(color: AppColors.gold));

  // ─── CABECERA DE VENTA ────────────────────────
  Widget _buildVentaHeader() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildChipInfo(
                  'N° Venta',
                  _numeroVentaFormateado,
                  Icons.tag,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChipInfo(
                  'Tipo',
                  _tipoVenta == 'Venta Cliente' ? 'Cliente' : 'Invitado',
                  Icons.person_outline,
                  valueColor: _tipoVenta == 'Venta Cliente'
                      ? AppColors.green
                      : AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _reciboController,
            style: const TextStyle(color: AppColors.whiteSecondary, fontSize: 14),
            maxLength: 10,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
            decoration: InputDecoration(
              labelText: 'N° Recibo *',
              labelStyle: const TextStyle(color: AppColors.greyLight, fontSize: 12),
              prefixIcon: const Icon(Icons.receipt_outlined, color: AppColors.gold, size: 18),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.red),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'El N° de recibo es obligatorio';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChipInfo(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.gold,
          ),
        ),
      ],
    );
  }

  // ─── SECCIÓN CLIENTE ──────────────────────────
  Widget _buildSeccionCliente() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloSeccion('Cliente', Icons.person_search),
          const SizedBox(height: 12),
          SearchableSelector<Cliente>(
            label: 'Buscar cliente',
            hint: 'Escribe nombre o documento...',
            items: _clientes,
            selectedItem: _clienteSeleccionado,
            displayText: (c) => c.nombreCompleto,
            searchText: (c) => '${c.nombreCompleto} ${c.documento}',
            prefixIcon: Icons.person_outline,
            required: false,
            selectedPrefixBuilder: (c) => _buildImage(
              c.fotoPerfil,
              defaultIcon: Icons.person_outline,
            ),
            renderItem: (c) => Row(
              children: [
                _buildImage(c.fotoPerfil, defaultIcon: Icons.person_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombreCompleto,
                        style: const TextStyle(
                          color: AppColors.whiteSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 11,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${c.documento}  ·  Tel: ${c.telefono}',
                            style: const TextStyle(
                              color: AppColors.greyLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onSelected: (c) {
              setState(() {
                _clienteSeleccionado = c;
                _usarSaldoAFavor = false;
                _saldoDisponible = 0;
                if (c != null) {
                  _clienteNombreInvitado = null;
                  _cargarSaldoCliente(c);
                }
              });
            },
            onChanged: (text) {
              if (_clienteSeleccionado == null) {
                setState(() => _clienteNombreInvitado = text);
              }
            },
          ),

          // Indicador invitado
          if (_clienteSeleccionado == null &&
              _clienteNombreInvitado != null &&
              _clienteNombreInvitado!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 13,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Se registrará como invitado: "$_clienteNombreInvitado"',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ← NUEVO: Panel de saldo a favor
          if (_clienteSeleccionado != null) ...[
            const SizedBox(height: 12),
            _buildSaldoAFavor(),
          ],
        ],
      ),
    );
  }

  // ← NUEVO: Widget de saldo a favor
  Widget _buildSaldoAFavor() {
    final tieneSaldo = _saldoDisponible > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tieneSaldo
            ? AppColors.gold.withOpacity(0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tieneSaldo
              ? AppColors.gold.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: tieneSaldo ? AppColors.gold : AppColors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo a Favor',
                  style: TextStyle(color: AppColors.greyLight, fontSize: 12),
                ),
                Text(
                  'Disponible: ${AppFormat.cop(_saldoDisponible)}',
                  style: TextStyle(
                    color: tieneSaldo ? AppColors.gold : AppColors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (tieneSaldo) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (!_saldoCubreTodo) {
                  _mostrarError(
                    'El saldo no cubre el total. Puedes aplicarlo parcialmente.',
                  );
                }
                setState(() => _usarSaldoAFavor = !_usarSaldoAFavor);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _usarSaldoAFavor
                      ? AppColors.gold.withOpacity(0.2)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _usarSaldoAFavor
                        ? AppColors.gold
                        : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _usarSaldoAFavor
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: _usarSaldoAFavor ? AppColors.gold : AppColors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Usar saldo',
                      style: TextStyle(
                        color: _usarSaldoAFavor
                            ? AppColors.gold
                            : AppColors.greyLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── CONFIGURACIÓN ────────────────────────────
  Widget _buildSeccionConfiguracion() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloSeccion('Configuración', Icons.settings_outlined),
          const SizedBox(height: 12),

          // Barbero (solo visible para admin/manager)
          if (!_barberoBloqueado) ...[
            SearchableSelector<Barbero>(
              label: _detalles.any((d) => d.servicioId != null)
                  ? 'Barbero * (requerido por servicio)'
                  : 'Barbero (opcional)',
              hint: 'Buscar barbero...',
              items: _barberos,
              selectedItem: _barberoSeleccionado,
              displayText: (b) => b.nombreCompleto,
              searchText: (b) => '${b.nombreCompleto} ${b.documento}',
              prefixIcon: Icons.badge_outlined,
              selectedPrefixBuilder: (b) => _buildImage(
                b.fotoPerfil,
                defaultIcon: Icons.badge_outlined,
              ),
              renderItem: (b) => Row(
                children: [
                  _buildImage(b.fotoPerfil, defaultIcon: Icons.badge_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.nombreCompleto,
                          style: const TextStyle(
                            color: AppColors.whiteSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Doc: ${b.documento}',
                          style: const TextStyle(
                            color: AppColors.greyLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onSelected: (b) => setState(() => _barberoSeleccionado = b),
            ),
            const SizedBox(height: 12),
          ],

          // Método de pago
          _buildDropdownField(
            label: 'Método de Pago *',
            value: _metodoPago,
            items: const ['Efectivo', 'Transferencia', 'Nequi'],
            icon: Icons.payment_outlined,
            onChanged: (v) => setState(() => _metodoPago = v!),
          ),
          const SizedBox(height: 12),

          // Descuento
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _descuentoController,
                label: 'Descuento (%)',
                icon: Icons.local_offer_outlined,
                hint: '0',
                inputType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                  ),
                ],
                onChanged: (v) {
                  final n = double.tryParse(v) ?? 0.0;
                  if (n > 100) {
                    _descuentoController.value = TextEditingValue(
                      text: '100',
                      selection: const TextSelection.collapsed(offset: 3),
                    );
                    setState(() {
                      _porcentajeDescuento = 100;
                      _descuentoExcedido = true;
                    });
                  } else {
                    setState(() {
                      _porcentajeDescuento = n.clamp(0, 100);
                      _descuentoExcedido = false;
                    });
                  }
                },
              ),
              if (_descuentoExcedido)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    'El descuento no puede ser superior a 100',
                    style: TextStyle(color: AppColors.red, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Garantía (solo lectura)
          _buildChipInfo(
            'Garantía',
            '15 días',
            Icons.verified_outlined,
          ),
        ],
      ),
    );
  }

  // ─── SECCIÓN AGREGAR (expandible) ─────────────
  Widget _buildSeccionAgregar({
    required String titulo,
    required IconData icono,
    required bool mostrar,
    required VoidCallback onToggle,
    required Widget contenido,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                _buildTituloSeccion(titulo, icono),
                const Spacer(),
                Icon(
                  mostrar ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.greyLight,
                  size: 20,
                ),
              ],
            ),
          ),
          if (mostrar) ...[const SizedBox(height: 12), contenido],
        ],
      ),
    );
  }

  // ─── SELECTOR PRODUCTOS ───────────────────────
  Widget _buildSelectorProductos() {
    final disponibles = _productos
        .where((p) => (p.stockVentas ?? 0) > 0)
        .toList();
    return Column(
      children: [
        SearchableSelector<Producto>(
          label: 'Seleccionar producto',
          hint: 'Escribe el nombre del producto...',
          items: disponibles,
          selectedItem: _productoParaAgregar,
          displayText: (p) => p.nombre,
          searchText: (p) => p.nombre,
          prefixIcon: Icons.inventory_2_outlined,
          onSelected: (p) => setState(() => _productoParaAgregar = p),
          renderItem: (p) => Row(
            children: [
              _buildImage(
                p.imagenProduc,
                isCircular: false,
                defaultIcon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.whiteSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppFormat.cop(p.precioVenta),
                style: const TextStyle(color: AppColors.gold, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'S:${p.stockVentas}',
                  style: const TextStyle(color: AppColors.green, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildBotonAgregar(onTap: _agregarProducto, label: 'Agregar Producto'),
      ],
    );
  }

  // ─── SELECTOR SERVICIOS / PAQUETES ────────────
  Widget _buildSelectorServiciosPaquetes() {
    final List<ItemVenta> opciones = [
      ..._servicios.map((s) => ItemVenta(tipo: 'Servicio', id: s.id!)),
      ..._paquetes.map((p) => ItemVenta(tipo: 'Paquete', id: p.id!)),
    ];

    String getDisplayText(ItemVenta item) {
      if (item.tipo == 'Servicio') {
        return _servicios.firstWhere((s) => s.id == item.id).nombre;
      } else {
        return _paquetes.firstWhere((p) => p.id == item.id).nombre;
      }
    }

    return Column(
      children: [
        SearchableSelector<ItemVenta>(
          label: 'Seleccionar servicio o paquete',
          hint: 'Escribe el nombre...',
          items: opciones,
          selectedItem: _servicioPaqueteParaAgregar,
          displayText: getDisplayText,
          searchText: getDisplayText,
          prefixIcon: Icons.content_cut,
          onSelected: (item) =>
              setState(() => _servicioPaqueteParaAgregar = item),
          renderItem: (item) {
            final isServicio = item.tipo == 'Servicio';
            final nombre = getDisplayText(item);
            final precio = isServicio
                ? _servicios.firstWhere((s) => s.id == item.id).precio
                : _paquetes.firstWhere((p) => p.id == item.id).precio;
            final url = isServicio
                ? _servicios.firstWhere((s) => s.id == item.id).imagen
                : null;

            return Row(
              children: [
                _buildImage(
                  url,
                  isCircular: false,
                  defaultIcon: isServicio ? Icons.cut : Icons.card_giftcard,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.whiteSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isServicio ? 'Servicio' : 'Paquete',
                        style: const TextStyle(
                          color: AppColors.greyLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppFormat.cop(precio),
                  style: const TextStyle(color: AppColors.gold, fontSize: 12),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        _buildBotonAgregar(
          onTap: _agregarServicioPaquete,
          label: 'Agregar Servicio / Paquete',
        ),
      ],
    );
  }

  // ─── TARJETA DE DETALLE ────────────────────────
  Widget _buildDetalleCard(int index, DetalleVentaItem d) {
    final esProducto = d.productoId != null;
    final stockExcedido =
        esProducto && d.stockDisponible != null && d.cantidad > d.stockDisponible!;
    final imagenUrl = _getImagenItem(d);
    final iconoDefault = _getIconItem(d);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stockExcedido ? AppColors.red : AppColors.divider),
      ),
      child: Row(
        children: [
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imagenUrl != null && imagenUrl.isNotEmpty
                ? Image.network(
                    imagenUrl.startsWith('http')
                        ? imagenUrl
                        : '${ApiConfig.baseUrl}$imagenUrl',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackImage(iconoDefault, false),
                  )
                : _buildFallbackImage(iconoDefault, false),
          ),
          const SizedBox(width: 10),
          // Info central
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getNombreItem(d),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.whiteSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppFormat.cop(d.precioUnitario)} c/u  ·  Sub: ${AppFormat.cop(d.subtotal)}',
                  style: const TextStyle(color: AppColors.greyLight, fontSize: 11),
                ),
                if (stockExcedido)
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.red),
                      const SizedBox(width: 3),
                      Text(
                        'Stock máx: ${d.stockDisponible}',
                        style: const TextStyle(color: AppColors.red, fontSize: 10),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Controles de cantidad
          if (!esProducto)
            // Servicios / Paquetes: cantidad fija en 1
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                '1',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.greyLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          else
            // Productos: editable con cap en 906
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCantidadBtn(
                  icon: Icons.remove,
                  onTap: () {
                    if (d.cantidad <= 1) return;
                    setState(() {
                      d.cantidad--;
                      d.cantidadController.text = d.cantidad.toString();
                    });
                  },
                ),
                SizedBox(
                  width: 48,
                  child: TextFormField(
                    controller: d.cantidadController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: TextStyle(
                      color: d.cantidad >= 906 ? AppColors.red : AppColors.whiteSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: d.cantidad >= 906 ? AppColors.red : AppColors.divider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: d.cantidad >= 906 ? AppColors.red : AppColors.divider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: d.cantidad >= 906 ? AppColors.red : AppColors.gold,
                        ),
                      ),
                      filled: true,
                      fillColor: d.cantidad >= 906
                          ? AppColors.red.withOpacity(0.08)
                          : AppColors.surface,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v) ?? 1;
                      // Cap en 906
                      if (n > 906) {
                        setState(() => d.cantidad = 906);
                        d.cantidadController.value = const TextEditingValue(
                          text: '906',
                          selection: TextSelection.collapsed(offset: 3),
                        );
                        return;
                      }
                      // Cap por stock disponible
                      if (d.stockDisponible != null && n > d.stockDisponible!) {
                        _mostrarError('Stock máximo: ${d.stockDisponible}');
                        setState(() => d.cantidad = d.stockDisponible!);
                        d.cantidadController.text = d.stockDisponible.toString();
                        return;
                      }
                      setState(() => d.cantidad = n < 1 ? 1 : n);
                      if (n < 1) {
                        d.cantidadController.text = '1';
                        d.cantidadController.selection =
                            const TextSelection.collapsed(offset: 1);
                      }
                    },
                    onEditingComplete: () {
                      final n = int.tryParse(d.cantidadController.text) ?? 1;
                      if (n < 1) {
                        setState(() => d.cantidad = 1);
                        d.cantidadController.text = '1';
                      }
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                _buildCantidadBtn(
                  icon: Icons.add,
                  onTap: () {
                    if (d.cantidad >= 906) return;
                    if (d.stockDisponible != null && d.cantidad >= d.stockDisponible!) {
                      _mostrarError('Stock máximo alcanzado.');
                      return;
                    }
                    setState(() {
                      d.cantidad++;
                      d.cantidadController.text = d.cantidad.toString();
                    });
                  },
                ),
              ],
            ),
          const SizedBox(width: 6),
          // Eliminar
          GestureDetector(
            onTap: () {
              d.cantidadController.dispose();
              setState(() => _detalles.removeAt(index));
            },
            child: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCantidadBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 14, color: AppColors.greyLight),
      ),
    );
  }

  // ─── RESUMEN FINANCIERO ────────────────────────
  // ← NUEVO: Muestra IVA, saldo aplicado, tipo de venta
  Widget _buildResumenFinanciero() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloSeccion('Resumen Financiero', Icons.calculate_outlined),
          const SizedBox(height: 12),
          _buildFilaResumen('Subtotal', AppFormat.cop(_subtotal)),
          if (_porcentajeDescuento > 0)
            _buildFilaResumen(
              'Descuento (${_porcentajeDescuento.toStringAsFixed(1)}%)',
              '- ${AppFormat.cop(_descuento)}',
              color: AppColors.gold,
            ),
          _buildFilaResumen(
            'IVA',
            AppFormat.cop(_iva),
            color: AppColors.greyLight,
          ),
          if (_usarSaldoAFavor && _saldoAplicado > 0)
            _buildFilaResumen(
              'Saldo a Favor aplicado',
              '- ${AppFormat.cop(_saldoAplicado)}',
              color: AppColors.greyLight,
            ),
          const Divider(color: AppColors.divider, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total a Pagar',
                style: TextStyle(
                  color: AppColors.whiteSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                AppFormat.cop(_total),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ← NUEVO: Garantía
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.greyMedium.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: AppColors.greyLight,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Garantía: 15 días',
                  style: TextStyle(color: AppColors.greyLight, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  'Estado: Completada',
                  style: TextStyle(
                    color: AppColors.green.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaResumen(String label, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.greyLight, fontSize: 13),
          ),
          Text(
            valor,
            style: TextStyle(
              color: color ?? AppColors.whiteSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM BAR ───────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: GestureDetector(
        onTap: _isLoading ? null : _guardarVenta,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: _isLoading
                ? null
                : const LinearGradient(
                    colors: [
                      AppColors.goldDeep,
                      AppColors.gold,
                      AppColors.goldLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _isLoading ? AppColors.divider : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.whiteSecondary,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF111111),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.venta == null
                      ? 'Registrar Venta  ·  ${AppFormat.cop(_total)}'
                      : 'Actualizar Venta',
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPERS DE UI ────────────────────────────
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildTituloSeccion(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Text(
          titulo,
          style: const TextStyle(
            color: AppColors.whiteSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBotonAgregar({
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldDeep, AppColors.gold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Color(0xFF111111), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.greyLight),
      hintStyle: const TextStyle(color: AppColors.grey),
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.gold, size: 18)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildImage(
    String? url, {
    bool isCircular = true,
    IconData defaultIcon = Icons.image,
  }) {
    final imageWidget = url != null && url.isNotEmpty
        ? Image.network(
            url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) =>
                _buildFallbackImage(defaultIcon, isCircular),
          )
        : _buildFallbackImage(defaultIcon, isCircular);

    return ClipRRect(
      borderRadius: BorderRadius.circular(isCircular ? 18 : 6),
      child: imageWidget,
    );
  }

  Widget _buildFallbackImage(IconData icon, bool isCircular) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCircular ? 18 : 6),
        border: Border.all(color: AppColors.divider),
      ),
      child: Icon(icon, size: 18, color: AppColors.grey),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      style: const TextStyle(color: AppColors.whiteSecondary, fontSize: 14),
      dropdownColor: AppColors.card,
      decoration: _inputDecoration(label, icon: icon),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(color: AppColors.whiteSecondary),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    TextInputType? inputType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      readOnly: readOnly,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color: readOnly ? AppColors.greyLight : AppColors.whiteSecondary,
        fontSize: 14,
      ),
      decoration: _inputDecoration(label, icon: icon, hint: hint),
      onChanged: onChanged,
    );
  }
}
