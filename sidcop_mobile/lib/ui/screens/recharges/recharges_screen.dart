import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart';
import 'package:sidcop_mobile/services/RecargasService.Dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/ui/screens/recharges/recarga_detalle_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:sidcop_mobile/Offline_Services/Recargas_OfflineService.dart';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class RechargesScreen extends StatefulWidget {
  const RechargesScreen({super.key});

  @override
  State<RechargesScreen> createState() => _RechargesScreenState();
}

class _RechargesScreenState extends State<RechargesScreen> {
  bool _verTodasLasRecargas = false;
  List<RecargasViewModel> _recargas = [];
  bool _isLoading = true;
  List<dynamic> permisos = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPermisos();
    _loadRecargas();
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await _sincronizarRecargasPendientes();
      }
    });
  }

  Future<void> _loadPermisos() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    if (userData != null &&
        (userData['PermisosJson'] != null ||
            userData['permisosJson'] != null)) {
      try {
        final permisosJson =
            userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }

  Future<void> _loadRecargas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final online = connectivityResult != ConnectivityResult.none;

      if (online) {
        // Sincronizar datos maestros
        await RecargasScreenOffline.sincronizarClientes();
        await RecargasScreenOffline.sincronizarDirecciones();

        // Intentar enviar recargas pendientes
        final pendientesEnviadas = await RecargasScreenOffline.sincronizarPendientes();
        if (mounted && pendientesEnviadas > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$pendientesEnviadas recarga(s) sincronizada(s) con éxito'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Cargar recargas remotas
        final perfilService = PerfilUsuarioService();
        final userData = await perfilService.obtenerDatosUsuario();
        final personaId = userData?['personaId'] ?? userData?['usua_IdPersona'] ?? userData?['idPersona'];
        if (personaId == null) throw Exception('Persona ID no encontrado');

        final recargas = await RecargasService().getRecargas(
          personaId is int ? personaId : int.tryParse(personaId.toString()) ?? 0,
        );
        final recargasJson = recargas.map((r) => r.toJson()).toList();

        // Fusionar con recargas locales pendientes
        final localRaw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
        final pendientes = localRaw?.where((e) => e['offline'] == true).toList() ?? [];

        for (final p in pendientes) {
          if (!recargasJson.any((r) => r['local_signature'] == p['local_signature'])) {
            recargasJson.add(p);
          }
        }

        await RecargasScreenOffline.guardarJson('recargas.json', recargasJson);

        setState(() {
          _recargas = recargasJson.map((r) => RecargasViewModel.fromJson(r)).toList();
          _isLoading = false;
        });
      } else {
        // Cargar recargas locales en modo offline
        final raw = await RecargasScreenOffline.leerJson('recargas.json');
        if (raw != null) {
          setState(() {
            _recargas = List<Map<String, dynamic>>.from(raw)
                .map((r) => RecargasViewModel.fromJson(r))
                .toList();
            _isLoading = false;
          });
        } else {
          throw Exception('No se encontraron datos locales');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar las recargas: ${e.toString()}';
        _isLoading = false;
      });
    }
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

  Future<void> _sincronizarRecargasPendientes() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final online = connectivityResult != ConnectivityResult.none;
    if (!online) return;

    try {
      // Leer recargas pendientes desde el almacenamiento local
      final pendientesRaw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
      if (pendientesRaw == null || pendientesRaw.isEmpty) return;

      final pendientes = List<Map<String, dynamic>>.from(pendientesRaw);
      final recargaService = RecargasService();

      int sincronizadas = 0;

      for (final recarga in pendientes) {
        try {
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          final usuaId = recarga['usua_Id'];

          // Intentar enviar la recarga al servidor
          final success = await recargaService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );

          if (success) {
            sincronizadas++;
          } else {
            throw Exception('Error al sincronizar recarga');
          }
        } catch (e) {
          // Si falla una recarga, continuar con las demás
          debugPrint('Error al sincronizar recarga: $e');
        }
      }

      // Actualizar el archivo local eliminando las recargas sincronizadas
      if (sincronizadas > 0) {
        final pendientesRestantes = pendientes.skip(sincronizadas).toList();
        await RecargasScreenOffline.guardarJson('recargas_pendientes.json', pendientesRestantes);
      }

      if (mounted && sincronizadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sincronizadas recarga(s) sincronizada(s) con éxito'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al sincronizar recargas pendientes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Recarga',
      icon: Icons.sync,
      permisos: permisos,
      onRefresh: () async {
        setState(() {});
      },
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
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        final Map<int, List<RecargasViewModel>> agrupadas = {};
                        for (final r in _recargas) {
                          if (r.reca_Id != null) {
                            agrupadas.putIfAbsent(r.reca_Id!, () => []).add(r);
                          }
                        }
                        final entriesList = agrupadas.entries.toList();
                        final mostrarTodas = _verTodasLasRecargas;
                        final itemsToShow = mostrarTodas
                            ? entriesList
                            : entriesList.take(3).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (agrupadas.isEmpty)
                              const Center(child: Text('No hay recargas.'))
                            else
                              Column(
                                children: itemsToShow.map((entry) {
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
                              ),
                            ),
                            const SizedBox(height: 15),
                            GestureDetector(
                              onTap: _openRecargaModal,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141A2F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Abrir recarga',
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
                          ],
                        );
                      },
                    ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      fontFamily: 'Satoshi',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _mapEstadoFromApi(dynamic recaConfirmacion) {
    if (recaConfirmacion == "A") return 'Aprobada';
    if (recaConfirmacion == "R") return 'Rechazada';
    if(recaConfirmacion == "E") return 'Entregado';
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
    int cantidadProductos, {
    required List<RecargasViewModel> recargasGrupo,
  }) {
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
      case 'Entregado':
        label = 'Entregado';
        primaryColor = const Color(0xFF141A2F); // Azul oscuro principal del sistema
        secondaryColor = const Color(0xFF2C3655); // Tono ligeramente más claro para el degradado
        backgroundColor = const Color(0xFFE8EAF6); // Fondo azul muy claro
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
            builder: (context) => RecargaDetalleBottomSheet(
              recargasGrupo: recargasGrupo,
              onRecargaUpdated: () {
                print('🔍 DEBUG: Callback ejecutado - refrescando lista');
                setState(() {}); // Refresca la lista de recargas
              },
            ),
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
                  colors: [Colors.white, backgroundColor.withOpacity(0.3)],
                ),
              ),
              child: Column(
                children: [
                  // Header con gradiente de estado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
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
// aquí termina correctamente el método

class RecargaBottomSheet extends StatefulWidget {
  final List<RecargasViewModel>? recargasGrupoParaEditar;
  final bool isEditMode;
  
  const RecargaBottomSheet({
    super.key,
    this.recargasGrupoParaEditar,
    this.isEditMode = false,
  });

  @override
  State<RecargaBottomSheet> createState() => _RecargaBottomSheetState();
}

class _RecargaBottomSheetState extends State<RecargaBottomSheet> {
  final ProductosService _productosService = ProductosService();
  List<Productos> _productos = [];
  Map<int, int> _cantidades = {}; // prod_Id -> cantidad
  Map<int, TextEditingController> _controllers = {}; // prod_Id -> controller
  String search = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
    _sincronizarRecargasPendientes();
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await _sincronizarRecargasPendientes();
      }
    });
  }

  Future<void> _sincronizarRecargasPendientes() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final online = connectivityResult != ConnectivityResult.none;
    if (!online) return;

    try {
      // Leer recargas pendientes desde el almacenamiento local
      final pendientesRaw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
      if (pendientesRaw == null || pendientesRaw.isEmpty) return;

      final pendientes = List<Map<String, dynamic>>.from(pendientesRaw);
      final recargaService = RecargasService();

      int sincronizadas = 0;

      for (final recarga in pendientes) {
        try {
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          final usuaId = recarga['usua_Id'];

          // Intentar enviar la recarga al servidor
          final success = await recargaService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );

          if (success) {
            sincronizadas++;
          } else {
            throw Exception('Error al sincronizar recarga');
          }
        } catch (e) {
          // Si falla una recarga, continuar con las demás
          debugPrint('Error al sincronizar recarga: $e');
        }
      }

      // Actualizar el archivo local eliminando las recargas sincronizadas
      if (sincronizadas > 0) {
        final pendientesRestantes = pendientes.skip(sincronizadas).toList();
        await RecargasScreenOffline.guardarJson('recargas_pendientes.json', pendientesRestantes);
      }

      if (mounted && sincronizadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sincronizadas recarga(s) sincronizada(s) con éxito'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al sincronizar recargas pendientes: $e');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchProductos() async {
    bool online = true;
    try {
      final result = await InternetAddress.lookup('google.com');
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }
    if (online) {
      try {
        final productos = await _productosService.getProductos();
        setState(() {
          _productos = productos;
          _isLoading = false;
          if (widget.isEditMode && widget.recargasGrupoParaEditar != null) {
            _preFillEditData();
          }
        });
        // Guardar productos offline
        try {
          final jsonList = productos.map((p) => p.toJson()).toList();
          await RecargasScreenOffline.guardarJson('productos.json', jsonList);
        } catch (_) {}
      } catch (e) {
        // Si falla online, intentar cargar productos offline
        await _loadProductosOffline();
      }
    } else {
      await _loadProductosOffline();
    }
  }

  Future<void> _loadProductosOffline() async {
    try {
      final raw = await RecargasScreenOffline.leerJson('productos.json');
      if (raw != null) {
        final lista = List.from(raw as List);
        setState(() {
          _productos = lista.map((json) => Productos.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _productos = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _productos = [];
        _isLoading = false;
      });
    }
  }
  
  void _preFillEditData() {
    if (widget.recargasGrupoParaEditar == null) return;
    
    for (final recarga in widget.recargasGrupoParaEditar!) {
      if (recarga.prod_Id != null && recarga.reDe_Cantidad != null) {
        final prodId = recarga.prod_Id!;
        final cantidad = recarga.reDe_Cantidad is int 
            ? recarga.reDe_Cantidad as int
            : int.tryParse(recarga.reDe_Cantidad.toString()) ?? 0;
        
        if (cantidad > 0) {
          _cantidades[prodId] = cantidad;
          // Create controller with listener
          final controller = TextEditingController(text: cantidad.toString());
          controller.addListener(() {
            final text = controller.text;
            final value = int.tryParse(text);
            if (value != null && value >= 0 ) {
              _cantidades[prodId] = value;
            } else if (text.isEmpty) {
              _cantidades[prodId] = 0;
            }
          });
          _controllers[prodId] = controller;
        }
      }
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
                  Text(
                    widget.isEditMode ? 'Editar recarga' : 'Solicitud de recarga',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "No se pudo obtener el usuario logueado.",
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  final int usuaId = userData['usua_Id'] is String
                      ? int.tryParse(userData['usua_Id']) ?? 0
                      : userData['usua_Id'] ?? 0;
                  if (usuaId == 0) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("usuario inválido."),
                        ),
                      );
                    }
                    return;
                  }

                  // 2. Construir detalles
                  final detalles = _cantidades.entries
                      .where((e) => e.value > 0)
                      .map(
                        (e) => {
                          "prod_Id": e.key,
                          "reDe_Cantidad": e.value,
                          "reDe_Observaciones": "N/A",
                        },
                      )
                      .toList();
                     
                  for(var detalle in detalles)
                  {
                    if(int.tryParse(detalle['reDe_Cantidad'].toString())! > 99)
                    {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("La cantidad máxima es 99."),
                        ),
                      );
                      return;
                    }
                  }
                  if (detalles.isEmpty) {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Alerta!'),
                            content: const Text('Selecciona al menos un producto.'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Dismiss the dialog
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        }
                      );
                    }
                    return;
                  }

                  // 3. Verificar conectividad
                  bool online = true;
                  try {
                    final result = await InternetAddress.lookup('google.com');
                    online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
                  } catch (_) {
                    online = false;
                  }
                  bool ok = false;
                  if (online) {
                    // 4. Llamar a RecargasService
                    final recargaService = RecargasService();
                    ok = await recargaService.insertarRecarga(
                      usuaCreacion: usuaId,
                      detalles: detalles,
                    );
                  } else {
                    // Guardar recarga offline para sincronizar después
                    final recargaOffline = {
                      'usua_Id': usuaId,
                      'detalles': detalles,
                      'fecha': DateTime.now().toIso8601String(),
                      'offline': true,
                    };
                    try {
                      final raw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
                      List<dynamic> pendientes = raw != null ? List.from(raw as List) : [];
                      pendientes.add(recargaOffline);
                      await RecargasScreenOffline.guardarJson('recargas_pendientes.json', pendientes);
                      ok = true;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recarga guardada en modo offline'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } catch (e) {
                      ok = false;
                    }
                  }

                  // 4. Intentar sincronizar pendientes si hay conexión
                  await _sincronizarRecargasPendientes();

                  if (mounted) {
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(online
                              ? "Recarga enviada correctamente"
                              : "Recarga guardada en modo offline. Se enviará cuando haya conexión."),
                          backgroundColor: online ? Colors.green : Colors.orange,
                        ),
                      );
                      Navigator.of(context).pop(true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(online
                              ? "Error al enviar la recarga"
                              : "Error al guardar la recarga offline"),
                          backgroundColor: Colors.red,
                        ),
                      );
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
    // Inicializa el controlador si no existe
    if (!_controllers.containsKey(producto.prod_Id)) {
      final controller = TextEditingController(
        text: cantidad > 0 ? cantidad.toString() : '',
      );
      controller.addListener(() {
        final text = controller.text;
        final value = int.tryParse(text);
        if (value != null && value >= 0 ) {
          setState(() {
            _cantidades[producto.prod_Id] = value;
          });
        } else if (text.isEmpty) {
          setState(() {
            _cantidades[producto.prod_Id] = 0;
          });
        }
      });
      _controllers[producto.prod_Id] = controller;
    } else {
      // Si la cantidad cambia por botones, actualiza el texto
      final currentText = _controllers[producto.prod_Id]!.text;
      var text;

      if (cantidad > 0) {
        text = cantidad.toString();
      }
      else
      {
        text = '';
      }

      if (cantidad < 99) {
       text = cantidad.toString();
      }
      else
      {
        text = '99';
      }

      if (currentText != text) {
        _controllers[producto.prod_Id]!.text = text;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  producto.prod_Imagen != null &&
                      producto.prod_Imagen!.isNotEmpty
                  ? Image.network(
                      producto.prod_Imagen!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 48),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: cantidad > 0
                      ? () {
                          final newValue = cantidad - 1;
                          _controllers[producto.prod_Id]?.text = newValue > 0
                              ? newValue.toString()
                              : '';
                          setState(() {
                            _cantidades[producto.prod_Id] = newValue > 0
                                ? newValue
                                : 0;
                          });
                        }
                      : null,
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _controllers[producto.prod_Id],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: cantidad < 99
                  ? () {
                    final newValue = cantidad + 1;  
                    _controllers[producto.prod_Id]?.text = newValue.toString();
                    setState(() {
                      _cantidades[producto.prod_Id] = newValue;
                    });
                  }
                  : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
