import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:parte_movil/data/models/venta.dart'; 
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
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

// === CLASE AUXILIAR DE VALOR ÚNICO (Solución al Dropdown Error) ===
// Asegura que el valor seleccionado sea único al combinar tipos (Producto, Servicio, Paquete).
class ItemVenta {
  final String tipo; // 'Producto', 'Servicio', 'Paquete'
  final int id;
  
  ItemVenta({required this.tipo, required this.id});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // La comparación debe basarse en el tipo Y el id
    return other is ItemVenta && other.tipo == tipo && other.id == id;
  }

  @override
  int get hashCode => tipo.hashCode ^ id.hashCode;
}

// Clase para manejar el estado en el formulario (DetalleVentaItem)
class DetalleVentaItem {
  int? productoId;
  int? servicioId;
  int? paqueteId;
  ItemVenta? itemSeleccionado; // Campo de estado para el Dropdown
  int cantidad;
  double precioUnitario;

  DetalleVentaItem({
    this.productoId,
    this.servicioId,
    this.paqueteId,
    this.itemSeleccionado,
    required this.cantidad,
    required this.precioUnitario,
  });
}

// ------------------------------------------------------------------

class VentaFormScreen extends StatefulWidget {
  final Venta? venta;

  const VentaFormScreen({super.key, this.venta});

  @override
  State<VentaFormScreen> createState() => _VentaFormScreenState();
}

