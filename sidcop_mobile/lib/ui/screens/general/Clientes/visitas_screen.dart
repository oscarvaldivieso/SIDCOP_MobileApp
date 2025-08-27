import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart'; // Cambié .Dart a .dart
import 'package:sidcop_mobile/models/VisitasViewModel.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';

class VendedorVisitasScreen extends StatefulWidget {
  final int usuaIdPersona;
  const VendedorVisitasScreen({super.key, required this.usuaIdPersona});

  @override
  State<VendedorVisitasScreen> createState() => _VendedorVisitasScreenState();
}

class _VendedorVisitasScreenState extends State<VendedorVisitasScreen> {
  final ClientesVisitaHistorialService _service =
      ClientesVisitaHistorialService();
  List<VisitasViewModel> _visitas = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState(); // Movido antes de otras operaciones
    developer.log(
      'VendedorVisitasScreen: usuaIdPersona recibido: ${widget.usuaIdPersona}', // Removí códigos ANSI
    );
    _loadVisitas();
  }

  Future<void> _loadVisitas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final visitas = await _service.listarPorVendedor();
      developer.log(
        'VendedorVisitasScreen: recibidas visitas (${visitas.runtimeType}) length=${visitas.length}',
      );
      if (visitas.isNotEmpty)
        developer.log('VendedorVisitasScreen: first=${visitas[0]}');

      setState(() {
        _visitas = List<VisitasViewModel>.from(visitas);
        _isLoading = false;
      });
      developer.log(
        'VendedorVisitasScreen: visitas recibidas: ${visitas.length}', // Removí códigos ANSI
      );
    } catch (e) {
      developer.log('Error cargando visitas: $e');
      setState(() {
        _errorMessage = 'Error al cargar las visitas';
        _isLoading = false;
      });
    }
  }

  // (Se usa la fecha cruda tal como llega)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Historial de Visitas',
        icon: Icons.location_history,
        onRefresh: _loadVisitas,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(fontFamily: 'Satoshi'),
                ),
              )
            : _visitas.isEmpty
            ? const Center(
                child: Text(
                  'No hay visitas registradas',
                  style: TextStyle(fontFamily: 'Satoshi'),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _visitas.length,
                itemBuilder: (context, index) {
                  final visita = _visitas[index];
                  final clienteNombre =
                      '${visita.clie_Nombres ?? ''} ${visita.clie_Apellidos ?? ''}'
                          .trim();
                  final negocio = visita.clie_NombreNegocio ?? '';
                  final fecha =
                      visita.clVi_Fecha?.toString() ?? 'Fecha no disponible';
                    
                  // SWITCH PARA COLOR DE LAS CARDS
                  Color primaryColor;
                  Color secondaryColor;
                  Color backgroundColor;
                  IconData statusIcon;
                  String statusLabel;

                  switch (visita.esVi_Descripcion.toString().toLowerCase()) {
                    case 'true':
                      statusLabel = 'Negocio cerrado';
                      primaryColor = const Color(0xFFFF3B30);
                      secondaryColor = const Color(0xFFFF6B60);
                      backgroundColor = const Color(0xFFFFE8E6);
                      statusIcon = Icons.cancel_rounded;
                      break;
                    default:
                      statusLabel = 'Venta Realizada';
                      primaryColor = const Color(0xFF141A2F);
                      secondaryColor = const Color(0xFF2C3655);
                      backgroundColor = const Color(0xFFE8EAF6);
                      statusIcon = Icons.check_circle_rounded;
                  }

                  // Tarjeta con información de la visita
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [secondaryColor, primaryColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // Cliente y Negocio
                          Text(
                            clienteNombre.isNotEmpty
                                ? clienteNombre
                                : 'Cliente',
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          if (negocio.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              negocio,
                              style: const TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Información del vendedor y ruta
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Vendedor: ${visita.vend_Nombres ?? ''} ${visita.vend_Apellidos ?? ''}'
                                          .trim(),
                                      style: const TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 14,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ruta: ${visita.ruta_Descripcion ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 14,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Estado de la visita
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: visita.esVi_Descripcion == 'Negocio cerrado'
                                ? BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withOpacity(0.3),
                                    ),
                                  )
                                : visita.esVi_Descripcion == 'Visitado(a)' || visita.esVi_Descripcion == 'Nuevo(a)'
                                    ? BoxDecoration(
                                        color: const Color(0xFF2196F3).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF2196F3).withOpacity(0.3),
                                        ),
                                      )
                                : visita.esVi_Descripcion == 'Venta Realizada'
                                    ? BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                                        ),
                                      )
                                : BoxDecoration(
                                    color: const Color(0xFFE3935A).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFE3935A).withOpacity(0.3),
                                    ),
                                  ),
                            child: Text(
                              visita.esVi_Descripcion ?? 'Estado desconocido',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 14,
                                color: visita.esVi_Descripcion == 'Negocio cerrado'
                                  ? const Color(0xFFEF4444)
                                  : visita.esVi_Descripcion == 'Visitado(a)' || visita.esVi_Descripcion == 'Nuevo(a)'
                                      ? const Color(0xFF2196F3)
                                  : visita.esVi_Descripcion == 'Venta Realizada'
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFE3935A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Observaciones
                          const Text(
                            'Observaciones:',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            visita.clVi_Observaciones ?? 'Sin observaciones',
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Fecha
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fecha: $fecha',
                                style: const TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 14,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ));
                },
              ),
      ),
    );
  }
}
