import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart';
import 'package:sidcop_mobile/services/RecargasService.Dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/ui/screens/recharges/recarga_detalle_bottom_sheet.dart';

import 'dart:convert';

class RechargesScreen extends StatefulWidget {
  const RechargesScreen({super.key});

  @override
  State<RechargesScreen> createState() => _RechargesScreenState();
}

class _RechargesScreenState extends State<RechargesScreen> {
  bool _verTodasLasRecargas = false;
  Future<List<RecargasViewModel>> _getRecargasConPersonaId() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    final personaId = userData?['personaId'] ?? userData?['usua_IdPersona'] ?? userData?['idPersona'];
    if (personaId == null) {
      throw Exception('No se encontró personaId en los datos de usuario');
    }
    return RecargasService().getRecargas(personaId is int ? personaId : int.tryParse(personaId.toString()) ?? 0);
  }

  List<dynamic> permisos = [];

  @override
  void initState() {
    super.initState();
    _loadPermisos();
  }

  Future<void> _loadPermisos() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    if (userData != null && (userData['PermisosJson'] != null || userData['permisosJson'] != null)) {
      try {
        final permisosJson = userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }
  void _openRecargaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RecargaBottomSheet(),
    ).then((value) {
      if (value == true) {
        setState(() {}); // Refresca la lista de recargas
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Recarga',
      icon: Icons.sync,
      permisos: permisos,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historial de solicitudes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _verTodasLasRecargas = !_verTodasLasRecargas;
                      });
                    },
                    child: Text(
                      _verTodasLasRecargas ? 'Cerrar' : 'Ver más',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<RecargasViewModel>>(
                future: _getRecargasConPersonaId(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final recargas = snapshot.data ?? [];
                  final Map<int, List<RecargasViewModel>> agrupadas = {};
                  for (final r in recargas) {
                    if (r.reca_Id != null) {
                      agrupadas.putIfAbsent(r.reca_Id!, () => []).add(r);
                    }
                  }
                  final entriesList = agrupadas.entries.toList();
                  final mostrarTodas = _verTodasLasRecargas;
                  final itemsToShow = mostrarTodas ? entriesList : entriesList.take(3).toList();

                  // Validación de recarga de hoy
                  final now = DateTime.now();
                  final existeRecargaHoy = recargas.any((r) {
                    if (r.reca_Fecha == null || r.reca_Confirmacion == null) return false;
                    final fecha = r.reca_Fecha!;
                    final mismoDia = fecha.year == now.year && fecha.month == now.month && fecha.day == now.day;
                    final estado = r.reca_Confirmacion?.toUpperCase();
                    return mismoDia && (estado == 'P' || estado == 'A');
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (agrupadas.isEmpty)
                        const Center(child: Text('No hay recargas.'))
                      else
                        Column(
                          children: itemsToShow.map((entry) {
                            final recaId = entry.key;
                            final recargasGrupo = entry.value;
                            final recarga = recargasGrupo.first;
                            final totalCantidad = recargasGrupo.fold<int>(0, (
                              sum,
                              r,
                            ) {
                              if (r.reDe_Cantidad == null) return sum;
                              if (r.reDe_Cantidad is int)
                                return sum + (r.reDe_Cantidad as int);
                              return sum +
                                  (int.tryParse(r.reDe_Cantidad.toString()) ?? 0);
                            });
                            return _buildHistorialCard(
                              _mapEstadoFromApi(recarga.reca_Confirmacion),
                              recarga.reca_Fecha != null
                                  ? _formatFechaFromApi(
                                      recarga.reca_Fecha!.toIso8601String(),
                                    )
                                  : '-',
                              totalCantidad,
                              recargasGrupo: recargasGrupo,
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Solicitar recarga',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: existeRecargaHoy ? null : _openRecargaModal,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: existeRecargaHoy ? Colors.grey : const Color(0xFF141A2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  existeRecargaHoy ? 'Ya tienes una recarga hoy' : 'Abrir recarga',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (existeRecargaHoy)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Ya tienes una recarga solicitada o aprobada para hoy.',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mapEstadoFromApi(dynamic recaConfirmacion) {
    if (recaConfirmacion == "A") return 'Aprobada';
    if (recaConfirmacion == "R") return 'Rechazada';
    return 'En proceso';
  }

  String _formatFechaFromApi(String fechaIso) {
    try {
      final date = DateTime.parse(fechaIso);
      return "${date.day} de " +
          _mesEnEspanol(date.month) +
          " del ${date.year}";
    } catch (_) {
      return fechaIso;
    }
  }

  String _mesEnEspanol(int mes) {
    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[mes];
  }

  Widget _buildHistorialCard(
    String estado,
    String fecha,
    int cantidadProductos,
    {required List<RecargasViewModel> recargasGrupo}
  ) {
    // Configuración de colores y gradientes según el estado
    Color primaryColor;
    Color secondaryColor;
    Color backgroundColor;
    IconData statusIcon;
    String label;
  
    switch (estado) {
      case 'En proceso':
      case 'Pendiente':
        label = 'En proceso';
        primaryColor = const Color.fromARGB(255, 206, 160, 8);
        secondaryColor = const Color.fromARGB(255, 228, 197, 69);
        backgroundColor = const Color(0xFFFFF4E6);
        statusIcon = Icons.schedule_rounded;
        break;
      case 'Aprobada':
        label = 'Aprobada';
        primaryColor = const Color(0xFF34C759);
        secondaryColor = const Color(0xFF4CD964);
        backgroundColor = const Color(0xFFE8F5E8);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Rechazada':
        label = 'Rechazada';
        primaryColor = const Color(0xFFFF3B30);
        secondaryColor = const Color(0xFFFF6B60);
        backgroundColor = const Color(0xFFFFE8E6);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        label = estado;
        primaryColor = const Color(0xFF8E8E93);
        secondaryColor = const Color(0xFFAEAEB2);
        backgroundColor = const Color(0xFFF2F2F7);
        statusIcon = Icons.help_outline_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => RecargaDetalleBottomSheet(recargasGrupo: recargasGrupo),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    backgroundColor.withOpacity(0.3),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Header con gradiente de estado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [primaryColor, secondaryColor],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Solicitud de recarga',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Fecha de solicitud
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha de solicitud',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fecha,
                                    style: const TextStyle(
                                      color: Color(0xFF181E34),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Cantidad de productos
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total productos',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$cantidadProductos productos solicitados',
                                    style: const TextStyle(
                                      color: Color(0xFF181E34),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
  // <- aquí termina correctamente el método

class RecargaBottomSheet extends StatefulWidget {
  const RecargaBottomSheet({super.key});

  @override
  State<RecargaBottomSheet> createState() => _RecargaBottomSheetState();
}

class _RecargaBottomSheetState extends State<RecargaBottomSheet> {
  final ProductosService _productosService = ProductosService();
  List<Productos> _productos = [];
  Map<int, int> _cantidades = {}; // prod_Id -> cantidad
  String search = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
  }

  Future<void> _fetchProductos() async {
    try {
      final productos = await _productosService.getProductos();
      setState(() {
        _productos = productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _productos.where((p) {
      final nombre = (p.prod_DescripcionCorta ?? '').toLowerCase();
      return nombre.contains(search.toLowerCase());
    }).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Solicitud de recarga',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar producto',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final producto = filtered[i];
                        final cantidad = _cantidades[producto.prod_Id] ?? 0;
                        return _buildProducto(producto, cantidad);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF141A2F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () async {
  // 1. Obtener usuario logueado
  final perfilService = PerfilUsuarioService();
  final userData = await perfilService.obtenerDatosUsuario();
  if (userData == null || userData['usua_Id'] == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo obtener el usuario logueado.")));
    }
    return;
  }
  final int usuaId = userData['usua_Id'] is String
      ? int.tryParse(userData['usua_Id']) ?? 0
      : userData['usua_Id'] ?? 0;
  if (usuaId == 0) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID de usuario inválido.")));
    }
    return;
  }

  // 2. Construir detalles
  final detalles = _cantidades.entries
      .where((e) => e.value > 0)
      .map((e) => {
            "prod_Id": e.key,
            "reDe_Cantidad": e.value,
            "reDe_Observaciones": "N/A",
          })
      .toList();
  if (detalles.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona al menos un producto.")));
    }
    return;
  }

  // 3. Llamar a RecargasService
  final recargaService = RecargasService();
  final ok = await recargaService.insertarRecarga(usuaCreacion: usuaId, detalles: detalles);
  if (mounted) {
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recarga enviada correctamente"), backgroundColor: Colors.green));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al enviar la recarga"), backgroundColor: Colors.red));
    }
  }
},
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  'Solicitar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducto(Productos producto, int cantidad) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: producto.prod_Imagen != null && producto.prod_Imagen!.isNotEmpty
                  ? Image.network(
                      producto.prod_Imagen!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 48),
                    )
                  : const Icon(Icons.image, size: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                producto.prod_DescripcionCorta ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: cantidad > 0
                      ? () {
                          setState(() {
                            _cantidades[producto.prod_Id] = cantidad - 1;
                          });
                        }
                      : null,
                ),
                Text(
                  '$cantidad',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() {
                      _cantidades[producto.prod_Id] = cantidad + 1;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
