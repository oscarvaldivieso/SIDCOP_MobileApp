import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucion_detalle_bottom_sheet.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';

class DevolucioneslistScreen extends StatefulWidget {
  const DevolucioneslistScreen({super.key});

  @override
  State<DevolucioneslistScreen> createState() => _DevolucioneslistScreenState();
}

class _DevolucioneslistScreenState extends State<DevolucioneslistScreen> {
  final DevolucionesService _devolucionesService = DevolucionesService();
  late Future<List<DevolucionesViewModel>> _devolucionesFuture;
  List<dynamic> permisos = [];

  @override
  void initState() {
    super.initState();
    _loadPermisos();
    _devolucionesFuture = _loadDevoluciones();
    print('DevolucioneslistScreen initialized');
  }

  Future<void> _loadPermisos() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    if (userData != null &&
        (userData['PermisosJson'] != null ||
            userData['permisosJson'] != null)) {
      try {
        final permisosJson =
            userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }

  Future<List<DevolucionesViewModel>> _loadDevoluciones() async {
    try {
      final devoluciones = await _devolucionesService.listarDevoluciones();
      print('Successfully loaded ${devoluciones.length} devoluciones');
      if (devoluciones.isEmpty) {
        print('No devoluciones found in the response');
      } else {
        print('First devolucion: ${devoluciones.first.toJson()}');
      }
      return devoluciones;
    } catch (e) {
      print('Error loading devoluciones: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Devoluciones',
      icon: Icons.restart_alt,
      permisos: permisos,
      onRefresh: () async {
        setState(() {
          _devolucionesFuture = _loadDevoluciones();
        });
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Listado de Devoluciones',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFFE0C7A0)),
                    onPressed: () {
                      setState(() {
                        _devolucionesFuture = _loadDevoluciones();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              FutureBuilder<List<DevolucionesViewModel>>(
                future: _devolucionesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Error al cargar las devoluciones',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _devolucionesFuture = _loadDevoluciones();
                                });
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Text(
                          'No hay devoluciones registradas',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }

                  final devoluciones = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devoluciones.length,
                    itemBuilder: (context, index) {
                      final devolucion = devoluciones[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          side: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.0),
                          onTap: () {
                            _showDevolucionDetails(context, devolucion);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0C7A0).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_return,
                                    color: Color(0xFFE0C7A0),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        devolucion.clieNombreNegocio ?? 'Cliente #${devolucion.clieId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF141A2F),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        devolucion.devoMotivo,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(devolucion.devoFecha),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  void _showDevolucionDetails(BuildContext context, DevolucionesViewModel devolucion) {
    showDevolucionDetalleBottomSheet(
      context: context,
      devolucion: devolucion,
    );
  }
}