import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/services/VendedoresService.dart';
import 'package:sidcop_mobile/models/vendedoresViewModel.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:http/http.dart' as http;
import 'Rutas_details.dart';
import 'Rutas_mapscreen.dart';
import 'Rutas_offline_mapscreen.dart';
import 'Rutas_descargas_screen.dart';
import 'package:sidcop_mobile/Offline_Services/Rutas_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';

class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key});
  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  bool isOnline =
      false; // Variable de clase para almacenar el estado de conexión

  Future<bool> verificarconexion() async {
    try {
      // Usar VerificarService.verificarConexion() en lugar de implementación directa
      isOnline = await VerificarService.verificarConexion();

      return isOnline;
    } catch (e) {
      isOnline = false;
      return false;
    }
  }

  // mapas static locales cache handled via archivos en getApplicationDocumentsDirectory()
  // Descarga y guarda la imagen de Google Maps Static
  Future<String?> guardarImagenDeMapaStatic(
    String imageUrl,
    String nombreArchivo,
  ) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$nombreArchivo.png';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        // write metadata to help verify saved images
        try {
          final metaPath = '${directory.path}/$nombreArchivo.url.txt';
          final metaFile = File(metaPath);
          await metaFile.writeAsString(
            'url:$imageUrl\nbytes:${response.bodyBytes.length}',
          );
        } catch (_) {}
        print('DEBUG: guardarImagenDeMapaStatic saved $filePath');
        return filePath;
      }
    } catch (e) {
      print('Error guardando imagen de mapa: $e');
    }
    return null;
  }

  // Obtiene la ruta local de la imagen static si existe

  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final RutasService _rutasService = RutasService();
  final TextEditingController _searchController = TextEditingController();
  List<Ruta> _rutas = [];
  List<Ruta> _filteredRutas = [];
  bool _isLoading = true;
  List<dynamic> permisos = [];
  Set<int> _rutasPermitidas = {}; // ids de rutas asignadas al vendedor
  final VendedoresService _vendedoresService = VendedoresService();
  bool _vendedorNoIdentificado = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);

    // Establecer isOnline = true por defecto para permitir intentos de conexión
    isOnline = true;

    // Inmediatamente establecer _isLoading en true para mostrar indicador de carga
    setState(() {
      _isLoading = true;
    });

    // On entering the Rutas screen we must persist all remote data locally
    // (rutas, clientes, direcciones, vendedores, visitas_historial, etc).
    // Run startup sync then load rutas. Use a microtask to avoid making
    // initState async and to keep UI responsive while we perform the
    // necessary persistence operations.
    Future.microtask(() async {
      try {
        // Intentar sincronización forzada - siempre intentamos sincronizar
        // todos los datos independientemente del estado de conexión previo
        print('DEBUG: Iniciando sincronización FORZADA en _initState');
        print('vendedor en rutas: $globalVendId');
        await _syncAllOnEntry();
        print('DEBUG: Sincronización FORZADA completada');
      } catch (e) {
        print('SYNC: forced full sync failed: $e');
        // Si falla la sincronización, asumimos que estamos offline
        isOnline = false;

        // Notificar al usuario sobre el error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al sincronizar datos: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      // Notificar que la sincronización se ha completado
      // No mostrar mensaje de éxito; dejamos solo el indicador de carga en la UI

      // After attempting to persist all data, load rutas for the UI.
      await _fetchRutas();
    });
  }

  Future<void> _syncAllOnEntry() async {
    try {
      print('SYNC: starting FORCED full startup sync...');

      // Verificar conexión para actualizar estado - solo para mostrar en logs
      await verificarconexion();
      print('DEBUG _syncAllOnEntry: Estado de conexión verificada: $isOnline');

      // IMPORTANTE: Ya no verificamos si estamos online,
      // siempre intentamos sincronizar para forzar actualización
      // de todos los datos incluyendo visitas

      print(
        'SYNC: Forzando sincronización completa independientemente del estado de conexión',
      );

      // Limpiar datos obsoletos antes de obtener nuevos datos
      await RutasScreenOffline.limpiarTodosLosDetalles();
      print('SYNC: limpiarTodosLosDetalles completed');

      // Sincronizar todos los datos en orden para asegurar consistencia
      await RutasScreenOffline.sincronizarRutas();
      print('SYNC: sincronizarRutas completed');

      await RutasScreenOffline.sincronizarClientes();
      print('SYNC: sincronizarClientes completed');

      await RutasScreenOffline.sincronizarDirecciones();
      print('SYNC: sincronizarDirecciones completed');

      await RutasScreenOffline.sincronizarVendedores();
      print('SYNC: sincronizarVendedores completed');

      // Forzar actualización de visitas historial (lo más importante)
      await RutasScreenOffline.sincronizarVisitasHistorial();
      print('SYNC: sincronizarVisitasHistorial FORCED completed');

      await RutasScreenOffline.sincronizarVendedoresPorRutas();
      print('SYNC: sincronizarVendedoresPorRutas completed');

      // Regenerar los detalles de rutas con los datos actualizados
      await RutasScreenOffline.guardarDetallesTodasRutas(forzar: true);
      print('SYNC: guardarDetallesTodasRutas completed with force=true');

      print('SYNC: forced full startup sync completed successfully!');

      // Si llegamos aquí, la sincronización tuvo éxito, actualizar estado online
      isOnline = true;
    } catch (e) {
      print('SYNC: _syncAllOnEntry forced sync encountered error: $e');
      // No volver a lanzar el error para que el flujo continúe
      isOnline = false; // Si hay error, asumimos que estamos offline
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRutas() async {
    try {
      // 1. Obtener rutas asignadas al vendedor (si existe variable global)
      await _cargarRutasAsignadasVendedor();

      // 2. Obtener todas las rutas
      final rutasJson = await _rutasService.getRutas();
      final rutasList = rutasJson
          .map<Ruta>((json) => Ruta.fromJson(json))
          .toList();

      // 3. Filtrar si hay rutas permitidas (si _rutasPermitidas vacío, muestra todas)
      final List<Ruta> rutasFiltradas = _rutasPermitidas.isEmpty
          ? rutasList
          : rutasList
                .where((r) => _rutasPermitidas.contains(r.ruta_Id))
                .toList();
      setState(() {
        _rutas = rutasFiltradas;
        _filteredRutas = List.from(rutasFiltradas);
        _isLoading = false;
      });
      // Guardar rutas encriptadas offline
      await _guardarRutasOffline(_rutas);
      // Lanzar sincronización en background para asegurar que las ubicaciones
      // de clientes y direcciones se persistan al entrar al listado de rutas.
      // Intentamos sincronizar clientes/direcciones primero (guardan JSON local)
      // y luego generamos los detalles por ruta. Errores se registran pero no
      // bloquean la UI.
      Future.microtask(() async {
        try {
          await RutasScreenOffline.sincronizarClientes();
          await RutasScreenOffline.sincronizarDirecciones();
        } catch (e) {
          print('SYNC: warning - sincronizar clientes/direcciones failed: $e');
        }
        try {
          await RutasScreenOffline.guardarDetallesTodasRutas();
          print('SYNC: guardarDetallesTodasRutas completed');
        } catch (e) {
          print('SYNC: guardarDetallesTodasRutas failed: $e');
        }
      });
    } catch (e) {
      // Si falla, intentar leer rutas offline
      final rutasOffline = await _leerRutasOffline();
      if (mounted) {
        setState(() {
          _rutas = rutasOffline;
          _filteredRutas = List.from(rutasOffline);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mostrando rutas sin conexión a Internet.')),
        );
      }
    }
  }

  // Guarda la lista de rutas encriptada
  Future<void> _guardarRutasOffline(List<Ruta> rutas) async {
    final rutasJson = rutas.map((r) => r.toJson()).toList();
    await secureStorage.write(
      key: 'rutas_offline',
      value: jsonEncode(rutasJson),
    );
  }

  // Lee la lista de rutas encriptada
  Future<List<Ruta>> _leerRutasOffline() async {
    try {
      final rutasString = await secureStorage.read(key: 'rutas_offline');
      print('DEBUG rutas_offline (offline): $rutasString');
      if (rutasString != null) {
        final rutasList = jsonDecode(rutasString) as List;
        return rutasList.map((json) => Ruta.fromJson(json)).toList();
      }
    } catch (e) {
      print('DEBUG: error leyendo rutas_offline key: $e');
    }

    // Fallback: intentar leer el JSON gestionado por RutasScreenOffline ('rutas.json')
    try {
      final raw = await RutasScreenOffline.leerJson('rutas.json');
      print('DEBUG rutas.json (offline service): $raw');
      if (raw == null) return [];
      final lista = List.from(raw as List);
      return lista.map((json) => Ruta.fromJson(json)).toList();
    } catch (e) {
      print('DEBUG: error leyendo rutas.json desde RutasScreenOffline: $e');
    }

    return [];
  }

  Future<void> _cargarRutasAsignadasVendedor() async {
    // Usa globalUsuaIdPersona como vend_Id
    final int? vendId = globalVendId;
    if (vendId == null) {
      _vendedorNoIdentificado = true;
      return; // no hay vendedor,
    }
    try {
      final lista = await _vendedoresService.listar();
      final vendedor = lista.firstWhere(
        (v) => v.vend_Id == vendId,
        orElse: () => VendedoresViewModel(
          vend_Id: -1,
          vend_Codigo: null,
          vend_DNI: null,
          vend_Nombres: null,
          vend_Apellidos: null,
          vend_Telefono: null,
          vend_Correo: null,
          vend_Sexo: null,
          vend_DireccionExacta: null,
          sucu_Id: 0,
          colo_Id: 0,
          vend_Supervisor: null,
          vend_Ayudante: null,
          vend_Tipo: null,
          vend_EsExterno: null,
          vend_Estado: false,
          usua_Creacion: 0,
          vend_FechaCreacion: DateTime.fromMillisecondsSinceEpoch(0),
          usua_Modificacion: null,
          vend_FechaModificacion: null,
          sucu_Descripcion: null,
          sucu_DireccionExacta: null,
          colo_Descripcion: null,
          muni_Codigo: null,
          muni_Descripcion: null,
          depa_Codigo: null,
          depa_Descripcion: null,
          nombreSupervisor: null,
          apellidoSupervisor: null,
          nombreAyudante: null,
          apellidoAyudante: null,
          usuarioCreacion: null,
          usuarioModificacion: null,
          rutas: null,
          rutas_Json: const [],
        ),
      );
      if (vendedor.vend_Id == -1) {
        _vendedorNoIdentificado = true; // no encontrado
        return;
      }
      // Parsear campo rutas (string JSON con estructura [{"id":2,"dias":"1"}, ...])
      final rutasStr = vendedor.rutas;
      if (rutasStr == null || rutasStr.isEmpty) return;
      final dynamic dec = jsonDecode(rutasStr);
      if (dec is List) {
        final ids = dec
            .whereType<Map>()
            .map((m) => m['id'])
            .where((v) => v is int || v is num || v is String)
            .map<int?>((v) {
              if (v is int) return v;
              if (v is num) return v.toInt();
              if (v is String) return int.tryParse(v);
              return null;
            })
            .whereType<int>()
            .toSet();
        if (ids.isNotEmpty) {
          _rutasPermitidas = ids;
        }
      }
    } catch (_) {
      // Silencioso, en caso de error no se filtra
    }
  }

  void _applySearch() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredRutas = _rutas.where((ruta) {
        final desc = ruta.ruta_Descripcion?.toLowerCase() ?? '';
        final cod = ruta.ruta_Codigo?.toString().toLowerCase() ?? '';
        return searchTerm.isEmpty ||
            desc.contains(searchTerm) ||
            cod.contains(searchTerm);
      }).toList();
    });
  }

  Future<String> _getStaticMapMarkers(Ruta ruta) async {
    final clientesService = ClientesService();
    final direccionesService = DireccionClienteService();
    final clientesJson = await clientesService.getClientes();
    final clientes = clientesJson
        .map<Cliente>((j) => Cliente.fromJson(j))
        .toList();
    final clientesFiltrados = clientes
        .where((c) => c.ruta_Id == ruta.ruta_Id)
        .toList();
    final todasDirecciones = await direccionesService
        .getDireccionesPorCliente();
    final clienteIds = clientesFiltrados
        .map((c) => c.clie_Id)
        .whereType<int>()
        .toSet();
    final direccionesFiltradas = todasDirecciones
        .where((d) => clienteIds.contains(d.clie_id))
        .toList();
    // Usar URL remota para el icono marker
    const iconUrl =
        'http://200.59.27.115/Honduras_map/static_marker_cjmmpj.png';
    final markers = direccionesFiltradas
        .where((d) => d.dicl_latitud != null && d.dicl_longitud != null)
        .map(
          (d) => 'markers=icon:$iconUrl%7C${d.dicl_latitud},${d.dicl_longitud}',
        )
        .join('&');
    final visiblePoints = direccionesFiltradas
        .where((d) => d.dicl_latitud != null && d.dicl_longitud != null)
        .map((d) => '${d.dicl_latitud},${d.dicl_longitud}')
        .join('|');
    // El parámetro visible fuerza a que todos los puntos estén en la imagen
    return 'https://maps.googleapis.com/maps/api/staticmap?size=400x150&$markers&visible=$visiblePoints&key=$mapApikey';
  }

  // Preferir siempre generar URL remota; usar local solo si offline
  Future<String> _getMapUrlPreferLocal(Ruta ruta) async {
    try {
      print('DEBUG: Obteniendo mapa para ruta ${ruta.ruta_Id}');

      // Verificar si hay imagen local primero (para tenerla como backup)
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/map_static_${ruta.ruta_Id}.png';
      final file = File(filePath);
      final hasLocalImage = await file.exists();

      // Verificar conexión usando VerificarService
      isOnline = await verificarconexion();
      print('DEBUG: Estado de conexión para ruta ${ruta.ruta_Id}: $isOnline');

      // Si estamos online, generar nueva imagen remota
      if (isOnline) {
        try {
          final remote = await _getStaticMapMarkers(ruta);
          print(
            'DEBUG: Generando nueva imagen remota para ruta ${ruta.ruta_Id}: $remote',
          );

          // Guardar para uso offline futuro
          guardarImagenDeMapaStatic(remote, 'map_static_${ruta.ruta_Id}');

          return remote;
        } catch (remoteError) {
          print('ERROR obteniendo imagen remota: $remoteError');

          // Si hay error obteniendo imagen remota pero tenemos local, usar local
          if (hasLocalImage) {
            print(
              'DEBUG: Error con imagen remota, usando local para ruta ${ruta.ruta_Id}',
            );
            return 'file://$filePath';
          }
          // No hay imagen local y falló la generación remota
          throw 'No se pudo generar imagen remota y no hay local disponible';
        }
      } else {
        // Estamos offline, verificar si hay imagen local disponible
        if (hasLocalImage) {
          print(
            'DEBUG: Offline, usando imagen local para ruta ${ruta.ruta_Id}',
          );
          return 'file://$filePath';
        }
        print('DEBUG: Offline y sin imagen local para ruta ${ruta.ruta_Id}');
        throw 'Offline y sin imagen local disponible';
      }
    } catch (e) {
      print('ERROR general en _getMapUrlPreferLocal: $e');
      // Retornar 'placeholder' en caso de error
      return 'placeholder';
    }
  }

  @override
  Widget build(BuildContext context) {
    // fallback use for map API key is available as mapApikey
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: CustomDrawer(permisos: permisos),
      body: AppBackground(
        title: 'Rutas',
        icon: Icons.map,
        onRefresh: () async {
          await _fetchRutas();
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD6B68A)),
                ),
              )
            : _vendedorNoIdentificado
            ? const Center(
                child: Text(
                  'El vendedor no ha sido identificado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141A2F),
                  ),
                ),
              )
            : _rutas.isEmpty
            ? const Center(child: Text('No hay rutas'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Buscar rutas:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar rutas...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF141A2F),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            borderSide: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF141A2F),
                              width: 2,
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Lista de rutas:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._filteredRutas.map(
                      (ruta) => FutureBuilder<String>(
                        future: _getMapUrlPreferLocal(ruta),
                        builder: (context, snapshot) {
                          // Siempre mostrar un resultado, incluso si está esperando
                          final mapUrl = snapshot.data ?? '';
                          print(
                            'DEBUG FutureBuilder ruta ${ruta.ruta_Id} mapUrl=$mapUrl state=${snapshot.connectionState} hasData=${snapshot.hasData}',
                          );

                          // Si todavía está cargando, mostrar placeholder inmediatamente
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildRutaCard(
                              ruta: ruta,
                              imageWidget: _buildPlaceholderImage(),
                              context: context,
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            // Si es local, mapUrl empieza con file://
                            if (mapUrl.startsWith('file://')) {
                              final localPath = mapUrl.replaceFirst(
                                'file://',
                                '',
                              );
                              print(
                                'DEBUG mostrando imagen local para ruta ${ruta.ruta_Id} -> $localPath',
                              );

                              // Crear widget de imagen de archivo
                              Widget imageWidget = Image.file(
                                File(localPath),
                                height: 120,
                                width: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('ERROR cargando imagen local: $error');
                                  return _buildPlaceholderImage();
                                },
                              );

                              return _buildRutaCard(
                                ruta: ruta,
                                imageWidget: imageWidget,
                                context: context,
                              );
                            }

                            // Si no es local, puede ser un URL remoto
                            if (mapUrl.startsWith('http')) {
                              print(
                                'DEBUG mostrando imagen remota para ruta ${ruta.ruta_Id}',
                              );

                              // Cachear en background
                              guardarImagenDeMapaStatic(
                                mapUrl,
                                'map_static_${ruta.ruta_Id}',
                              );

                              // Crear widget de imagen de red
                              Widget imageWidget = Image.network(
                                mapUrl,
                                height: 120,
                                width: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('ERROR cargando imagen remota: $error');
                                  return _buildPlaceholderImage();
                                },
                              );

                              return _buildRutaCard(
                                ruta: ruta,
                                imageWidget: imageWidget,
                                context: context,
                              );
                            }

                            // Si mapUrl es placeholder u otro valor
                            if (mapUrl == 'placeholder' || mapUrl.isEmpty) {
                              print(
                                'DEBUG usando placeholder para ruta ${ruta.ruta_Id}',
                              );
                              return _buildRutaCard(
                                ruta: ruta,
                                imageWidget: _buildPlaceholderImage(),
                                context: context,
                              );
                            }
                            // Si llegamos aquí o es placeholder, mostrar placeholder
                            return _buildRutaCard(
                              ruta: ruta,
                              imageWidget: _buildPlaceholderImage(),
                              context: context,
                            );
                          }

                          // Fallback por si acaso
                          return _buildRutaCard(
                            ruta: ruta,
                            imageWidget: _buildPlaceholderImage(),
                            context: context,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF141A2F),
        foregroundColor: const Color(0xFFD6B68A),
        tooltip: 'Descargas - Mapas Offline',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RutasDescargasScreen()),
          );
        },
        child: const Icon(Icons.download),
      ),
    );
  }

  // Método para construir un widget de imagen placeholder
  Widget _buildPlaceholderImage() {
    return Container(
      height: 120,
      width: 140,
      color: Colors.grey[300],
      child: const Icon(Icons.map, size: 40, color: Colors.grey),
    );
  }

  // Método para construir la tarjeta de ruta completa
  Widget _buildRutaCard({
    required Ruta ruta,
    required Widget imageWidget,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Card(
        color: const Color(0xFF141A2F),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD6B68A), width: 1),
        ),
        elevation: 4,
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                await verificarconexion();
                if (isOnline) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RutaMapScreen(
                        rutaId: ruta.ruta_Id,
                        descripcion: ruta.ruta_Descripcion,
                        vendId: globalVendId,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RutasOfflineMapScreen(
                        rutaId: ruta.ruta_Id,
                        descripcion: ruta.ruta_Descripcion,
                      ),
                    ),
                  );
                }
              },
              child: Card(
                color: const Color(0xFFF5F5F5),
                margin: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                elevation: 2,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: imageWidget,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ruta.ruta_Descripcion ?? 'Sin descripción',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código: ${(ruta.ruta_Codigo ?? "-").toString()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB5B5B5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Observaciones: ${(ruta.ruta_Observaciones ?? "-").toString()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RutasDetailsScreen(ruta: ruta),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: Icon(
                  Icons.chevron_right,
                  color: Color(0xFFD6B68A),
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
