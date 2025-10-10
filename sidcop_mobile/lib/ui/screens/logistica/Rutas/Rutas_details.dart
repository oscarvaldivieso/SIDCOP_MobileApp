import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'Rutas_mapscreen.dart'; // contiene RutaMapScreen
import 'Rutas_offline_mapscreen.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/Offline_Services/Rutas_OfflineService.dart';

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
    final filePath = await RutasScreenOffline.rutaEnDocuments(
      'map_static_$rutaId.png',
    );
    final file = File(filePath);
    if (await file.exists()) return filePath;
    return null;
  }

  /// Descarga la imagen desde `url` y la guarda en Documents como map_static_<rutaId>.png
  Future<void> _guardarImagenDesdeUrlSiEsPosible(String url, int rutaId) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri);
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final path = await RutasScreenOffline.rutaEnDocuments(
          'map_static_$rutaId.png',
        );
        final file = File(path);
        await file.writeAsBytes(resp.bodyBytes);
        // metadata
        try {
          final metaPath = await RutasScreenOffline.rutaEnDocuments(
            'map_static_$rutaId.url.txt',
          );
          final metaFile = File(metaPath);
          await metaFile.writeAsString(
            'url:$url\nbytes:${resp.bodyBytes.length}',
          );
        } catch (_) {}
      }
    } catch (e) {
    }
  }

  // Usar el servicio centralizado para persistencia offline
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
      const iconUrl =
          'http://200.59.27.115/Honduras_map/static_marker_cjmmpj.png';
      final markers = direccionesFiltradas
          .where((d) => d.dicl_latitud != null && d.dicl_longitud != null)
          .map(
            (d) =>
                'markers=icon:$iconUrl%7C${d.dicl_latitud},${d.dicl_longitud}',
          )
          .join('&');
      final visiblePoints = direccionesFiltradas
          .where((d) => d.dicl_latitud != null && d.dicl_longitud != null)
          .map((d) => '${d.dicl_latitud},${d.dicl_longitud}')
          .join('|');
      // El parámetro visible fuerza a que todos los puntos estén en la imagen
      final staticUrl =
          'https://maps.googleapis.com/maps/api/staticmap?size=400x150&$markers&visible=$visiblePoints&key=$mapApikey';
      if (mounted) {
        setState(() {
          _clientes = clientesFiltrados;
          _direccionesPorCliente = mapDirecciones;
          _staticMapUrl = staticUrl;
          _loading = false;
        });
      }
      // Intentar guardar la imagen static localmente (UI) y luego guardar detalles
      await _guardarImagenDesdeUrlSiEsPosible(staticUrl, widget.ruta.ruta_Id);
    } catch (e) {
      // Si falla, intentar leer detalles offline
      final detallesOffline = await _leerDetallesOffline();
      if (detallesOffline != null &&
          detallesOffline['clientes'] != null &&
          (detallesOffline['clientes'] as List).isNotEmpty) {
        if (mounted) {
          setState(() {
            _clientes = detallesOffline['clientes'] ?? [];
            _direccionesPorCliente =
                detallesOffline['direccionesPorCliente'] ?? {};
            _staticMapUrl = detallesOffline['staticMapUrl'];
            _loading = false;
            _error = null; // No mostrar error si hay datos offline
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                'No hay datos disponibles. Compruebe su conexión a Internet.';
            _loading = false;
          });
        }
      }
    }
  }

  // Nota: la pantalla ya no guarda detalles de ruta en almacenamiento.

  // Lee los detalles encriptados offline por ruta usando RutasScreenOffline
  Future<Map<String, dynamic>?> _leerDetallesOffline() async {
    final detalles = await RutasScreenOffline.leerDetallesRuta(
      widget.ruta.ruta_Id,
    );
    if (detalles == null) {
      return null;
    }

    // convertir a objetos modelo para el UI
    final clientes =
        (detalles['clientes'] as List?)?.map((j) {
          return Cliente.fromJson(j);
        }).toList() ??
        [];
    final direcciones =
        (detalles['direcciones'] as List?)?.map((j) {
          return DireccionCliente.fromJson(j);
        }).toList() ??
        [];

    final mapDirecciones = <int, List<DireccionCliente>>{};
    for (final d in direcciones) {
      mapDirecciones.putIfAbsent(d.clie_id, () => []).add(d);
    }

    return {
      'clientes': clientes,
      'direccionesPorCliente': mapDirecciones,
      'staticMapUrl':
          detalles['staticMapUrl'] ?? detalles['staticMapLocalPath'],
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
                        _miniMeta(
                          'Dirección',
                          '${d.dicl_direccionexacta}, ${d.muni_descripcion}',
                        ),
                        _miniMeta('Departamento', d.depa_descripcion),
                        if ((d.dicl_observaciones).isNotEmpty)
                          _miniMeta('Observación', d.dicl_observaciones),
                        if (d.dicl_latitud != null && d.dicl_longitud != null)
                          _miniMeta(
                            'Coordenadas',
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
                            onTap: () async {
                              await _abrirMapaSegunConexion();
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
                                        future: obtenerImagenLocalStatic(
                                          widget.ruta.ruta_Id,
                                        ),
                                        builder: (context, snapshotLocal) {
                                          if (snapshotLocal.connectionState ==
                                                  ConnectionState.done &&
                                              snapshotLocal.data != null) {
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
                            future: obtenerImagenLocalStatic(
                              widget.ruta.ruta_Id,
                            ),
                            builder: (context, snapshotLocal) {
                              if (snapshotLocal.connectionState ==
                                      ConnectionState.done &&
                                  snapshotLocal.data != null) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => RutaMapScreen(
                                          rutaId: widget.ruta.ruta_Id,
                                          descripcion:
                                              widget.ruta.ruta_Descripcion,
                                          vendId: globalVendId,
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
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
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
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          onExpansionChanged: (v) =>
                              setState(() => _clientesExpanded = v),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            16,
                          ),
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
                                children: _clientes
                                    .map(_buildClienteTile)
                                    .toList(),
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

  Future<void> _abrirMapaSegunConexion() async {
    try {
      // Quick connectivity probe
      final resp = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      final online = resp.statusCode == 200;
      if (online) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RutaMapScreen(
              rutaId: widget.ruta.ruta_Id,
              descripcion: widget.ruta.ruta_Descripcion,
              vendId: globalVendId,
            ),
          ),
        );
      } else {
        // fallback to offline map
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RutasOfflineMapScreen(
              rutaId: widget.ruta.ruta_Id,
              descripcion: widget.ruta.ruta_Descripcion,
            ),
          ),
        );
      }
    } catch (e) {
      // On timeout or any network error, open offline map
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RutasOfflineMapScreen(
            rutaId: widget.ruta.ruta_Id,
            descripcion: widget.ruta.ruta_Descripcion,
          ),
        ),
      );
    }
  }
}
