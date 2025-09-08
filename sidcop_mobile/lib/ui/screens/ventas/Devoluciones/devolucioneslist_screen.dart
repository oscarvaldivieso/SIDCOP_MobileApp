import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/Offline_Services/Devoluciones_OfflineServices.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucion_detalle_bottom_sheet.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucioncrear_screen.dart';
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
  bool isOnline = true; // Indicador de estado de conexión

  // Método para verificar la conexión a internet
  Future<bool> verificarConexion() async {
    try {
      final tieneConexion = await VerificarService.verificarConexion();
      setState(() {
        isOnline = tieneConexion;
      });
      print('Estado de conexión: ${tieneConexion ? 'Online' : 'Offline'}');
      return tieneConexion;
    } catch (e) {
      print('Error al verificar la conexión: $e');
      setState(() {
        isOnline = false;
      });
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPermisos();
    // Inicializar _devolucionesFuture inmediatamente para evitar LateInitializationError
    _devolucionesFuture = _loadDevoluciones();
    // Luego actualizar después de verificar conexión
    _actualizarDatosSegunConexion();
    print('DevolucioneslistScreen initialized');
  }

  // Método para actualizar los datos según la conexión
  Future<void> _actualizarDatosSegunConexion() async {
    // Verificar si hay conexión a internet
    await verificarConexion();

    // Solo actualizar si la pantalla sigue montada
    if (mounted) {
      setState(() {
        _devolucionesFuture = _loadDevoluciones();
      });
    }
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
      print(
        'Estado de conexión antes de cargar devoluciones: ${isOnline ? 'Online' : 'Offline'}',
      );

      // Ya no verificamos la conexión aquí, usamos el estado actual de isOnline
      // que se actualiza mediante el método verificarConexion()
      List<DevolucionesViewModel> devoluciones = [];

      // Sincronizar y guardar devoluciones pasando el estado de conexión actual
      final devolucionesData =
          await DevolucionesOffline.sincronizarYGuardarDevoluciones(
            forzarSincronizacionDetalles:
                isOnline, // Solo sincronizar detalles si estamos online
            isOnline:
                isOnline, // Pasar el estado de conexión para que el método sepa si debe obtener del servidor o localmente
          );

      // Convertir a modelos con manejo mejorado de errores
      try {
        devoluciones = DevolucionesOffline.convertirAModelos(devolucionesData);
        print(
          '${isOnline ? 'Online' : 'Offline'}: Successfully loaded ${devoluciones.length} devoluciones',
        );
      } catch (conversionError) {
        print('Error al convertir devoluciones a modelos: $conversionError');

        // Intentar conversión manual
        devoluciones = [];
        for (var devData in devolucionesData) {
          try {
            devoluciones.add(DevolucionesViewModel.fromJson(devData));
          } catch (e) {
            print('Error al convertir una devolución específica: $e');
            print('Datos problemáticos: $devData');
          }
        }
        print(
          'Se pudieron convertir ${devoluciones.length} devoluciones después del manejo de errores',
        );
      }

      if (isOnline) {
        // Si estamos online, sincronizar detalles para todas las devoluciones
        print(
          'Modo online: Sincronizando detalles para todas las devoluciones...',
        );

        // Imprimir el estado actual del almacenamiento local de detalles
        await DevolucionesOffline.imprimirDetallesDevolucionesGuardados();

        if (devoluciones.isEmpty) {
          print('No devoluciones found in the server response');
        } else {
          // Sincronizar detalles para todas las devoluciones que aún no los tienen
          for (final devolucion in devoluciones) {
            final tieneDetalles =
                await DevolucionesOffline.existenDetallesParaDevolicion(
                  devolucion.devoId,
                );

            if (!tieneDetalles) {
              print(
                'La devolución ID ${devolucion.devoId} no tiene detalles. Sincronizando...',
              );

              try {
                // Intentar sincronizar los detalles para esta devolución específica
                final service = DevolucionesService();
                final detallesServidor = await service.getDevolucionDetalles(
                  devolucion.devoId,
                );

                if (detallesServidor.isNotEmpty) {
                  // Convertir a formato Map para almacenamiento
                  final detallesMap = detallesServidor
                      .map((d) => d.toJson())
                      .toList();

                  await DevolucionesOffline.guardarDetallesDevolucion(
                    devolucion.devoId,
                    detallesMap,
                  );

                  print(
                    '✓ Sincronizados ${detallesMap.length} detalles para ID ${devolucion.devoId}',
                  );
                } else {
                  print(
                    '⚠ No se encontraron detalles en el servidor para ID ${devolucion.devoId}',
                  );
                }
              } catch (detalleError) {
                print(
                  'Error al sincronizar detalles para ID ${devolucion.devoId}: $detalleError',
                );
              }
            }
          }

          // Verificar el estado final del almacenamiento
          await DevolucionesOffline.imprimirDetallesDevolucionesGuardados();
        }
      } else {
        print('Modo offline: Usando datos almacenados localmente');

        // Imprimir los detalles disponibles en modo offline para diagnóstico
        await DevolucionesOffline.imprimirDetallesDevolucionesGuardados();

        if (devoluciones.isEmpty) {
          print('⚠ No se encontraron devoluciones en el almacenamiento local');

          // Intentar cargar directamente desde el almacenamiento como último recurso
          try {
            print(
              'Intentando cargar devoluciones directamente del almacenamiento...',
            );
            final devolucionesDirectas =
                await DevolucionesOffline.obtenerDevolucionesLocal();
            if (devolucionesDirectas.isNotEmpty) {
              devoluciones = DevolucionesOffline.convertirAModelos(
                devolucionesDirectas,
              );
              print(
                '✓ Recuperadas ${devoluciones.length} devoluciones directamente del almacenamiento',
              );
            }
          } catch (e) {
            print('Error en la recuperación directa: $e');
          }
        }
      }

      return devoluciones;
    } catch (e) {
      print('Error general al cargar devoluciones: $e');
      print('Stacktrace: ${e is Error ? e.stackTrace : ''}');

      // Si ocurre un error, intentar cargar desde almacenamiento local como último recurso
      try {
        print(
          '🔄 Intentando recuperación de emergencia desde almacenamiento local...',
        );
        final devolucionesData =
            await DevolucionesOffline.obtenerDevolucionesLocal();
        final localDevoluciones = DevolucionesOffline.convertirAModelos(
          devolucionesData,
        );
        print(
          '✓ Recuperadas ${localDevoluciones.length} devoluciones en modo de emergencia',
        );
        return localDevoluciones;
      } catch (localError) {
        print('❌ Error también en la recuperación de emergencia: $localError');
        return []; // Devolver lista vacía en lugar de relanzar el error para evitar un crash
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DevolucioncrearScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF141A2F),
        child: const Icon(Icons.add, color: Colors.white),
        shape: const CircleBorder(),
        elevation: 4.0,
      ),
      body: AppBackground(
        title: 'Devoluciones',
        icon: Icons.restart_alt,
        permisos: permisos,
        onRefresh: () async {
          // Verificar conexión antes de recargar
          await verificarConexion();

          setState(() {
            _devolucionesFuture = _loadDevoluciones();
          });
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Widget _buildDevolucionCard(DevolucionesViewModel devolucion) {
    // Color principal del proyecto (usando el mismo que en el drawer y otros componentes)
    final primaryColor = const Color(0xFF141A2F); // Azul oscuro principal
    final secondaryColor = const Color(
      0xFF1E2746,
    ); // Tono ligeramente más claro para gradiente
    final backgroundColor = const Color(0xFFF5F5F7); // Fondo gris claro

    // Usar el ícono original de devolución
    final iconoDevolucion = Icons.assignment_return;

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
        Icon(icon, size: 20, color: const Color(0xFF8E8E93)),
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

  void _showDevolucionDetails(
    BuildContext context,
    DevolucionesViewModel devolucion,
  ) {
    showDevolucionDetalleBottomSheet(context: context, devolucion: devolucion);
  }
}
