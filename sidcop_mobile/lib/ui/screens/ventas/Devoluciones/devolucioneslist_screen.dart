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
                  Text(
                    'Listado de Devoluciones',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.bold,
                    ),
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
                            Text(
                              'Error al cargar las devoluciones',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Satoshi',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _devolucionesFuture = _loadDevoluciones();
                                });
                              },
                              child: const Text(
                                'Reintentar',
                                style: TextStyle(fontFamily: 'Satoshi'),
                              ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Satoshi',
                          ),
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
                      return _buildDevolucionCard(devolucion);
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

  Widget _buildDevolucionCard(DevolucionesViewModel devolucion) {
    // Color principal del proyecto (usando el mismo que en el drawer y otros componentes)
    final primaryColor = const Color(0xFF141A2F); // Azul oscuro principal
    final secondaryColor = const Color(0xFF1E2746); // Tono ligeramente más claro para gradiente
    final backgroundColor = const Color(0xFFF5F5F7); // Fondo gris claro
    
    // Usar el ícono original de devolución
    final iconoDevolucion = Icons.assignment_return;
    
    // Obtener el estado como texto
    final estado = devolucion.devoEstado.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          _showDevolucionDetails(context, devolucion);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, backgroundColor.withOpacity(0.3)],
                ),
              ),
              child: Column(
                children: [
                  // Header con gradiente de estado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [primaryColor, secondaryColor],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconoDevolucion,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Devolución #${devolucion.devoId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  // Contenido de la tarjeta
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila de cliente
                        _buildDetailRow(
                          Icons.person_outline,
                          'Cliente',
                          devolucion.clieNombreNegocio ?? 'Cliente #${devolucion.clieId}',
                        ),
                        const SizedBox(height: 12),
                        // Fila de motivo
                        _buildDetailRow(
                          Icons.receipt_long_outlined,
                          'Motivo',
                          devolucion.devoMotivo,
                        ),
                        const SizedBox(height: 12),
                        // Fila de fecha
                        _buildDetailRow(
                          Icons.calendar_today_outlined,
                          'Fecha',
                          _formatDate(devolucion.devoFecha),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF8E8E93),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Satoshi',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDevolucionDetails(BuildContext context, DevolucionesViewModel devolucion) {
    showDevolucionDetalleBottomSheet(
      context: context,
      devolucion: devolucion,
    );
  }
}