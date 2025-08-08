import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/services/Globalservice.dart';
import 'Rutas_mapscreen.dart';
import 'Rutas_details.dart';

class RutasScreen extends StatefulWidget {
  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  // Helper para obtener los markers de direcciones por cliente filtradas
  Future<String> _getStaticMapMarkers(Ruta ruta) async {
    // Obtener clientes y direcciones filtradas igual que en RutasMapScreen
    final clientesService = ClientesService();
    final direccionesService = DireccionClienteService();
    final clientesJson = await clientesService.getClientes();
    final clientes = clientesJson
        .map<Cliente>((json) => Cliente.fromJson(json))
        .toList();
    final clientesFiltrados = clientes
        .where((c) => c.ruta_Id == ruta.ruta_Id)
        .toList();
    final todasDirecciones = await direccionesService
        .getDireccionesPorCliente();
    final clienteIds = clientesFiltrados.map((c) => c.clie_Id).toSet();
    final direccionesFiltradas = todasDirecciones
        .where((d) => clienteIds.contains(d.clie_id))
        .toList();
    // Generar string de markers para el StaticMap
    final markers = direccionesFiltradas
        .map((d) => 'markers=color:red%7C${d.dicl_latitud},${d.dicl_longitud}')
        .join('&');
    // Si no hay direcciones, usar centro default
    String center = direccionesFiltradas.isNotEmpty
        ? '${direccionesFiltradas.first.dicl_latitud},${direccionesFiltradas.first.dicl_longitud}'
        : '15.525585,-88.013512';
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=15&size=400x150&$markers&key=$mapApikey';
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

  List<dynamic> permisos = [];
  final RutasService _rutasService = RutasService();
  final TextEditingController _searchController = TextEditingController();
  List<Ruta> _rutas = [];
  List<Ruta> _filteredRutas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRutas();
    _searchController.addListener(_applySearch);
  }

  Future<void> _fetchRutas() async {
    try {
      final rutasJson = await _rutasService.getRutas();
      final rutasList = rutasJson
          .map<Ruta>((json) => Ruta.fromJson(json))
          .toList();
      setState(() {
        _rutas = rutasList;
        _filteredRutas = List.from(rutasList);
        _isLoading = false;
      });
      print('Rutas ${_rutas.length} ');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las rutas: $e')),
        );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final String mapApiKey = mapApikey;
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: CustomDrawer(permisos: permisos),
      body: AppBackground(
        title: 'Rutas',
        icon: Icons.map,
        onRefresh: () async {
          await _fetchRutas();
          if (mounted) setState(() {});
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _rutas.isEmpty
            ? const Center(child: Text('No hay rutas'))
            : SingleChildScrollView(
                child: Column(
                  children: [
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
                            borderSide: BorderSide(
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
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 0,
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                    ),
                    ..._filteredRutas.map(
                      (ruta) => FutureBuilder<String>(
                        future: _getStaticMapMarkers(ruta),
                        builder: (context, snapshot) {
                          final mapUrl =
                              snapshot.data ??
                              'https://maps.googleapis.com/maps/api/staticmap?center=15.525585,-88.013512&zoom=15&size=400x150&markers=color:red%7C15.525585,-88.013512&key=$mapApiKey';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: SizedBox(
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RutaMapScreen(
                                              rutaId: ruta.ruta_Id,
                                              descripcion:
                                                  ruta.ruta_Descripcion,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Card(
                                        color: Colors.white,
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
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                          ),
                                          child: Image.network(
                                            mapUrl,
                                            height: 120,
                                            width: 140,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      height: 120,
                                                      width: 140,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.map,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
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
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Código: ${(ruta.ruta_Codigo ?? "-").toString()}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              'Observaciones: ${(ruta.ruta_Observaciones ?? "-").toString()}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 40,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF141A2F,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                ),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          RutasDetailsScreen(
                                                            ruta: ruta,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: const Text(
                                                  'Detalles',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFFD6B68A),
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ),
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
