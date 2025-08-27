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
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:http/http.dart' as http;
import 'Rutas_details.dart';
import 'Rutas_mapscreen.dart';
import 'Rutas_offline_mapscreen.dart';
import 'Rutas_descargas_screen.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';

class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key});
  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  bool isOnline = true;

  Future<void> verificarConexion() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      if (response.statusCode == 200) {
        isOnline = true;
      } else {
        isOnline = false;
      }
    } catch (e) {
      isOnline = false;
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
        return filePath;
      }
    } catch (e) {
      print('Error guardando imagen de mapa: $e');
    }
    return null;
  }

  // Obtiene la ruta local de la imagen static si existe
  Future<String?> obtenerImagenLocalStatic(int rutaId) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/map_static_$rutaId.png';
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  // Comprueba si existen tiles locales para un departamento (slug de descripcion)
  Future<bool> _departmentTilesExist(String descripcion) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mapsDir = Directory('${directory.path}/maps');
      if (!await mapsDir.exists()) return false;

      String slug(String s) =>
          s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').trim();

      final candidate = Directory('${mapsDir.path}/${slug(descripcion)}');
      if (!await candidate.exists()) return false;

      try {
        final hasPng = await candidate
            .list(recursive: true)
            .any((f) => f is File && f.path.toLowerCase().endsWith('.png'));
        return hasPng;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

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
    _fetchRutas();
    _searchController.addListener(_applySearch);
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
          SnackBar(
            content: Text(
              'Error al cargar las rutas. Mostrando rutas precargadas.',
            ),
          ),
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
    final rutasString = await secureStorage.read(key: 'rutas_offline');
    print('DEBUG rutas_offline (offline): $rutasString');
    if (rutasString == null) return [];
    final rutasList = jsonDecode(rutasString) as List;
    return rutasList.map((json) => Ruta.fromJson(json)).toList();
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
    const iconUrl =
        'https://res.cloudinary.com/dbt7mxrwk/image/upload/v1755185408/static_marker_cjmmpj.png';
    final markers = direccionesFiltradas
        .map(
          (d) => 'markers=icon:$iconUrl%7C${d.dicl_latitud},${d.dicl_longitud}',
        )
        .join('&');
    String center;
    if (direccionesFiltradas.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      int count = 0;
      for (var d in direccionesFiltradas) {
        if (d.dicl_latitud != null && d.dicl_longitud != null) {
          sumLat += double.tryParse(d.dicl_latitud.toString()) ?? 0;
          sumLng += double.tryParse(d.dicl_longitud.toString()) ?? 0;
          count++;
        }
      }
      if (count > 0) {
        double avgLat = sumLat / count;
        double avgLng = sumLng / count;
        center = '$avgLat,$avgLng';
      } else {
        center = '15.525585,-88.013512';
      }
    } else {
      center = '15.525585,-88.013512';
    }
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=10&size=400x150&$markers&key=$mapApikey';
  }

  // Preferir imagen local si existe; si no, generar URL remota
  Future<String> _getMapUrlPreferLocal(Ruta ruta) async {
    try {
      final local = await obtenerImagenLocalStatic(ruta.ruta_Id);
      if (local != null) {
        print('DEBUG: Usando imagen local para ruta ${ruta.ruta_Id}: $local');
        return 'file://$local';
      }
      final remote = await _getStaticMapMarkers(ruta);
      print(
        'DEBUG: No hay imagen local para ruta ${ruta.ruta_Id}, usando remote: $remote',
      );
      return remote;
    } catch (e) {
      print('DEBUG: Error obteniendo mapa para ruta ${ruta.ruta_Id}: $e');
      return '';
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
            ? const Center(child: CircularProgressIndicator())
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
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CustomButton(
                          text: 'Mapas Offline',
                          width: 180,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RutasDescargasScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
                          final mapUrl = snapshot.data ?? '';
                          print(
                            'DEBUG FutureBuilder ruta ${ruta.ruta_Id} mapUrl=$mapUrl state=${snapshot.connectionState} hasData=${snapshot.hasData}',
                          );
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            // Si es local, mapUrl empieza con file://
                            if (mapUrl.startsWith('file://')) {
                              final localPath = mapUrl.replaceFirst(
                                'file://',
                                '',
                              );
                              print(
                                'DEBUG mostrando imagen local para ruta ${ruta.ruta_Id} -> $localPath',
                              );
                              // mostrar tarjeta con imagen local
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 6.0,
                                ),
                                child: Card(
                                  color: const Color(0xFF141A2F),
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(
                                      color: Color(0xFFD6B68A),
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 4,
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          await verificarConexion();
                                          if (isOnline) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RutaMapScreen(
                                                  rutaId: ruta.ruta_Id,
                                                  descripcion:
                                                      ruta.ruta_Descripcion,
                                                  vendId: globalVendId,
                                                ),
                                              ),
                                            );
                                          } else {
                                            final hasTiles = await _departmentTilesExist('Atlántida');
                                            if (hasTiles) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      RutasOfflineMapScreen(
                                                        rutaId: ruta.ruta_Id,
                                                        descripcion: 'Atlántida',
                                                      ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text('No hay mapas offline descargados para Atlántida.'),
                                              ));
                                            }
                                          }
                                        },
                                        child: Card(
                                          color: const Color(0xFFF5F5F5),
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                            top: 8,
                                            bottom: 8,
                                          ),
                                          elevation: 2,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              bottomLeft: Radius.circular(16),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(16),
                                                  bottomLeft: Radius.circular(
                                                    16,
                                                  ),
                                                ),
                                            child: Image.file(
                                              File(localPath),
                                              height: 120,
                                              width: 140,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      height: 120,
                                                      width: 140,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.map,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ruta.ruta_Descripcion ??
                                                    'Sin descripción',
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
                                              builder: (_) =>
                                                  RutasDetailsScreen(
                                                    ruta: ruta,
                                                  ),
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

                            // Si no es local, puede ser un URL remoto. Mostrar online y cachear
                            if (mapUrl.startsWith('http')) {
                              print(
                                'DEBUG mostrando imagen remota para ruta ${ruta.ruta_Id}',
                              );
                              // cachear en background
                              guardarImagenDeMapaStatic(
                                mapUrl,
                                'map_static_${ruta.ruta_Id}',
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 6.0,
                                ),
                                child: Card(
                                  color: const Color(0xFF141A2F),
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(
                                      color: Color(0xFFD6B68A),
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 4,
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          await verificarConexion();
                                          if (isOnline) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RutaMapScreen(
                                                  rutaId: ruta.ruta_Id,
                                                  descripcion:
                                                      ruta.ruta_Descripcion,
                                                  vendId: globalVendId,
                                                ),
                                              ),
                                            );
                                          } else {
                                              final hasTiles = await _departmentTilesExist('Atlántida');
                                              if (hasTiles) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        RutasOfflineMapScreen(
                                                          rutaId: ruta.ruta_Id,
                                                          descripcion: 'Atlántida',
                                                        ),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                  content: Text('No hay mapas offline descargados para Atlántida.'),
                                                ));
                                              }
                                          }
                                        },
                                        child: Card(
                                          color: const Color(0xFFF5F5F5),
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                            top: 8,
                                            bottom: 8,
                                          ),
                                          elevation: 2,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              bottomLeft: Radius.circular(16),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(16),
                                                  bottomLeft: Radius.circular(
                                                    16,
                                                  ),
                                                ),
                                            child: Image.network(
                                              mapUrl,
                                              height: 120,
                                              width: 140,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      height: 120,
                                                      width: 140,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.map,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ruta.ruta_Descripcion ??
                                                    'Sin descripción',
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
                                              builder: (_) =>
                                                  RutasDetailsScreen(
                                                    ruta: ruta,
                                                  ),
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
                            // Si llegamos aquí, mostrar placeholder
                            return Container(
                              height: 120,
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.map,
                                size: 40,
                                color: Colors.grey,
                              ),
                            );
                          }
                          // fallback (no deberia llegar aquí)
                          return Container(
                            height: 120,
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 6.0,
                            ),
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.map,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}
