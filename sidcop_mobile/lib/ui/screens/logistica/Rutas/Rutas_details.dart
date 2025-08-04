import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';

class RutasDetailsScreen extends StatefulWidget {
  final Ruta ruta;
  const RutasDetailsScreen({Key? key, required this.ruta}) : super(key: key);

  @override
  State<RutasDetailsScreen> createState() => _RutasDetailsScreenState();
}

class _RutasDetailsScreenState extends State<RutasDetailsScreen> {
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
    setState(() {
      _clientes = clientesFiltrados;
      _direcciones = direccionesFiltradas;
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
                    const Text(
                      'Clientes en la ruta:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._clientes.map(
                      (cliente) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(cliente.clie_NombreNegocio ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nombre: ${cliente.clie_Nombres ?? ''} ${cliente.clie_Apellidos ?? ''}',
                              ),
                              if (cliente.clie_Telefono != null &&
                                  cliente.clie_Telefono!.isNotEmpty)
                                Text('Teléfono: ${cliente.clie_Telefono}'),
                              if (cliente.clie_RTN != null &&
                                  cliente.clie_RTN!.isNotEmpty)
                                Text('RTN: ${cliente.clie_RTN}'),
                              if (cliente.clie_DNI != null &&
                                  cliente.clie_DNI!.isNotEmpty)
                                Text('DNI: ${cliente.clie_DNI}'),
                            ],
                          ),
                        ),
                      ),
                    ),
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
