import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/models/RutasViewModel.Dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';


class RutasScreen extends StatefulWidget {
  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
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
      print('Rutas fetched successfully: ${_rutas.length} rutas loaded.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas')),
      drawer: CustomDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                          Icon(Icons.people, color: Colors.white, size: 30),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _rutas.length,
                      itemBuilder: (context, index) {
                        final ruta = _rutas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(ruta.ruta_Descripcion ?? 'Sin descripción'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Código: ${(ruta.ruta_Codigo ?? "-").toString()}'),
                                Text('Observaciones: ${(ruta.ruta_Observaciones ?? "-").toString()}'),
                                Text('Estado: ${ruta.ruta_Estado ? "Activo" : "Inactivo"}'),
                              ],
                            ),
                            trailing: Text('ID: ${ruta.ruta_Id.toString()}'),
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