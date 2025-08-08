import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/Globalservice.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'Rutas_mapscreen.dart';

class RutasDetailsScreen extends StatelessWidget {
  Future<Map<String, dynamic>> _getStaticMapData(BuildContext context) async {
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
    final markers = direccionesFiltradas
        .map((d) => 'markers=color:red%7C${d.dicl_latitud},${d.dicl_longitud}')
        .join('&');
    String center = direccionesFiltradas.isNotEmpty
        ? '${direccionesFiltradas.first.dicl_latitud},${direccionesFiltradas.first.dicl_longitud}'
        : '15.525585,-88.013512';
    final mapUrl =
        'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=15&size=400x150&$markers&key=$mapApikey';
    return {
      'mapUrl': mapUrl,
      'clientesCount': clientesFiltrados.length,
      'direccionesCount': direccionesFiltradas.length,
    };
  }

  final Ruta ruta;
  const RutasDetailsScreen({super.key, required this.ruta});

  Widget _buildInfoField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141A2F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AppBackground(
            title: 'Detalles de la Ruta',
            icon: Icons.alt_route,
            onRefresh: () async {},
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            size: 24,
                            color: Color(0xFF141A2F),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            ruta.ruta_Descripcion ?? '',
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mapa estático con los marcadores filtrados
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _getStaticMapData(context),
                      builder: (context, snapshot) {
                        final mapUrl =
                            snapshot.data?['mapUrl'] ??
                            'https://maps.googleapis.com/maps/api/staticmap?center=15.525585,-88.013512&zoom=15&size=400x150&markers=color:red%7C15.525585,-88.013512&key=$mapApikey';
                        final clientesCount =
                            snapshot.data?['clientesCount'] ?? 0;
                        final direccionesCount =
                            snapshot.data?['direccionesCount'] ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RutaMapScreen(
                                      rutaId: ruta.ruta_Id,
                                      descripcion: ruta.ruta_Descripcion,
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  mapUrl,
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
                            const SizedBox(height: 8),
                            Text(
                              'Clientes en la ruta: $clientesCount',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF141A2F),
                              ),
                            ),
                            Text(
                              'Visitas en la ruta: $direccionesCount',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF141A2F),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoField(
                          label: 'Código:',
                          value: ruta.ruta_Codigo?.toString() ?? '-',
                        ),
                        const SizedBox(height: 12),
                        if (ruta.ruta_Observaciones != null &&
                            ruta.ruta_Observaciones!.isNotEmpty)
                          _buildInfoField(
                            label: 'Observaciones:',
                            value: ruta.ruta_Observaciones!,
                          ),
                        const SizedBox(height: 12),
                        _buildInfoField(
                          label: 'Estado:',
                          value: ruta.ruta_Estado == true
                              ? 'Activa'
                              : 'Inactiva',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
