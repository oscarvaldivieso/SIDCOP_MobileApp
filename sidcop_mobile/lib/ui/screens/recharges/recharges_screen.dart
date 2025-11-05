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
import 'dart:math';

class RechargesScreen extends StatefulWidget {
  const RechargesScreen({super.key});

  @override
  State<RechargesScreen> createState() => _RechargesScreenState();
}

class _RechargesScreenState extends State<RechargesScreen> {
  bool _verTodasLasRecargas = false;
  List<RecargasViewModel> _recargas = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canView = false;
  List<dynamic> permisos = [];
  String _errorMessage = '';
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadPermisos();
    _loadRecargas();
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none && !_isSyncing) {
        if (_lastSyncTime == null || 
            DateTime.now().difference(_lastSyncTime!).inSeconds >= 30) {
          await _sincronizarRecargasPendientes();
          _lastSyncTime = DateTime.now();
        }
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

  //se carga la lista de recargas
  Future<void> _loadRecargas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Verificar conectividad y carga offline en caso que no se disponga 
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final online = connectivityResult != ConnectivityResult.none;

      if (online) {
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

        final perfilService = PerfilUsuarioService();
        final userData = await perfilService.obtenerDatosUsuario();
        final personaId = userData?['personaId'] ?? userData?['usua_IdPersona'] ?? userData?['idPersona'];
        if (personaId == null) throw Exception('Persona ID no encontrado');

        final recargas = await RecargasService().getRecargas(
          personaId is int ? personaId : int.tryParse(personaId.toString()) ?? 0,
        );
        final recargasJson = recargas.map((r) => r.toJson()).toList();

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

  //abrir modal para nueva recarga o editar una ya existente
  void _openRecargaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RecargaBottomSheet(),
    ).then((value) {
      if (value == true) {
        setState(() {});
      }
    });
  }

  //sincroniza las recargas pendientes cuando se detecta que hay conexión
  Future<void> _sincronizarRecargasPendientes() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
      _isLoading = true;
    });

    try {
      final sincronizadas = await RecargasScreenOffline.sincronizarRecargasOffline();
      
      if (sincronizadas > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$sincronizadas recarga(s) sincronizada(s) exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadRecargas();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay recargas pendientes por sincronizar'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('Error en sincronización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar recargas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
        _isLoading = false;
      });
    }
  }

  //creación de la pantalla de recargas
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        title: 'Recarga',
        icon: Icons.sync,
        permisos: permisos,
        onRefresh: () async {
          await _loadRecargas();
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

                            if (agrupadas.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No hay recargas registradas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }

                            final keys = agrupadas.keys.toList()
                              ..sort((a, b) => b.compareTo(a));

                            final recargasAMostrar = _verTodasLasRecargas
                                ? keys
                                : keys.take(3).toList();

                            return Column(
                              children: recargasAMostrar.map((recaId) {
                                final recargasGrupo = agrupadas[recaId]!;
                                final recarga = recargasGrupo.first;
                                final cantidadProductos = recargasGrupo.fold(
                                  0,
                                  (sum, r) => sum +
                                      (int.tryParse(r.reDe_Cantidad.toString()) ?? 0),
                                );
                                return _buildHistorialCard(
                                  _mapEstadoFromApi(recarga.reca_Confirmacion),
                                  recarga.reca_Fecha != null
                                      ? _formatFechaFromApi(
                                          recarga.reca_Fecha.toString())
                                      : 'Fecha no disponible',
                                  cantidadProductos,
                                  recargasGrupo: recargasGrupo,
                                );
                              }).toList(),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF141A2F),
        onPressed: () async {
          _openRecargaModal();
        },
        child: const Icon(Icons.add, color: Colors.white),
        shape: const CircleBorder(),
        elevation: 4.0,
      ),
    );
  }

  // Mapeo del estado desde la API a una cadena legible
  String _mapEstadoFromApi(dynamic recaConfirmacion) {
    if (recaConfirmacion == "A") return 'Aprobada';
    if (recaConfirmacion == "R") return 'Rechazada';
    if(recaConfirmacion == "E") return 'Entregado';
    return 'En proceso';
  }

  // Formateo de la fecha desde la API a un formato legible
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

  // Conversión del número del mes a su nombre
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

  // Construcción de la tarjeta de historial de la recarga
  Widget _buildHistorialCard(
    String estado,
    String fecha,
    int cantidadProductos, {
    required List<RecargasViewModel> recargasGrupo,
  }) {
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
        primaryColor = const Color(0xFF141A2F);
        secondaryColor = const Color(0xFF2C3655);
        backgroundColor = const Color(0xFFE8EAF6);
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
                setState(() {});
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
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

//Funcion para determinar si se esta editando o creando una recarga
class RecargaBottomSheet extends StatefulWidget {
  final List<RecargasViewModel>? recargasGrupoParaEditar;
  final bool isEditMode;
  final int? recaId;
  final int? bode_IdU;
  
  const RecargaBottomSheet({
    super.key,
    this.recargasGrupoParaEditar,
    this.isEditMode = false,
    this.recaId,
    this.bode_IdU,
  });

  @override
  State<RecargaBottomSheet> createState() => _RecargaBottomSheetState();
}

//modal para crear o editar una recarga
class _RecargaBottomSheetState extends State<RecargaBottomSheet> {
  final ProductosService _productosService = ProductosService();
  List<Productos> _productos = [];
  Map<int, int> _cantidades = {};
  Map<int, TextEditingController> _controllers = {};
  String search = '';
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conexión restablecida.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    });
  }

  //sincroniza las recargas pendientes cuando se detecta que hay conexión
  Future<void> _sincronizarRecargasPendientes() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final online = connectivityResult != ConnectivityResult.none;
    if (!online) return;

    try {
      final pendientesRaw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
      if (pendientesRaw == null || pendientesRaw.isEmpty) return;

      final pendientes = List<Map<String, dynamic>>.from(pendientesRaw);
      final recargaService = RecargasService();

      int sincronizadas = 0;
      final recargasNoSincronizadas = <Map<String, dynamic>>[];

      for (final recarga in pendientes) {
        try {
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          final usuaId = recarga['usua_Id'];

          final success = await recargaService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );

          if (success) {
            sincronizadas++;
          } else {
            recargasNoSincronizadas.add(recarga);
          }
        } catch (e) {
          recargasNoSincronizadas.add(recarga);
          debugPrint('Error al sincronizar recarga: $e');
        }
      }

      await RecargasScreenOffline.guardarJson('recargas_pendientes.json', recargasNoSincronizadas);

      //mensaje de exito en caso se sincronice alguna recarga
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

  //carga los productos disponibles para crear una recarga
  //en caso no haya conexión, carga los productos guardados localmente
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
        try {
          final jsonList = productos.map((p) => p.toJson()).toList();
          await RecargasScreenOffline.guardarJson('productos.json', jsonList);
        } catch (_) {}
      } catch (e) {
        await _loadProductosOffline();
      }
    } else {
      await _loadProductosOffline();
    }
  }

  //cargar los productos desde el almacenamiento local
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
  
  //prellenar los datos en caso de estar editando una recarga
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

  //creación del widget para la creación o edición de una recarga
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
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
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  'Solicitar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  final perfilService = PerfilUsuarioService();
                  final userData = await perfilService.obtenerDatosUsuario();
                  //validacion de los datos del usuario
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
                    //validación para la cantidad de productos que se pueden solicitar
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
                  //validacion en caso quiera hacer una recarga sin seleccionar productos
                  if (detalles.isEmpty) {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Error"),
                            content: const Text("Debe seleccionar al menos un producto."),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    return;
                  }

                  bool online = true;
                  try {
                    final result = await InternetAddress.lookup('google.com');
                    online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
                  } catch (_) {
                    online = false;
                  }
                  bool ok = false;
                  //guardar la recarga de manera online en caso se tenga conexión
                  if (online) {
                    if(widget.isEditMode)
                    {
                      final recargaService = RecargasService();
                      ok = await recargaService.updateRecarga(
                        recaId: widget.recaId!,
                        usuaModificacion: usuaId,
                        detalles: detalles,
                      );
                    }
                    else
                    {
                      final recargaService = RecargasService();
                      ok = await recargaService.insertarRecarga(
                        usuaCreacion: usuaId,
                        detalles: detalles,
                      );
                    }
                  } else {
                    final recargaOffline = {
                      'id': DateTime.now().microsecondsSinceEpoch,
                      'usua_Id': usuaId,
                      'fecha': DateTime.now().toIso8601String(),
                      'offline': true,
                      'local_signature': '${DateTime.now().microsecondsSinceEpoch}_${usuaId}',
                      'detalles': detalles,
                    };
                    
                    //guardar la recarga de manera offline en caso no se tenga conexión
                    try {
                      final raw = await RecargasScreenOffline.leerJson('recargas_pendientes.json') ?? [];
                      final lista = List<Map<String, dynamic>>.from(raw as List);
                      lista.add(recargaOffline);
                      await RecargasScreenOffline.guardarJson('recargas_pendientes.json', lista);
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

                  //mensaje de exito o error al guardar la recarga
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
                        const SnackBar(
                          content: Text("Error al guardar la recarga."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  //creación del widget para cada producto en la lista de selección
  Widget _buildProducto(Productos producto, int cantidad) {
    if (!_controllers.containsKey(producto.prod_Id)) {
      final controller = TextEditingController(
        text: cantidad > 0 ? cantidad.toString() : '',
      );
      controller.addListener(() {
        final text = controller.text;
        final value = int.tryParse(text);
        if (value != null && value >= 0) {
          _cantidades[producto.prod_Id] = value;
        } else if (text.isEmpty) {
          _cantidades[producto.prod_Id] = 0;
        }
      });
      _controllers[producto.prod_Id] = controller;
    } else {
      final currentText = _controllers[producto.prod_Id]!.text;
      var text;
      if (cantidad > 0) {
        text = cantidad.toString();
      } else {
        text = '';
      }
      if (currentText != text) {
        _controllers[producto.prod_Id]!.text = text;
      }
    }

    //creación de las tarjedas donde se muestra cada producto
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 48),
                    )
                  : const Icon(Icons.image, size: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.prod_DescripcionCorta ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (producto.prod_Descripcion != null &&
                      producto.prod_Descripcion!.isNotEmpty)
                    Text(
                      producto.prod_Descripcion!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (cantidad > 0) {
                      setState(() {
                        _cantidades[producto.prod_Id] = cantidad - 1;
                        _controllers[producto.prod_Id]!.text = (cantidad - 1).toString();
                      });
                    }
                  },
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _controllers[producto.prod_Id],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    if (cantidad < 99) {
                      setState(() {
                        _cantidades[producto.prod_Id] = cantidad + 1;
                        _controllers[producto.prod_Id]!.text = (cantidad + 1).toString();
                      });
                    }
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
