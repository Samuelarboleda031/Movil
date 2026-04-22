import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_bloc.dart';
import 'package:parte_movil/presentation/blocs/auth/auth_event.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/widgets/dashboard_ganancias_widget.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/presentation/pages/producto_detalle_screen.dart';
import 'package:parte_movil/presentation/pages/producto_detalle_cliente_screen.dart';
import 'package:parte_movil/presentation/pages/servicio_detalle_screen.dart';
import 'package:parte_movil/presentation/pages/agendamiento_detalle_screen.dart';
import 'package:parte_movil/presentation/pages/profile_screen.dart';

// ─── TOKENS ────────────────────────────────────────────────────────────────
import 'package:parte_movil/core/themes/app_colors.dart';


// ─── HOME SCREEN ──────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final AppRole role;
  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0; // 0 = Servicios, 1 = Productos
  bool _showDropdown = false;
  int _carouselPage = 0;

  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  
  List<Servicio> _serviciosApi = [];
  List<Producto> _productosApi = [];
  List<Agendamiento> _cortesPasados = [];
  bool _isLoadingData = true;
  int _productsPageSize = 10; // Para paginación vertical de productos

  @override
  void initState() {
    super.initState();
    if (widget.role == AppRole.client) {
      _loadClientData();
    }
  }

  Future<void> _loadClientData() async {
    try {
      final servicios = await AuxiliarService().obtenerServicios();
      final productos = await AuxiliarService().obtenerProductos();
      
      final userContext = UserContextService();
      final cliente = await userContext.obtenerClienteActual();
      
      List<Agendamiento> pasados = [];
      if (cliente != null && cliente.id != null) {
        final paginacion = await AgendamientoService().obtenerAgendamientosPorCliente(cliente.id!, pageSize: 20);
        // Filtrar citas completadas
        pasados = paginacion.items.where((a) => a.estado?.toLowerCase() == 'completada').take(10).toList();
      }
      
      if (mounted) {
        setState(() {
          _serviciosApi = servicios.where((s) => s.estado == true).toList();
          _productosApi = productos.where((p) => p.activo == true).toList();
          _cortesPasados = pasados;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── APPBAR PARA ADMIN/BARBERO ───────────────────────────────────────────
  PreferredSizeWidget _buildAdminAppBar() {
    String title = widget.role == AppRole.barber ? 'Panel Barbero' : 'MANITO BARBERSHOP';
    return AppBar(
      title: Text(title),
      backgroundColor: AppColors.card,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: _logout,
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.white)),
        content: const Text('¿Estás seguro de que deseas salir?', style: TextStyle(color: AppColors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<AuthBloc>().add(LogoutRequested());
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != AppRole.client) {
      // VISTA DE ADMIN / BARBERO (DASHBOARD)
      final user = _authService.currentUser;
      return SessionGuard(
        allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: _buildAdminAppBar(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(widget.role == AppRole.barber ? Icons.content_cut : Icons.admin_panel_settings, size: 60, color: AppColors.gold),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido, ${widget.role == AppRole.barber ? 'Barbero' : 'Administrador'}', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white), 
                  textAlign: TextAlign.center
                ),
                if (user != null && user.email != null) 
                  Text(user.email!, style: const TextStyle(color: AppColors.grey, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                const Text('Resumen del Día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.white)),
                const SizedBox(height: 16),
                DashboardGananciasWidget(role: widget.role),
              ],
            ),
          ),
        ),
      );
    }

    // VISTA DE CLIENTE (LANDING PREMIUM)
    return SessionGuard(
      allowedRoles: const [AppRole.client],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: GestureDetector(
          onTap: () {
            if (_showDropdown) setState(() => _showDropdown = false);
          },
          child: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      _buildHeroBanner(),
                      const SizedBox(height: 16),
                      _buildTabBar(),
                      const SizedBox(height: 16),
                      if (_isLoadingData)
                        const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: AppColors.gold)))
                      else ...[
                        if (_tabIndex == 0) ...[
                          _buildFrequentServices(),
                          const SizedBox(height: 16),
                          _buildPastCuts(),
                        ] else ...[
                          _buildVerticalProducts(),
                        ],
                        const SizedBox(height: 24),
                      ]
                    ],
                  ),
                ),
              ),
              // Dropdown overlay
              if (_showDropdown) _buildDropdownOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER (CLIENTE) ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    final user = _authService.currentUser;
    final email = user?.email ?? 'usuario@correo.com';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 22, color: AppColors.white),
                    children: [
                      TextSpan(text: 'Bienvenido, '),
                      TextSpan(
                        text: 'Cliente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showDropdown = !_showDropdown),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.person, color: AppColors.white, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _showDropdown = !_showDropdown),
            child: const Icon(Icons.keyboard_arrow_down, color: AppColors.white),
          ),
        ],
      ),
    );
  }

  // ── DROPDOWN (CLIENTE) ────────────────────────────────────────────────────
  Widget _buildDropdownOverlay() {
    return Positioned(
      top: 80,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _dropItem(Icons.person_outline, 'Mi Perfil', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(role: widget.role)));
              }),
              _dropDivider(),
              _dropItem(Icons.calendar_today_outlined, 'Mis Citas', onTap: () {}),
              _dropDivider(),
              _dropItem(Icons.shopping_bag_outlined, 'Mis Compras', onTap: () {}),
              _dropDivider(),
              _dropItem(Icons.settings_outlined, 'Configuración', onTap: () {}),
              _dropDivider(),
              _dropItem(
                Icons.logout, 
                'Cerrar sesión', 
                isRed: true, 
                onTap: () {
                  setState(() => _showDropdown = false);
                  _logout();
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropItem(IconData icon, String label, {bool isRed = false, required VoidCallback onTap}) {
    final color = isRed ? Colors.redAccent : AppColors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => _showDropdown = false);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _dropDivider() => Container(height: 1, color: AppColors.divider);

  // ── HERO BANNER ──────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1A0E), Color(0xFF1A1008)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background texture overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withOpacity(0.05),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Tu estilo, nuestra pasión',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Reserva tu cita y luce tu mejor versión.',
                    style: TextStyle(
                      color: AppColors.greyLight,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _goldButton('Reservar ahora', onTap: () {}),
                ],
              ),
            ),
            // Scissors icon decoration
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.content_cut,
                  size: 64,
                  color: AppColors.gold.withOpacity(0.18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.tabInactive,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _tabItem(0, Icons.content_cut, 'Servicios'),
            _tabItem(1, Icons.shopping_bag_outlined, 'Productos'),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
      onTap: () => setState(() {
        _tabIndex = index;
        _carouselPage = 0; // Reset carousel page when switching tabs
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? AppColors.bg : AppColors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.bg : AppColors.grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── VERTICAL PRODUCTS (GRID) ─────────────────────────────────────────────
  Widget _buildVerticalProducts() {
    // Sin filtro, mostrar todos los activos
    final filtered = _productosApi.toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No hay productos disponibles en este momento.', style: TextStyle(color: AppColors.grey)),
      );
    }

    final paged = filtered.take(_productsPageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Catálogo de Productos',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text('${paged.length} de ${filtered.length}', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 220,
          ),
          itemCount: paged.length,
          itemBuilder: (ctx, i) => _productCard(paged[i]),
        ),
        if (_productsPageSize < filtered.length)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: _goldButton(
                'Cargar más productos', 
                onTap: () => setState(() => _productsPageSize += 10)
              ),
            ),
          ),
      ],
    );
  }

  // ── FREQUENT SERVICES (CAROUSEL) ──────────────────────────────────────────
  Widget _buildFrequentServices() {
    if (_serviciosApi.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No hay servicios disponibles en este momento.', style: TextStyle(color: AppColors.grey)),
      );
    }

    return Column(
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'Servicios frecuentes',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('Ver todos', style: TextStyle(color: AppColors.gold, fontSize: 13)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: AppColors.gold, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal scroll cards
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _carouselPage = i),
            itemCount: (_serviciosApi.length / 2).ceil(),
            itemBuilder: (ctx, pageIdx) {
              final start = pageIdx * 2;
              final end = (start + 2).clamp(0, _serviciosApi.length);
              final pageItems = _serviciosApi.sublist(start, end);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: pageItems.map((s) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _serviceCard(s),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots
        if (_serviciosApi.length > 2)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate((_serviciosApi.length / 2).ceil(), (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _carouselPage == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _carouselPage == i ? AppColors.gold : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _serviceCard(Servicio servicio) {
    bool hasImage = servicio.imagen != null && servicio.imagen!.isNotEmpty;
    String imageUrl = '';
    if (hasImage) {
      if (servicio.imagen!.startsWith('http')) {
        imageUrl = servicio.imagen!;
      } else {
        imageUrl = '${ApiConfig.baseUrl}${servicio.imagen}';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServicioDetalleScreen(servicio: servicio, role: widget.role)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder or actual API image
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasImage
                  ? const Center(
                      child: Icon(Icons.content_cut, color: Colors.white24, size: 40),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servicio.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Text(
                      '\$${servicio.precio.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Producto producto) {
    bool hasImage = producto.imagenProduc != null && producto.imagenProduc!.isNotEmpty;
    String imageUrl = '';
    if (hasImage) {
      if (producto.imagenProduc!.startsWith('http')) {
        imageUrl = producto.imagenProduc!;
      } else {
        imageUrl = '${ApiConfig.baseUrl}${producto.imagenProduc}';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductoDetalleClienteScreen(producto: producto)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasImage
                  ? const Center(
                      child: Icon(Icons.shopping_bag_outlined, color: Colors.white24, size: 40),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Text(
                      '\$${producto.precioVenta.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAST CUTS (REAL API DATA) ─────────────────────────────────────────────
  Widget _buildPastCuts() {
    if (_cortesPasados.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.history, color: AppColors.gold, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Cortes pasados',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('Ver historial', style: TextStyle(color: AppColors.gold, fontSize: 13)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: AppColors.gold, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cortesPasados.length,
            itemBuilder: (ctx, i) {
              final colors = [
                const Color(0xFF2B1A10),
                const Color(0xFF101A2B),
                const Color(0xFF0F2B1A),
                const Color(0xFF2B0F1A),
              ];
              return _pastCutCard(_cortesPasados[i], colors[i % colors.length]);
            },
          ),
        ),
      ],
    );
  }

  Widget _pastCutCard(Agendamiento agendamiento, Color bgColor) {
    String dateStr = '';
    try {
      if (agendamiento.fechaCita != null) {
        final date = DateTime.parse(agendamiento.fechaCita!);
        dateStr = DateFormat('dd MMM yyyy').format(date);
      }
    } catch (e) {
      dateStr = agendamiento.fechaCita ?? '';
    }

    // Try to get a thumbnail from the first service if available
    String? imageUrl;
    if (agendamiento.serviciosNombres.isNotEmpty) {
      // Find the service in the API to get its image
      try {
        final apiServ = _serviciosApi.firstWhere((s) => s.nombre == agendamiento.serviciosNombres[0]);
        if (apiServ.imagen != null && apiServ.imagen!.isNotEmpty) {
          if (apiServ.imagen!.startsWith('http')) {
            imageUrl = apiServ.imagen!;
          } else {
            imageUrl = '${ApiConfig.baseUrl}${apiServ.imagen}';
          }
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgendamientoDetalleScreen(agendamiento: agendamiento, role: widget.role)),
        );
      },
      child: Container(
        width: 115,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 95,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null 
                ? const Center(child: Icon(Icons.history, color: Colors.white30, size: 40))
                : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agendamiento.serviciosNombres.isNotEmpty 
                        ? agendamiento.serviciosNombres.join(', ') 
                        : 'Servicio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateStr,
                    style: const TextStyle(color: AppColors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SHARED WIDGETS ────────────────────────────────────────────────────────
  Widget _goldButton(String text, {required VoidCallback onTap, bool compact = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 20,
          vertical: compact ? 10 : 11,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC9A96E).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.bold,
            fontSize: compact ? 12 : 13,
          ),
        ),
      ),
    );
  }
}
