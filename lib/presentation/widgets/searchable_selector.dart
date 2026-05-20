 import 'package:flutter/material.dart';

/// Widget de búsqueda y selección (equivalente al SearchField del front web).
/// Muestra un campo de texto con lista desplegable filtrada al escribir.
///
/// [T] es el tipo de cada elemento (Cliente, Barbero, Servicio, etc.).
class SearchableSelector<T> extends StatefulWidget {
  final String label;
  final String hint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T item) displayText;
  final String Function(T item) searchText;
  final Widget Function(T item)? renderItem;
  final void Function(T? item) onSelected;
  final void Function(String)? onChanged;
  final bool required;
  final bool enabled;
  final IconData? prefixIcon;
  final String? Function(T?)? validator;
  /// Widget que se muestra como prefijo cuando hay un item seleccionado.
  /// Si es null, se usa el [prefixIcon] normal.
  final Widget Function(T item)? selectedPrefixBuilder;

  const SearchableSelector({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.selectedItem,
    required this.displayText,
    required this.searchText,
    required this.onSelected,
    this.onChanged,
    this.renderItem,
    this.required = false,
    this.enabled = true,
    this.prefixIcon,
    this.validator,
    this.selectedPrefixBuilder,
  });

  @override
  State<SearchableSelector<T>> createState() => _SearchableSelectorState<T>();
}

class _SearchableSelectorState<T> extends State<SearchableSelector<T>> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;
  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    if (widget.selectedItem != null) {
      _ctrl.text = widget.displayText(widget.selectedItem as T);
    }
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SearchableSelector<T> old) {
    super.didUpdateWidget(old);
    // Si la selección externa cambió, actualizar el texto del campo
    if (widget.selectedItem != old.selectedItem) {
      if (widget.selectedItem != null) {
        final txt = widget.displayText(widget.selectedItem as T);
        if (_ctrl.text != txt) {
          _ctrl.text = txt;
          _ctrl.selection = TextSelection.collapsed(offset: txt.length);
        }
      } else if (!_focus.hasFocus) {
        _ctrl.clear();
      }
    }
    // Actualizar lista filtrada si los items cambiaron
    if (widget.items != old.items) {
      _filtered = widget.items;
    }
  }

  @override
  void dispose() {
    _closeOverlay();
    _ctrl.dispose();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      // Al perder foco, si hay un item seleccionado restaurar su texto;
      // si no, limpiar el campo para no dejar texto huérfano.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (widget.selectedItem != null) {
          final expected = widget.displayText(widget.selectedItem as T);
          if (_ctrl.text != expected) {
            _ctrl.text = expected;
          }
        } else if (_ctrl.text.isNotEmpty) {
          // No hay selección → limpiar
          _ctrl.clear();
        }
        _closeOverlay();
      });
    }
  }

  void _filter(String query) {
    final q = _normalize(query);
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items.where((item) {
              return _normalize(widget.searchText(item)).contains(q);
            }).toList();
    });
    if (_isOpen) {
      _overlay?.markNeedsBuild();
    } else {
      _openOverlay();
    }
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .trim();

  void _openOverlay() {
    if (_isOpen) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A), // _kSurface2
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF252525), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Sin resultados para "${_ctrl.text}"',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFF2A2A2A),
                          ),
                          itemBuilder: (_, i) {
                            final item = _filtered[i];
                            final isSelected =
                                widget.selectedItem != null &&
                                    widget.displayText(
                                            widget.selectedItem as T) ==
                                        widget.displayText(item);
                            return InkWell(
                              onTap: () {
                                _ctrl.text = widget.displayText(item);
                                _ctrl.selection = TextSelection.collapsed(
                                    offset: _ctrl.text.length);
                                widget.onSelected(item);
                                _closeOverlay();
                                _focus.unfocus();
                              },
                              child: Container(
                                color: isSelected
                                    ? const Color(0xFF1A1408) // _kGoldTint
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: widget.renderItem != null
                                    ? widget.renderItem!(item)
                                    : Row(
                                        children: [
                                          if (isSelected)
                                            const Icon(Icons.check,
                                                size: 14,
                                                color: Color(0xFFC9A04E)), // _kGoldMid
                                          if (isSelected)
                                            const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              widget.displayText(item),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFFD8B081)
                                                    : Colors.white,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
    setState(() => _isOpen = true);
  }

  void _closeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _isOpen = false);
  }

  void _clearSelection() {
    _ctrl.clear();
    _filtered = widget.items;
    widget.onSelected(null);
    _closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: FormField<T>(
        initialValue: widget.selectedItem,
        validator: widget.validator ??
            (widget.required
                ? (v) {
                    if (widget.selectedItem == null) {
                      return 'Seleccione ${widget.label.replaceAll(' *', '').toLowerCase()}';
                    }
                    return null;
                  }
                : null),
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              enabled: widget.enabled,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) {
                // Si el usuario borró el texto, limpiar selección
                if (val.isEmpty && widget.selectedItem != null) {
                  widget.onSelected(null);
                }
                if (widget.onChanged != null) {
                  widget.onChanged!(val);
                }
                _filter(val);
              },
              onTap: () {
                _filtered = widget.items;
                _openOverlay();
              },
              decoration: InputDecoration(
                labelText: widget.label.isEmpty ? null : widget.label,
                labelStyle: const TextStyle(
                    color: Color(0xFFC9A04E), fontSize: 12),
                hintText: widget.hint,
                hintStyle:
                    const TextStyle(color: Color(0xFF444444), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF141414), // _kSurface
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                prefixIcon: widget.selectedItem != null &&
                        widget.selectedPrefixBuilder != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: widget.selectedPrefixBuilder!(
                            widget.selectedItem as T),
                      )
                    : widget.prefixIcon != null
                        ? Icon(widget.prefixIcon,
                            size: 18, color: const Color(0xFF888888))
                        : null,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.selectedItem != null)
                      GestureDetector(
                        onTap: _clearSelection,
                        child: const Icon(Icons.close,
                            size: 18, color: Color(0xFF666666)),
                      ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down,
                          size: 20, color: Color(0xFF444444)),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF252525), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: field.hasError
                        ? Colors.red
                        : const Color(0xFF252525),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF9A6A25), width: 0.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Colors.red, width: 0.5),
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  field.errorText!,
                  style:
                      const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
