import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'Rutas_mapscreen.dart'; // contiene RutaMapScreen
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Limpio y reconstruido: detalles de ruta con sección desplegable única "Clientes".

class RutasDetailsScreen extends StatefulWidget {
  final Ruta ruta;
  const RutasDetailsScreen({super.key, required this.ruta});
  @override
  State<RutasDetailsScreen> createState() => _RutasDetailsScreenState();
}

class _RutasDetailsScreenState extends State<RutasDetailsScreen> {
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
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  bool _loading = true;
  String? _error;
  List<Cliente> _clientes = [];
  Map<int, List<DireccionCliente>> _direccionesPorCliente = {};
  String? _staticMapUrl;
  bool _clientesExpanded = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final clientesService = ClientesService();
      final direccionesService = DireccionClienteService();
      final clientesJson = await clientesService.getClientes();
      final clientes = clientesJson
          .map<Cliente>((j) => Cliente.fromJson(j))
          .toList();
      final clientesFiltrados = clientes
          .where((c) => c.ruta_Id == widget.ruta.ruta_Id)
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
      final mapDirecciones = <int, List<DireccionCliente>>{};
      for (final d in direccionesFiltradas) {
        mapDirecciones.putIfAbsent(d.clie_id, () => []).add(d);
      }
    // Usar el mismo icono marker que en Rutas_screen.dart
    const iconUrl = 'https://res.cloudinary.com/dbt7mxrwk/image/upload/v1755185408/static_marker_cjmmpj.png';
    final markers = direccionesFiltradas
      .where((d) => d.dicl_latitud != null && d.dicl_longitud != null)
      .map(
      (d) => 'markers=icon:$iconUrl%7C${d.dicl_latitud},${d.dicl_longitud}',
      )
      .join('&');
    final center =
      (direccionesFiltradas.isNotEmpty &&
        direccionesFiltradas.first.dicl_latitud != null &&
        direccionesFiltradas.first.dicl_longitud != null)
      ? '${direccionesFiltradas.first.dicl_latitud},${direccionesFiltradas.first.dicl_longitud}'
      : '15.525585,-88.013512';
    final staticUrl =
      'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=10&size=600x250&$markers&key=$mapApikey';
      if (mounted) {
        setState(() {
          _clientes = clientesFiltrados;
          _direccionesPorCliente = mapDirecciones;
          _staticMapUrl = staticUrl;
          _loading = false;
        });
      }
    // Guardar imagen estática offline igual que en Rutas_screen.dart
    await guardarImagenDeMapaStatic(staticUrl, 'map_static_${widget.ruta.ruta_Id}');
      // Guardar detalles encriptados offline
      await _guardarDetallesOffline(
        clientesFiltrados,
        direccionesFiltradas,
        staticUrl,
      );
    } catch (e) {
      // Si falla, intentar leer detalles offline
      final detallesOffline = await _leerDetallesOffline();
      if (detallesOffline != null && detallesOffline['clientes'] != null && (detallesOffline['clientes'] as List).isNotEmpty) {
        if (mounted) {
          setState(() {
            _clientes = detallesOffline['clientes'] ?? [];
            _direccionesPorCliente = detallesOffline['direccionesPorCliente'] ?? {};
            _staticMapUrl = detallesOffline['staticMapUrl'];
            _loading = false;
            _error = null; // No mostrar error si hay datos offline
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'No hay datos disponibles. Compruebe su conexión a Internet.';
            _loading = false;
          });
        }
      }
    }
  }

  // Guarda los detalles encriptados offline por ruta
  Future<void> _guardarDetallesOffline(
    List<Cliente> clientes,
    List<DireccionCliente> direcciones,
    String staticMapUrl,
  ) async {
    final detalles = {
      'clientes': clientes.map((c) => c.toJson()).toList(),
      'direcciones': direcciones.map((d) => d.toJson()).toList(),
      'staticMapUrl': staticMapUrl,
    };
    await secureStorage.write(
      key: 'details_ruta_${widget.ruta.ruta_Id}',
      value: jsonEncode(detalles),
    );
  }

  // Lee los detalles encriptados offline por ruta
  Future<Map<String, dynamic>?> _leerDetallesOffline() async {
    final detallesString = await secureStorage.read(
      key: 'details_ruta_${widget.ruta.ruta_Id}',
    );
    if (detallesString == null) return null;
    final detallesMap = jsonDecode(detallesString);
    // Reconstruir objetos
    final clientes =
        (detallesMap['clientes'] as List?)
            ?.map((j) => Cliente.fromJson(j))
            .toList() ??
        [];
    final direcciones =
        (detallesMap['direcciones'] as List?)
            ?.map((j) => DireccionCliente.fromJson(j))
            .toList() ??
        [];
    final mapDirecciones = <int, List<DireccionCliente>>{};
    for (final d in direcciones) {
      mapDirecciones.putIfAbsent(d.clie_id, () => []).add(d);
    }
    return {
      'clientes': clientes,
      'direccionesPorCliente': mapDirecciones,
      'staticMapUrl': detallesMap['staticMapUrl'],
    };
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFFD6B68A),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFFB5B5B5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMeta(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$k: ',
            style: const TextStyle(
              color: Color(0xFFD6B68A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: Color(0xFFB5B5B5), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteTile(Cliente c) {
    final direcciones = _direccionesPorCliente[c.clie_Id ?? -1] ?? [];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        collapsedBackgroundColor: const Color(0xFF141A2F),
        backgroundColor: const Color(0xFF141A2F),
        leading: const Icon(Icons.person_pin_circle, color: Color(0xFFD6B68A)),
        title: Text(
          c.clie_NombreNegocio ?? c.clie_Nombres ?? 'Cliente',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        subtitle: (c.clie_Codigo != null)
            ? Text(
                'Código: ${c.clie_Codigo}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              )
            : null,
        children: [
          if (direcciones.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Sin direcciones asociadas',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: direcciones.map((d) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E253D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0x33D6B68A),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.dicl_direccionexacta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _miniMeta('Municipio', d.muni_descripcion),
                        _miniMeta('Depto', d.depa_descripcion),
                        if ((d.dicl_observaciones).isNotEmpty)
                          _miniMeta('Obs', d.dicl_observaciones),
                        if (d.dicl_latitud != null && d.dicl_longitud != null)
                          _miniMeta(
                            'Coords',
                            '${d.dicl_latitud!.toStringAsFixed(5)}, ${d.dicl_longitud!.toStringAsFixed(5)}',
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Detalles de la Ruta',
      icon: Icons.alt_route,
      onRefresh: () async => _cargarDatos(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            size: 22,
                            color: Color(0xFFD6B68A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.ruta.ruta_Descripcion ?? 'Ruta',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _staticMapUrl != null
                      ? GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RutaMapScreen(
                                  rutaId: widget.ruta.ruta_Id,
                                  descripcion: widget.ruta.ruta_Descripcion,
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(
                                  _staticMapUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return FutureBuilder<String?>(
                                      future: obtenerImagenLocalStatic(widget.ruta.ruta_Id),
                                      builder: (context, snapshotLocal) {
                                        if (snapshotLocal.connectionState == ConnectionState.done && snapshotLocal.data != null) {
                                          return Image.file(
                                            File(snapshotLocal.data!),
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          );
                                        } else {
                                          return Container(
                                            height: 180,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.map,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC141A2F),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: const Color(0xFFD6B68A),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_full,
                                        size: 16,
                                        color: Color(0xFFD6B68A),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Ver mapa',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FutureBuilder<String?>(
                          future: obtenerImagenLocalStatic(widget.ruta.ruta_Id),
                          builder: (context, snapshotLocal) {
                            if (snapshotLocal.connectionState == ConnectionState.done && snapshotLocal.data != null) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RutaMapScreen(
                                        rutaId: widget.ruta.ruta_Id,
                                        descripcion: widget.ruta.ruta_Descripcion,
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.file(
                                        File(snapshotLocal.data!),
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 12,
                                      bottom: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xCC141A2F),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: const Color(0xFFD6B68A),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.open_in_full,
                                              size: 16,
                                              color: Color(0xFFD6B68A),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Ver mapa',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                height: 180,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.map,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              );
                            }
                          },
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141A2F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD6B68A),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD6B68A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Descripción',
                            widget.ruta.ruta_Descripcion ?? '-',
                          ),
                          const SizedBox(height: 2),
                          _infoRow(
                            'Código',
                            widget.ruta.ruta_Codigo?.toString() ?? '-',
                          ),
                          _infoRow(
                            'Paradas',
                            _direccionesPorCliente.values
                                .fold<int>(0, (a, b) => a + b.length)
                                .toString(),
                          ),
                          if ((widget.ruta.ruta_Observaciones ?? '')
                              .trim()
                              .isNotEmpty)
                            _infoRow(
                              'Observaciones',
                              widget.ruta.ruta_Observaciones ?? '',
                            ),
                        ],
                      ),
                    ),

                    // Bloque de clientes
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A2F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD6B68A),
                          width: 1,
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          onExpansionChanged: (v) => setState(() => _clientesExpanded = v),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          title: const Text(
                            'Clientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          trailing: AnimatedRotation(
                            turns: _clientesExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFD6B68A),
                            ),
                          ),
                          children: [
                            if (_clientes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'No hay clientes en esta ruta',
                                  style: TextStyle(
                                    color: Color(0xFF9E9E9E),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: _clientes.map(_buildClienteTile).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
