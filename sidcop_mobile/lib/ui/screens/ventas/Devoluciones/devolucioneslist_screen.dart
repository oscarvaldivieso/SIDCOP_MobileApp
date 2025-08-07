import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';

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
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0C7A0).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.assignment_return,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(
                            devolucion.clieNombreNegocio ?? 'Cliente #${devolucion.clieId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Motivo: ${devolucion.devoMotivo}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Fecha: ${_formatDate(devolucion.devoFecha)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: devolucion.devoEstado
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  devolucion.devoEstado
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: devolucion.devoEstado
                                      ? Colors.green
                                      : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  devolucion.devoEstado ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: devolucion.devoEstado
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            // TODO: Navigate to detail screen
                          },
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
}