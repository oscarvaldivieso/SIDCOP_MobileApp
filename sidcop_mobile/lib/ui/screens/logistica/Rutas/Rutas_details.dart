import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'Rutas_mapscreen.dart';
import 'package:sidcop_mobile/services/global_service.dart';

class RutasDetailsScreen extends StatefulWidget {
  final Ruta ruta;
  const RutasDetailsScreen({Key? key, required this.ruta}) : super(key: key);

  @override
  State<RutasDetailsScreen> createState() => _RutasDetailsScreenState();
}

class _RutasDetailsScreenState extends State<RutasDetailsScreen> {
  String? _staticMapUrl;
  List<Cliente> _clientes = [];
  List<DireccionCliente> _direcciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final clientesService = ClientesService();
    final direccionesService = DireccionClienteService();
    final clientesJson = await clientesService.getClientes();
    final clientes = clientesJson
        .map<Cliente>((json) => Cliente.fromJson(json))
        .toList();
    final clientesFiltrados = clientes
        .where((c) => c.ruta_Id == widget.ruta.ruta_Id)
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
    String center = direccionesFiltradas.isNotEmpty
        ? '${direccionesFiltradas.first.dicl_latitud},${direccionesFiltradas.first.dicl_longitud}'
        : '15.525585,-88.013512';
    final staticMapUrl =
        'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=15&size=400x150&$markers&key=$mapApikey';
    setState(() {
      _clientes = clientesFiltrados;
      _direcciones = direccionesFiltradas;
      _staticMapUrl = staticMapUrl;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalles de la Ruta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ruta.ruta_Descripcion ?? 'Sin descripción',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Código: ${widget.ruta.ruta_Codigo ?? "-"}'),
                    Text(
                      'Observaciones: ${widget.ruta.ruta_Observaciones ?? "-"}',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.white,
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Clientes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_clientes.length}',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            color: Colors.white,
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Direcciones',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_direcciones.length}',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_staticMapUrl != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RutaMapScreen(
                                rutaId: widget.ruta.ruta_Id,
                                descripcion: widget.ruta.ruta_Descripcion,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _staticMapUrl!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 150,
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
                    const SizedBox(height: 16),
                    // Solo mostrar la cantidad de clientes y direcciones
                    const SizedBox(height: 16),
                    const Text(
                      'Direcciones:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._direcciones.map(
                      (d) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            '${d.dicl_direccionexacta}, ${d.muni_descripcion}, ${d.depa_descripcion}',
                          ),
                          subtitle: d.dicl_observaciones.isNotEmpty
                              ? Text('Observaciones: ${d.dicl_observaciones}')
                              : null,
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