class _VentaFormScreenState extends State<VentaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final VentaService _ventaService = VentaService();
  final ClienteService _clienteService = ClienteService();
  final BarberoService _barberoService = BarberoService();
  final ServicioService _servicioService = ServicioService();
  final PaqueteService _paqueteService = PaqueteService();
  final AuthService _authService = AuthService();
  final UserContextService _userContextService = UserContextService();

  List<Cliente> _clientes = [];
  List<Barbero> _barberos = [];
  List<Producto> _productos = [];
  List<Servicio> _servicios = [];
  List<Paquete> _paquetes = [];

  Cliente? _clienteSeleccionado;
  Barbero? _barberoSeleccionado;
  Barbero? _barberoDelUsuario; // Barbero asociado al usuario que registra
  int? _usuarioIdActual; // ID del usuario logeado (responsable)
  AppRole? _rolActual;
  String _metodoPago = 'Efectivo';
  double _porcentajeDescuento = 0.0;

  List<DetalleVentaItem> _detalles = [];
  Producto? _productoSeleccionadoParaAgregar;
  ItemVenta? _servicioPaqueteSeleccionadoParaAgregar;
  String? _clienteNombreInvitado;
  bool _isLoading = false;
  bool _isLoadingData = true; 
  String _fechaCreacionTexto = '';
  bool _barberoBloqueado = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  String _formatearFecha(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }
  
  // Lógica para inicializar los detalles de la venta en modo edición
  void _inicializarDetalles(Venta venta) {
    if (venta.detalles != null) {
      _detalles = venta.detalles!.map((d) {
        
        ItemVenta? item;
        // Lógica crucial: Reconstruir ItemVenta a partir del detalle existente
        if (d.productoId != null) {
          item = ItemVenta(tipo: 'Producto', id: d.productoId!);
        } else if (d.servicioId != null) {
          item = ItemVenta(tipo: 'Servicio', id: d.servicioId!);
        } else if (d.paqueteId != null) {
          item = ItemVenta(tipo: 'Paquete', id: d.paqueteId!);
        }
        
        return DetalleVentaItem(
          productoId: d.productoId,
          servicioId: d.servicioId,
          paqueteId: d.paqueteId,
          itemSeleccionado: item, // Asignar el ItemVenta reconstruido
          cantidad: d.cantidad,
          precioUnitario: d.precioUnitario,
        );
      }).toList();
    }
  }

  Future<void> _cargarDatos() async {
    try {
      // 1. Cargar todas las listas de referencia de la API
      final clientes = await _clienteService.obtenerClientes();
      final barberos = await _barberoService.obtenerBarberos();
      final productos = await ProductoService().getProductos(pageSize: 1000);
      final servicios = await _servicioService.obtenerServicios();
      final paquetes = await _paqueteService.obtenerPaquetes();

      // 1.1 Obtener usuario actual para asociar barbero por defecto
      final usuarioActual =
          await _authService.getCurrentUser() ?? await _authService.fetchUsuarioDesdeApi();
      final rolActual = usuarioActual?.rolId != null ? roleForRolId(usuarioActual!.rolId) : null;
      final barberoPropio =
          await _userContextService.obtenerBarberoActual(barberosCache: barberos);

      Venta? ventaFull;
      if (widget.venta != null) {
        ventaFull = await _ventaService.obtenerVentaPorId(widget.venta!.id!);
        // Fetch details explicitly as they might not be included in the main fetch
        try {
          final detalles = await _ventaService.obtenerDetallesVenta(widget.venta!.id!);
          if (detalles.isNotEmpty) {
             // Create a new Venta object with the fetched details
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
          print('Error fetching details for edit: $e');
        }
      }

      // 1.2 Sort lists for better UX
      clientes.sort((a, b) => a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));
      barberos.sort((a, b) => a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));
      productos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      servicios.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

      setState(() {
        _clientes = clientes;
        _barberos = barberos;
        _productos = productos;
        _servicios = servicios;
        _paquetes = paquetes;

        _rolActual = rolActual;
        _usuarioIdActual = usuarioActual?.id; // Guardar el ID del responsable
        _barberoDelUsuario = barberoPropio;
        _barberoBloqueado = _rolActual == AppRole.barber;
        if (_barberoBloqueado) {
          _barberoSeleccionado = _barberoDelUsuario;
        }

        // 2. Si estamos editando, inicializar los campos
        if (ventaFull != null) {
          // Inicializar campos principales
          if (ventaFull.clienteId != 0) {
            try {
              _clienteSeleccionado = _clientes.firstWhere(
                (c) => c.id == ventaFull!.clienteId,
              );
              _clienteNombreInvitado = null;
            } catch (_) {
              _clienteNombreInvitado = ventaFull.clienteNombre;
              _clienteSeleccionado = null;
            }
          } else {
            _clienteNombreInvitado = ventaFull.clienteNombre;
            _clienteSeleccionado = null;
          }

          try {
            _barberoSeleccionado = _barberos.firstWhere(
              (b) => b.id == ventaFull!.barberoId,
            );
          } catch (_) {
            _barberoSeleccionado = _barberos.isNotEmpty ? _barberos.first : null;
          }
          _metodoPago = ventaFull.metodoPago;
          _porcentajeDescuento = ventaFull.porcentajeDescuento;
          _fechaCreacionTexto = _formatearFecha(ventaFull.fechaRegistro);
          
          // 3. Inicializar los detalles SÓLO después de que _productos, _servicios, etc. están cargados
          _inicializarDetalles(ventaFull);
        } else {
           // Si es venta nueva, establecer la fecha actual de creación (solo visual)
           _fechaCreacionTexto = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
        }

        if (_barberoBloqueado) {
          _barberoSeleccionado = _barberoDelUsuario ?? _barberoSeleccionado;
        }
        
        _isLoadingData = false; // Desbloquear la interfaz
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        _mostrarError('Error al cargar datos: $e');
      }
    }
  }

  double get _subtotal {
    return _detalles.fold(0.0, (sum, item) => sum + (item.precioUnitario * item.cantidad));
  }

  double get _descuento {
    return _subtotal * (_porcentajeDescuento / 100);
  }

  double get _total {
    return _subtotal - _descuento;
  }

  // _requiereBarbero eliminado


  void _eliminarDetalle(int index) {
    setState(() {
      _detalles.removeAt(index);
    });
  }

  double _getPrecioItem(ItemVenta item) {
    switch (item.tipo) {
      case 'Producto':
        final prod = _productos.firstWhere(
          (p) => p.id == item.id,
          orElse: () => Producto(
            id: -1,
            nombre: '',
            categoriaId: 0,
            precioVenta: 0,
          ),
        );
        return prod.id != -1 ? prod.precioVenta : 0.0;
      case 'Servicio':
        final serv = _servicios.firstWhere(
          (s) => s.id == item.id,
          orElse: () => Servicio(
            id: -1,
            nombre: '',
            precio: 0,
            duracionMinutos: 0,
          ),
        );
        return serv.id != -1 ? serv.precio : 0.0;
      case 'Paquete':
        final paq = _paquetes.firstWhere(
          (p) => p.id == item.id,
          orElse: () => Paquete(
            id: -1,
            nombre: '',
            precio: 0,
            duracionMinutos: 0,
          ),
        );
        return paq.id != -1 ? paq.precio : 0.0;
      default:
        return 0.0;
    }
  }

  void _agregarProductoSeleccionado() {
    if (_productoSeleccionadoParaAgregar == null) {
      _mostrarError('Seleccione un producto para agregar.');
      return;
    }

    final prod = _productoSeleccionadoParaAgregar!;
    if (prod.id == null) {
      _mostrarError('Producto inválido.');
      return;
    }

    final itemVenta = ItemVenta(tipo: 'Producto', id: prod.id!);
    final precio = prod.precioVenta;

    setState(() {
      _detalles.add(
        DetalleVentaItem(
          productoId: prod.id,
          servicioId: null,
          paqueteId: null,
          itemSeleccionado: itemVenta,
          cantidad: 1,
          precioUnitario: precio,
        ),
      );
    });
  }

  void _agregarServicioPaqueteSeleccionado() {
    if (_servicioPaqueteSeleccionadoParaAgregar == null) {
      _mostrarError('Seleccione un servicio o paquete para agregar.');
      return;
    }

    final item = _servicioPaqueteSeleccionadoParaAgregar!;
    final precio = _getPrecioItem(item);

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
    });
  }

  void _mostrarError(String mensaje) {
    print('❌ ERROR EN VENTA: $mensaje');
    if (!mounted) return;
    AppToast.showError(context, mensaje);
  }

  Future<void> _guardarVenta() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validaciones de negocio
    if (_detalles.isEmpty) {
      _mostrarError('Debe agregar al menos un producto, servicio o paquete a la venta');
      return;
    }
    
    for (final d in _detalles) {
      if (d.itemSeleccionado == null) {
        _mostrarError('Todos los detalles deben tener seleccionado un producto, servicio o paquete.');
        return;
      }
    }

    if (_clienteSeleccionado == null && (_clienteNombreInvitado == null || _clienteNombreInvitado!.trim().isEmpty)) {
      _mostrarError('Debe seleccionar un cliente o ingresar el nombre de un invitado');
      return;
    }

    final bool tieneServicios = _detalles.any((d) => d.servicioId != null);
    Barbero? barberoParaVenta;

    if (_rolActual == AppRole.barber) {
      if (tieneServicios && _barberoDelUsuario == null) {
        _mostrarError('Tu cuenta no tiene un perfil de barbero asociado. Contacta al administrador.');
        return;
      }
      barberoParaVenta = _barberoDelUsuario;
    } else {
      barberoParaVenta = _barberoSeleccionado;
      if (tieneServicios && barberoParaVenta == null) {
        _mostrarError('Debe seleccionar un barbero responsable de prestar el servicio.');
        return;
      }
    }


    setState(() {
      _isLoading = true;
    });

    try {
      // Mapeo de DetalleVentaItem a DetalleVenta
      final detallesVenta = _detalles.map((d) => DetalleVenta(
        id: null, 
        ventaId: widget.venta?.id ?? 0, 
        productoId: d.productoId,
        servicioId: d.servicioId,
        paqueteId: d.paqueteId,
        cantidad: d.cantidad,
        precioUnitario: d.precioUnitario,
        subTotal: d.precioUnitario * d.cantidad, 
      )).toList();

      final venta = Venta(
        id: widget.venta?.id,
        // Usar la lógica de negocio para generar el número si es nueva
        numero: widget.venta?.numero ?? 'V-${DateTime.now().millisecondsSinceEpoch}',
        fechaRegistro: widget.venta?.fechaRegistro ?? DateTime.now().toIso8601String(),
        clienteId: _clienteSeleccionado?.id ?? 0, // 0 indica cliente invitado/no registrado
        clienteNombre: _clienteNombreInvitado,
        barberoId: barberoParaVenta?.id,
        usuarioId: _usuarioIdActual, 
        metodoPago: _metodoPago,
        subtotal: _subtotal,
        porcentajeDescuento: _porcentajeDescuento,
        total: _total,
        estado: widget.venta?.estado ?? 'Completada',
        detalles: detallesVenta, 
      );

      print('Datos a enviar: ${jsonEncode(venta.toJson())}');

      final currentContext = context;
      final navigator = Navigator.of(currentContext);

      await _ventaService.crearVenta(venta);

      if (mounted) {
        AppToast.showSuccess(context, widget.venta == null 
            ? '✅ Venta creada exitosamente' 
            : '✅ Venta actualizada exitosamente');
        navigator.pop(true); // Retornar éxito
      }
    } catch (e) {
      String errorMessage = 'Error al guardar la venta: $e';
      // if (e.toString().contains('400')) {
      //   errorMessage = 'Error 400: Datos inválidos. Verifique IDs, stock o formato.';
      // }
      _mostrarError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.venta == null ? 'Nueva Venta' : 'Editar Venta'),
          backgroundColor: Colors.brown.shade800,
          foregroundColor: Colors.white,
        ),
        // Muestra el indicador de carga si los datos aún no están listos
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (_fechaCreacionTexto.isNotEmpty) ...[
                      TextFormField(
                        initialValue: _fechaCreacionTexto,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de creación',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Cliente
                    SearchableSelector<Cliente>(
                      label: 'Cliente *',
                      hint: 'Escribe nombre o búscalo...',
                      items: _clientes,
                      selectedItem: _clienteSeleccionado,
                      displayText: (c) => c.nombreCompleto,
                      searchText: (c) => '${c.nombreCompleto} ${c.documento}',
                      prefixIcon: Icons.person_search,
                      required: false, // Permitimos escritura libre para invitados
                      renderItem: (c) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nombreCompleto,
                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                          Text('Doc: ${c.documento}  ·  Tel: ${c.telefono}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      onSelected: (c) {
                        setState(() {
                          _clienteSeleccionado = c;
                          if (c != null) {
                            _clienteNombreInvitado = null;
                          }
                        });
                      },
                      onChanged: (text) {
                        if (_clienteSeleccionado == null) {
                          setState(() {
                            _clienteNombreInvitado = text;
                          });
                        }
                      },
                    ),
                    if (_clienteSeleccionado == null && _clienteNombreInvitado != null && _clienteNombreInvitado!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          'Venta para invitado: "$_clienteNombreInvitado"',
                          style: const TextStyle(color: Color(0xFFD2B48C), fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Barbero
                      SearchableSelector<Barbero>(
                        label: _barberoBloqueado
                            ? 'Barbero (asignado automáticamente)'
                            : _detalles.any((d) => d.servicioId != null)
                                ? 'Barbero * (Obligatorio por Servicio)' 
                                : 'Barbero (Opcional)',
                        hint: 'Escribe el nombre del barbero...',
                      items: _barberos,
                      selectedItem: _barberoSeleccionado,
                      displayText: (b) => b.nombreCompleto,
                      searchText: (b) => '${b.nombreCompleto} ${b.documento}',
                      prefixIcon: Icons.badge,
                      enabled: !_barberoBloqueado,
                      onSelected: (b) => setState(() => _barberoSeleccionado = b),
                    ),
                    const SizedBox(height: 16),
                    // Método de Pago
                    DropdownButtonFormField<String>(
                      initialValue: _metodoPago,
                      decoration: const InputDecoration(
                        labelText: 'Método de Pago *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Efectivo', 'Transferencia', 'Nequi'].map((metodo) {
                        return DropdownMenuItem(
                          value: metodo,
                          child: Text(metodo),
                        );
                      }).toList(),
                      onChanged: (metodo) {
                        setState(() {
                          _metodoPago = metodo!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Porcentaje de Descuento
                    TextFormField(
                      initialValue: _porcentajeDescuento.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Porcentaje de Descuento (%)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _porcentajeDescuento = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Detalles
                    const Text(
                      'Detalles de Venta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Select de Productos + botón agregar
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Producto>(
                            value: _productoSeleccionadoParaAgregar,
                            decoration: const InputDecoration(
                              labelText: 'Productos',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: _productos.map((p) {
                              return DropdownMenuItem<Producto>(
                                value: p,
                                child: Text(
                                  p.nombre,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (p) {
                              setState(() {
                                _productoSeleccionadoParaAgregar = p;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _agregarProductoSeleccionado,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, color: Color(0xFF111111), size: 18),
                                SizedBox(width: 4),
                                Text('Agregar', style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Select de Servicios/Paquetes + botón agregar
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ItemVenta>(
                            value: _servicioPaqueteSeleccionadoParaAgregar,
                            decoration: const InputDecoration(
                              labelText: 'Servicios / Paquetes',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: [
                              ..._servicios.map(
                                (s) => DropdownMenuItem<ItemVenta>(
                                  value: ItemVenta(tipo: 'Servicio', id: s.id!),
                                  child: Text(
                                    'Servicio: ${s.nombre}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              ..._paquetes.map(
                                (p) => DropdownMenuItem<ItemVenta>(
                                  value: ItemVenta(tipo: 'Paquete', id: p.id!),
                                  child: Text(
                                    'Paquete: ${p.nombre}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (item) {
                              setState(() {
                                _servicioPaqueteSeleccionadoParaAgregar = item;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _agregarServicioPaqueteSeleccionado,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, color: Color(0xFF111111), size: 18),
                                SizedBox(width: 4),
                                Text('Agregar', style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Lista resumida de detalles (máx. 2 líneas de texto por ítem)
                    ..._detalles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final detalle = entry.value;

                      String titulo = 'Ítem';
                      String descripcion = '';

                      if (detalle.itemSeleccionado != null) {
                        final item = detalle.itemSeleccionado!;
                        switch (item.tipo) {
                          case 'Producto':
                            final prod = _productos.firstWhere(
                              (p) => p.id == item.id,
                              orElse: () => Producto(
                                id: -1,
                                nombre: 'Producto desconocido',
                                categoriaId: 0,
                                precioVenta: 0,
                              ),
                            );
                            titulo = 'Producto: ${prod.nombre}';
                            break;
                          case 'Servicio':
                            final serv = _servicios.firstWhere(
                              (s) => s.id == item.id,
                              orElse: () => Servicio(
                                id: -1,
                                nombre: 'Servicio desconocido',
                                precio: 0,
                                duracionMinutos: 0,
                              ),
                            );
                            titulo = 'Servicio: ${serv.nombre}';
                            break;
                          case 'Paquete':
                            final paq = _paquetes.firstWhere(
                              (p) => p.id == item.id,
                              orElse: () => Paquete(
                                id: -1,
                                nombre: 'Paquete desconocido',
                                precio: 0,
                                duracionMinutos: 0,
                              ),
                            );
                            titulo = 'Paquete: ${paq.nombre}';
                            break;
                        }
                      }

                      final subtotalDetalle = detalle.cantidad * detalle.precioUnitario;
                      descripcion =
                          'Cant: ${detalle.cantidad}  |  Precio: ${AppFormat.cop(detalle.precioUnitario)}  |  Subtotal: ${AppFormat.cop(subtotalDetalle)}';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  setState(() {
                                    if (detalle.cantidad > 1) {
                                      detalle.cantidad--;
                                    }
                                  });
                                },
                              ),
                              Text('${detalle.cantidad}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    detalle.cantidad++;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarDetalle(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    // Resumen (Card)
                    Card(
                      color: Theme.of(context).cardTheme.color,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                            children: [
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        const Text('Subtotal:'),
                                        Text(AppFormat.cop(_subtotal)),
                                    ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text('Descuento (${_porcentajeDescuento.toStringAsFixed(2)}%):'),
                                        Text('-${AppFormat.cop(_descuento)}'),
                                    ],
                                ),
                                const Divider(),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        const Text(
                                            'Total:',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                            ),
                                        ),
                                        Text(
                                            AppFormat.cop(_total),
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.brown.shade200, // Lighter brown for dark mode
                                            ),
                                        ),
                                    ],
                                ),
                            ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _isLoading || _isLoadingData ? null : _guardarVenta,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC9A96E).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Color(0xFF111111))
                              : Text(
                                  widget.venta == null ? 'Guardar Venta' : 'Actualizar Venta',
                                  style: const TextStyle(
                                    color: Color(0xFF111111),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}