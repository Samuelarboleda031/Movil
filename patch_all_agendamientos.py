import re
import os

paths = [
    r'c:\Users\samue\OneDrive\Escritorio\Proyectos\Movil\lib\screens\agendamiento_form_screen.dart',
    r'c:\Users\samue\OneDrive\Escritorio\Proyectos\Movil\lib\screens\barber_agendamiento_form_screen.dart',
    r'c:\Users\samue\OneDrive\Escritorio\Proyectos\Movil\lib\screens\client_agendamiento_form_screen.dart'
]

for path in paths:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Keep track if modified to save it later
        original_content = content

        # 1. Imports
        if "import '../models/producto.dart';" not in content:
            content = content.replace(
                "import '../models/paquete.dart';",
                "import '../models/paquete.dart';\nimport '../models/producto.dart';"
            )

        # 2. State variables
        if "List<Producto> _productos =" not in content:
            content = content.replace(
                "List<Paquete> _paquetes = [];",
                "List<Paquete> _paquetes = [];\n  List<Producto> _productos = [];\n  List<Agendamiento> _todasLasCitas = [];"
            )
        if "List<Servicio> _serviciosSeleccionados =" not in content:
            content = content.replace(
                "Servicio? _servicioSeleccionado;",
                "List<Servicio> _serviciosSeleccionados = [];"
            )
        if "Map<int, int> _productoCantidades =" not in content:
            content = content.replace(
                "Paquete? _paqueteSeleccionado;",
                "Paquete? _paqueteSeleccionado;\n  Map<int, int> _productoCantidades = {};"
            )

        # 3. _cargarDatos
        if "obtenerProductos()" not in content:
            content = content.replace(
                "_auxiliarService.obtenerPaquetes(),",
                "_auxiliarService.obtenerPaquetes(),\n        _auxiliarService.obtenerProductos(),\n        _agendamientoService.obtenerAgendamientos(),"
            )
            content = content.replace(
                "_paquetes = results[3] as List<Paquete>;",
                "_paquetes = results[3] as List<Paquete>;\n        _productos = results[5] as List<Producto>;\n        _todasLasCitas = results[6] as List<Agendamiento>;"
            )

        # Replace _calcularTotal helper inside state class (before _rellenarFormulario)
        calc_total_code = '''
  void _calcularTotal() {
    double total = 0;
    if (_esServicio) {
      for (var s in _serviciosSeleccionados) {
        total += s.precio;
      }
    } else if (_paqueteSeleccionado != null) {
      total += _paqueteSeleccionado!.precio;
    }

    _productoCantidades.forEach((pid, qty) {
      try {
        final p = _productos.firstWhere((prod) => prod.id == pid);
        total += p.precioVenta * qty;
      } catch (_) {}
    });

    setState(() {
       _monto = total;
    });
  }
'''
        if "void _calcularTotal()" not in content:
            content = content.replace("void _rellenarFormulario(Agendamiento a) {", calc_total_code + "\n  void _rellenarFormulario(Agendamiento a) {")

        # 4. _rellenarFormulario - Fix service array and products
        old_rellenar_serv = '''
      if (a.servicioId != null) {
        _servicioSeleccionado = _servicios.firstWhere(
          (s) => s.id == a.servicioId,
          orElse: () => a.servicio!,
        );
        _esServicio = true;
      }'''

        new_rellenar_serv = '''
      if (a.servicioIds.isNotEmpty) {
        _serviciosSeleccionados = _servicios.where((s) => a.servicioIds.contains(s.id)).toList();
        _esServicio = true;
      } else if (a.servicioId != null) {
        try {
          final serv = _servicios.firstWhere((s) => s.id == a.servicioId);
          _serviciosSeleccionados = [serv];
          _esServicio = true;
        } catch(_) {
           if (a.servicio != null) _serviciosSeleccionados = [a.servicio!];
        }
      }
      
      if (a.productoIds.isNotEmpty) {
        _productoCantidades.clear();
        for (var pid in a.productoIds) {
           _productoCantidades[pid] = (_productoCantidades[pid] ?? 0) + 1;
        }
      }'''
        content = content.replace(old_rellenar_serv, new_rellenar_serv)

        # 5. _recalcularSlots update (Overlaps and 30min rule)
        # Solo lo ejecutamos si todavía no lo hemos sobreescrito
        if "final now = DateTime.now();" not in content or "bool solapa = false;" not in content:
            # Need to adapt the condition for when barber selection might be different
            # In barber_agendamiento, barberId is fixed or comes from login.
            # In client_agendamiento, it might be _barberoSeleccionado.
            
            recalcular_re = re.compile(r"// Duración estimada del servicio/paquete.*?_slotsDisponibles = unique;", re.DOTALL)
            match = recalcular_re.search(content)
            if match:
                barbero_check = "if (c.barberoId != _barberoSeleccionado!.id) return false;"
                if "_barberoSeleccionado" not in content:
                    barbero_check = "if (c.barberoId != widget.barberoId && c.barberoId != 0) return false;"
                
                new_recalcular = '''
    // Duración estimada del servicio/paquete seleccionado (en minutos)
    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(0, (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30));
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    if (durMin == 0) durMin = 30; // fallback

    final now = DateTime.now();
    final isToday = _fechaSeleccionada.year == now.year &&
                    _fechaSeleccionada.month == now.month &&
                    _fechaSeleccionada.day == now.day;
    final currentMin = now.hour * 60 + now.minute;

    final String fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

    final citasBarberoHoy = _todasLasCitas.where((c) {
      <BARBERO_CHECK>
      if (c.estado?.toLowerCase() == 'cancelada' || c.estadoCita?.toLowerCase() == 'cancelada') return false;
      String fCita = c.fechaCita ?? '';
      if (fCita.isEmpty && c.fechaHora != null && c.fechaHora!.contains('T')) {
          fCita = c.fechaHora!.split('T')[0];
      }
      if (fCita != fechaStr) return false;
      if (c.id != null && widget.agendamiento != null && c.id == widget.agendamiento!.id) return false;
      return true;
    }).toList();

    final slots = <String>[];
    for (final h in horariosBarbero) {
      int cursor = _toMinutes(h.horaInicio);
      final end = _toMinutes(h.horaFin);
      while (cursor + durMin <= end) {
        bool solapa = false;
        
        // Regla 30 min avance si es hoy
        if (isToday && cursor <= currentMin + 30) {
           solapa = true;
        }
        
        if (!solapa) {
           final endCursor = cursor + durMin;
           for (final c in citasBarberoHoy) {
              if (c.horaInicio == null || c.horaInicio!.isEmpty) continue;
              int startExist = _toMinutes(c.horaInicio!);
              int endExist = 0;
              if (c.horaFin != null && c.horaFin!.isNotEmpty) {
                  endExist = _toMinutes(c.horaFin!);
              } else {
                  endExist = startExist + 60; // fallback duracion c
              }
              if (cursor < endExist && startExist < endCursor) {
                 solapa = true;
                 break;
              }
           }
        }

        if (!solapa) {
           slots.add(_fromMinutes(cursor));
        }
        cursor += 30; // intervalos de 30 min
      }
    }

    // Ordenar y deduplicar
    final unique = slots.toSet().toList()..sort();

    setState(() {
      _slotsDisponibles = unique;'''.replace('<BARBERO_CHECK>', barbero_check)
                content = content[:match.start()] + new_recalcular + content[match.end():]

        # 6. _seleccionarSlot -> update to match multiselect
        if "if (_esServicio && _serviciosSeleccionados.isNotEmpty) {" not in content:
            seleccionar_slot_re = re.compile(r"void _seleccionarSlot\(String slot\) \{.*?setState\(\(\) \{", re.DOTALL)
            new_sel_slot = '''
  void _seleccionarSlot(String slot) {
    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(0, (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30));
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    if (durMin == 0) durMin = 30;
    final finMin = _toMinutes(slot) + durMin;
    setState(() {'''
            content = seleccionar_slot_re.sub(new_sel_slot, content)

        # 7. Guardar agendamiento fixes
        content = content.replace("if (_esServicio && _servicioSeleccionado == null)", "if (_esServicio && _serviciosSeleccionados.isEmpty)")

        # In client screen _clienteSeleccionado doesn't exist (it uses logged in user). Same for barbero
        barbero_id_ref = "_barberoSeleccionado!.id!" if "_barberoSeleccionado!.id!" in content else "widget.barberoId"
        cliente_id_ref = "_clienteSeleccionado!.id!" if "_clienteSeleccionado!.id!" in content else "widget.clienteId"

        guardar_instantiation = f'''
      final agendamiento = Agendamiento(
        id: widget.agendamiento?.id,
        clienteId: {cliente_id_ref},
        barberoId: {barbero_id_ref},
        servicioId: _esServicio && _serviciosSeleccionados.isNotEmpty ? _serviciosSeleccionados.first.id : null,
        servicioIds: _esServicio ? _serviciosSeleccionados.map((s)=>s.id!).toList() : [],
        productoIds: _productoCantidades.entries.expand((e) => List.filled(e.value, e.key)).toList(),
        paqueteId: !_esServicio ? _paqueteSeleccionado!.id : null,
        fechaCita: DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
        horaInicio: _horaInicioSeleccionada,
        horaFin: _horaFinSeleccionada,
        estadoCita: _estadoCita,
        monto: _monto,
        observaciones: _observaciones,
      );'''
        
        guardar_old_re = re.compile(r"final agendamiento = Agendamiento\([^;]+;", re.DOTALL)
        content = guardar_old_re.sub(guardar_instantiation, content)
        
        # 8. Modificar setState en "onSelectionChanged" del Toggle (Servicio / Paquete)
        content = content.replace(
            "setState(() {\n                              _esServicio = s.first;\n                              _servicioSeleccionado = null;\n                              _paqueteSeleccionado = null;\n                              _monto = null;\n                            });",
            "setState(() {\n                              _esServicio = s.first;\n                              _serviciosSeleccionados.clear();\n                              _paqueteSeleccionado = null;\n                              _monto = null;\n                            });"
        )
        content = content.replace(
            "setState(() {\n                                _esServicio = s.first;\n                                _servicioSeleccionado = null;\n                                _paqueteSeleccionado = null;\n                                _monto = null;\n                              });",
            "setState(() {\n                              _esServicio = s.first;\n                              _serviciosSeleccionados.clear();\n                              _paqueteSeleccionado = null;\n                              _monto = null;\n                            });"
        )

        UI_servicios_regex = re.compile(r"_esServicio\s*\?\s*SearchableSelector<Servicio>\s*\([\s\S]*?onSelected:\s*\(s\)\s*\{[\s\S]*?\}\s*,\s*\)\s*:\s*SearchableSelector<Paquete>\s*\(", re.DOTALL)
        
        UI_servicios_new = '''
                        _esServicio
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SearchableSelector<Servicio>(
                                    label: 'Añadir Servicio',
                                    hint: 'Escribe el nombre del servicio...',
                                    items: _servicios,
                                    selectedItem: null, // Siempre nulo para multi-select
                                    displayText: (s) => s.nombre,
                                    searchText: (s) => s.nombre,
                                    prefixIcon: Icons.cut,
                                    required: _serviciosSeleccionados.isEmpty,
                                    renderItem: (s) => Row(
                                      children: [
                                        Expanded(
                                          child: Text(s.nombre,
                                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        ),
                                        Text(
                                          '\\$${s.precio.toStringAsFixed(0)} · ${s.duracionMinutos}min',
                                          style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    onSelected: (s) {
                                      if (s != null && !_serviciosSeleccionados.any((sel) => sel.id == s.id)) {
                                          setState(() {
                                            _serviciosSeleccionados.add(s);
                                            _paqueteSeleccionado = null;
                                            _horaInicioSeleccionada = null;
                                            _horaFinSeleccionada = null;
                                            _calcularTotal();
                                          });
                                          _recalcularSlots();
                                      }
                                    },
                                  ),
                                  if (_serviciosSeleccionados.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _serviciosSeleccionados.map((s) => Chip(
                                        label: Text(s.nombre),
                                        onDeleted: () {
                                          setState(() {
                                            _serviciosSeleccionados.removeWhere((sel) => sel.id == s.id);
                                            _horaInicioSeleccionada = null;
                                            _horaFinSeleccionada = null;
                                            _calcularTotal();
                                          });
                                          _recalcularSlots();
                                        },
                                        backgroundColor: const Color(0xFFD8B081).withOpacity(0.2),
                                        deleteIconColor: const Color(0xFFD8B081),
                                        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                                        side: const BorderSide(color: Color(0xFFD8B081)),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              )
                            : SearchableSelector<Paquete>('''
        content = UI_servicios_regex.sub(UI_servicios_new, content)

        # 9. Agregar la UI de productos (Just above _sectionCard for Fecha)
        fecha_ui = "_sectionCard(\n                        icon: Icons.calendar_today,\n                        title: 'Fecha de Cita *',"
        
        productos_ui = '''
                      // ── Productos (Extra) ────────────────────────────────
                      _sectionCard(
                        icon: Icons.shopping_bag,
                        title: 'Productos (Opcional)',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SearchableSelector<Producto>(
                              label: 'Añadir Producto',
                              hint: 'Escribe el nombre del producto...',
                              items: _productos,
                              selectedItem: null,
                              displayText: (p) => p.nombre,
                              searchText: (p) => p.nombre,
                              prefixIcon: Icons.shopping_bag,
                              required: false,
                              renderItem: (p) => Row(
                                children: [
                                  Expanded(
                                    child: Text(p.nombre,
                                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  ),
                                  Text(
                                    '\\$${p.precioVenta.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12),
                                  ),
                                ],
                              ),
                              onSelected: (p) {
                                if (p != null) {
                                  setState(() {
                                    _productoCantidades[p.id!] = (_productoCantidades[p.id!] ?? 0) + 1;
                                    _calcularTotal();
                                  });
                                }
                              },
                            ),
                            if (_productoCantidades.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ..._productoCantidades.entries.map((e) {
                                final p = _productos.firstWhere((prod) => prod.id == e.key, orElse: () => Producto(nombre: 'Desconocido', categoriaId: 0, proveedorId: 0, precioCompra: 0, precioVenta: 0));
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(p.nombre, style: const TextStyle(color: Colors.white)),
                                      ),
                                      Text('\\$${p.precioVenta.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white54)),
                                      const SizedBox(width: 10),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFD8B081)),
                                            onPressed: () {
                                              setState(() {
                                                if (e.value > 1) {
                                                  _productoCantidades[e.key] = e.value - 1;
                                                } else {
                                                  _productoCantidades.remove(e.key);
                                                }
                                                _calcularTotal();
                                              });
                                            },
                                          ),
                                          Text('${e.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFD8B081)),
                                            onPressed: () {
                                              setState(() {
                                                _productoCantidades[e.key] = e.value + 1;
                                                _calcularTotal();
                                              });
                                            },
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      '''
        if "Productos (Extra)" not in content:
            content = content.replace(fecha_ui, productos_ui + fecha_ui)
            # handle alternate spacing
            content = content.replace("                      _sectionCard(\n                              icon: Icons.calendar_today,\n                              title: 'Fecha de Cita *',", productos_ui + "                      _sectionCard(\n                              icon: Icons.calendar_today,\n                              title: 'Fecha de Cita *',")

        UI_paquetes_onSelected_re = re.compile(r"onSelected:\s*\(\s*p\s*\)\s*\{[\s\S]*?_recalcularSlots\(\);\s*\},")
        UI_paquetes_onSelected_new = '''
                                onSelected: (p) {
                                  setState(() {
                                    _paqueteSeleccionado = p;
                                    _serviciosSeleccionados.clear();
                                    _horaInicioSeleccionada = null;
                                    _horaFinSeleccionada = null;
                                    _calcularTotal();
                                  });
                                  _recalcularSlots();
                                },'''
        content = UI_paquetes_onSelected_re.sub(UI_paquetes_onSelected_new, content)

        if content != original_content:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Patched: {path}")
        else:
            print(f"No changes made to {path} (already patched?)")

    except Exception as e:
        print(f"ERROR on {path}: {e}")
