import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'Rutas_mapscreen.dart';

class RutasScreen extends StatefulWidget {
  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  List<dynamic> permisos = [];
  final RutasService _rutasService = RutasService();
  List<Ruta> _rutas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRutas();
  }

  Future<void> _fetchRutas() async {
    try {
      final rutasJson = await _rutasService.getRutas();
      setState(() {
        _rutas = rutasJson.map<Ruta>((json) => Ruta.fromJson(json)).toList();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final String mapApiKey = 'AIzaSyA6bbij1_4crYsWVg6E1PnqGb17lNGdIjA';
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas')),
      drawer: CustomDrawer(permisos: permisos),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A2F),
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: AssetImage('assets/asset-breadcrumb.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rutas',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          Icon(Icons.map, color: Colors.white, size: 30),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _rutas.length,
                      itemBuilder: (context, index) {
                        final ruta = _rutas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(
                              ruta.ruta_Descripcion ?? 'Sin descripción',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () {
                                    final rutaId = ruta.ruta_Id ?? 0;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RutaMapScreen(
                                          rutaId: rutaId,
                                          descripcion: ruta.ruta_Descripcion,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    'https://maps.googleapis.com/maps/api/staticmap?center=15.525585,-88.013512&zoom=15&size=400x150&markers=color:red%7C15.525585,-88.013512&key=$mapApiKey',
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 120,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.map,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                  ),
                                ),
                                Text(
                                  'Código: ${(ruta.ruta_Codigo ?? "-").toString()}',
                                ),
                                Text(
                                  'Observaciones: ${(ruta.ruta_Observaciones ?? "-").toString()}',
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF141A2F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    onPressed: () {},
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
