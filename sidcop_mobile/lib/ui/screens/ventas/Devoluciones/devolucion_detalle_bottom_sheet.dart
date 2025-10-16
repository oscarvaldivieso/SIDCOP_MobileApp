// Importaciones necesarias para la pantalla de detalles de devolución
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';
import 'package:sidcop_mobile/Offline_Services/Devoluciones_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';

/// Bottom sheet que muestra los detalles completos de una devolución
/// Incluye información del cliente, motivo, fecha y lista de productos
class DevolucionDetalleBottomSheet extends StatefulWidget {
  final DevolucionesViewModel devolucion;

  const DevolucionDetalleBottomSheet({Key? key, required this.devolucion})
    : super(key: key);

  @override
  _DevolucionDetalleBottomSheetState createState() =>
      _DevolucionDetalleBottomSheetState();
}

class _DevolucionDetalleBottomSheetState
    extends State<DevolucionDetalleBottomSheet> {
  // Future que contiene la lista de detalles de la devolución
  // Inicializado con lista vacía para evitar problemas de late initialization
  Future<List<DevolucionDetalleModel>> _detallesFuture = Future.value([]);
  // bool isOnline = true; // Eliminado indicador online/offline

  @override
  void initState() {
    super.initState();
    // Cargar los datos de la devolución inmediatamente al iniciar
    _cargarDatos();
  }

  /// Verifica si hay conexión a internet disponible
  /// Retorna true si hay conexión, false en caso contrario

  Future<bool> verificarConexion() async {
    try {
      final tieneConexion = await VerificarService.verificarConexion();
      // Eliminada lógica de estado online/offline
      return tieneConexion;
    } catch (e) {
      print('Error al verificar la conexión en detalles: $e');
      // Eliminada lógica de estado online/offline
      return false;
    }
  }

  /// Carga los datos de la devolución con manejo de modo offline
  /// Sincroniza desde el servidor si hay conexión, o usa datos locales

  Future<void> _cargarDatos() async {
    // Verificar si hay conexión a internet
    final tieneConexion = await verificarConexion();

    // FLUJO ONLINE: Si hay conexión, sincronizar detalles desde el servidor
    if (tieneConexion) {
      try {
        print(
          'Hay conexión, sincronizando detalles para devolución ID: ${widget.devolucion.devoId}',
        );

        // Obtener detalles frescos desde el servidor
        final service = DevolucionesService();
        final detalles = await service.getDevolucionDetalles(
          widget.devolucion.devoId,
        );

        if (detalles.isNotEmpty) {
          print('Se obtuvieron ${detalles.length} detalles del servidor');

          // Convertir a formato JSON y guardar localmente para uso offline
          final detallesMap = detalles.map((d) => d.toJson()).toList();
          await DevolucionesOffline.guardarDetallesDevolucion(
            widget.devolucion.devoId,
            detallesMap,
          );

          print(
            'Sincronización específica completada para devolución ID: ${widget.devolucion.devoId}',
          );
        } else {
          print('El servidor devolvió 0 detalles para esta devolución');
        }
      } catch (e) {
        print('Error al sincronizar detalles específicos: $e');
        // Continuar con la carga de datos locales en caso de error
      }
    } else {
      // FLUJO OFFLINE: Sin conexión, usar datos del almacenamiento local
      print('Sin conexión, se cargarán datos del almacenamiento local');
    }

    // Actualizar la UI con los datos cargados
    if (mounted) {
      setState(() {
        // Inicializar el Future que cargará los detalles
        _detallesFuture = _cargarDetallesDevolucion();
      });
    }
  }

  /// Método principal para cargar los detalles de la devolución
  /// Maneja múltiples estrategias: online, offline, caché local y recuperación de errores

  // Método para cargar detalles con manejo online/offline
  Future<List<DevolucionDetalleModel>> _cargarDetallesDevolucion() async {
    try {
      // Obtener el ID de la devolución
      int devolucionId = widget.devolucion.devoId;
      print('Intentando cargar detalles para devolución ID: $devolucionId');

      // Lista que contendrá los detalles cargados
      List<DevolucionDetalleModel> detalles = [];

      // Verificar estado de conexión a internet
      final tieneConexion = await verificarConexion();
      print(
        'Estado de conexión al cargar detalles: ${tieneConexion ? 'Online' : 'Offline'}',
      );

      // Verificar si ya existen detalles en el almacenamiento local
      bool tieneDetallesLocales = false;
      try {
        tieneDetallesLocales =
            await DevolucionesOffline.existenDetallesParaDevolicion(
              devolucionId,
            );
        print(
          '¿Ya existen detalles locales para ID $devolucionId? ${tieneDetallesLocales ? 'Sí' : 'No'}',
        );
      } catch (e) {
        print('Error al verificar si existen detalles locales: $e');
        tieneDetallesLocales = false;
      }

      // Estrategia optimizada para cargar detalles
      try {
        print(
          'Usando enfoque optimizado para cargar detalles de la devolución ID: $devolucionId',
        );

        // Determinar si se debe forzar la sincronización desde el servidor
        // Forzar solo si estamos online y no hay detalles locales
        final forceSync = tieneConexion && !tieneDetallesLocales;

        print(
          'Estrategia: ${tieneConexion ? 'Online' : 'Offline'}, ${forceSync ? 'Forzar sincronización' : 'Usar caché si está disponible'}',
        );

        // Sincronizar y obtener detalles usando el método optimizado
        final List<Map<String, dynamic>> detallesData =
            await DevolucionesOffline.sincronizarYGuardarDetallesDevolucion(
              devolucionId,
              isOnline: tieneConexion, // Estado de conexión actual
              forceSync: forceSync, // Si se debe forzar sincronización
            );

        // Convertir datos JSON a modelos con manejo de errores
        int exitosos = 0;
        int errores = 0;

        for (int i = 0; i < detallesData.length; i++) {
          try {
            final detalle = detallesData[i];
            // Convertir cada detalle a modelo
            detalles.add(DevolucionDetalleModel.fromJson(detalle));
            exitosos++;
          } catch (conversionError) {
            errores++;

            // Mostrar información de diagnóstico en caso de error
            try {
              final detalle = detallesData[i];
            } catch (e) {}
          }
        }

        // Mecanismo de recuperación si no se encontraron detalles
        if (detalles.isEmpty && tieneConexion) {
          try {
            // Último intento: consultar directamente al servidor
            final service = DevolucionesService();
            final detallesServidor = await service.getDevolucionDetalles(
              devolucionId,
            );

            if (detallesServidor.isNotEmpty) {
              // Guardar los detalles obtenidos para futuras consultas offline
              final detallesMap = detallesServidor
                  .map((d) => d.toJson())
                  .toList();
              await DevolucionesOffline.guardarDetallesDevolucion(
                devolucionId,
                detallesMap,
              );

              return detallesServidor;
            }
          } catch (emergencyError) {}
        }

        return detalles;
      } catch (syncError) {
        // Manejo de errores durante la sincronización
        // Fallback: Si estamos online, intentar obtener desde el servidor
        if (tieneConexion) {
          try {
            final service = DevolucionesService();
            final detallesServidor = await service.getDevolucionDetalles(
              devolucionId,
            );

            if (detallesServidor.isNotEmpty) {
              // Convertir y guardar localmente
              try {
                final detallesMap = detallesServidor
                    .map((d) => d.toJson())
                    .toList();
                await DevolucionesOffline.guardarDetallesDevolucion(
                  devolucionId,
                  detallesMap,
                );
              } catch (e) {}

              return detallesServidor;
            } else {}
          } catch (e) {}
        }

        // Último recurso: cargar desde almacenamiento local
        try {
          final detallesData =
              await DevolucionesOffline.obtenerDetallesDevolucionLocal(
                devolucionId,
                isOnline: false,
              );

          // Convertir cada detalle JSON a modelo
          for (final detalle in detallesData) {
            try {
              detalles.add(DevolucionDetalleModel.fromJson(detalle));
            } catch (e) {
              print('Error al convertir detalle: $e');
            }
          }

          if (detalles.isNotEmpty) {
            print(
              '✓ Recuperados ${detalles.length} detalles desde almacenamiento local',
            );
            return detalles;
          }
        } catch (localError) {
          print(
            'Error al cargar detalles desde almacenamiento local: $localError',
          );
        }
      }

      // Si todos los intentos fallaron, devolver lista vacía
      if (detalles.isEmpty) {
        print(
          '⚠ No se pudieron cargar detalles para la devolución ID: $devolucionId',
        );
        // La UI maneja correctamente el caso de lista vacía
      }

      return detalles;
    } catch (e) {
      // Manejo de errores generales
      print('❌ Error general en _cargarDetallesDevolucion: $e');
      print('Stacktrace: ${e is Error ? e.stackTrace : ''}');
      return []; // Devolver lista vacía en caso de error no manejado
    }
  }

  /// Construye la interfaz de usuario del bottom sheet

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador visual de arrastre (handle)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título del bottom sheet
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles de la Devolución',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF141A2F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Contenedor con información general de la devolución
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Nombre del cliente
                  _buildModernDetailRow(
                    'Cliente',
                    widget.devolucion.clieNombreNegocio ?? 'N/A',
                    Icons.business,
                  ),
                  const Divider(
                    height: 20,
                    thickness: 1,
                    indent: 40,
                    endIndent: 10,
                  ),
                  // Usuario que solicitó la devolución
                  _buildModernDetailRow(
                    'Solicitada Por',
                    widget.devolucion.nombreCompleto ?? 'N/A',
                    Icons.person_outline,
                  ),
                  const Divider(
                    height: 20,
                    thickness: 1,
                    indent: 40,
                    endIndent: 10,
                  ),
                  // Motivo de la devolución
                  _buildModernDetailRow(
                    'Motivo',
                    widget.devolucion.devoMotivo,
                    Icons.receipt_long_outlined,
                  ),
                  const Divider(
                    height: 20,
                    thickness: 1,
                    indent: 40,
                    endIndent: 10,
                  ),
                  // Fecha de la devolución
                  _buildModernDetailRow(
                    'Fecha',
                    _formatDate(widget.devolucion.devoFecha),
                    Icons.calendar_today_outlined,
                  ),
                ],
              ),
            ),
            // Sección de productos a devolver
            const SizedBox(height: 20),
            Text(
              'Productos a devolver:',
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF141A2F),
              ),
            ),
            const SizedBox(height: 10),
            // Contenedor con lista de productos
            Container(
              height: 200, // Altura fija para la lista de productos
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: FutureBuilder<List<DevolucionDetalleModel>>(
                future: _detallesFuture,
                builder: (context, snapshot) {
                  // Estado de carga
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Cargando productos...',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    // Estado de error
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 36,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Error al cargar productos',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    // Estado sin datos
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey,
                            size: 36,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No hay productos para esta devolución',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Mostrar lista de productos
                  final detalles = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: detalles.length,
                    itemBuilder: (context, index) {
                      final detalle = detalles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          title: Text(
                            detalle.prod_Descripcion,
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Categoría: ${detalle.cate_Descripcion}',
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            'Cantidad: 1', // Cantidad fija por detalle
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Botón para cerrar el bottom sheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: CustomButton(
                text: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                width: double.infinity,
                height: 56,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una fila de detalle con icono, etiqueta y valor
  /// Utilizado para mostrar información de la devolución de forma consistente
  Widget _buildModernDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono con fondo de color
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0C7A0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFE0C7A0)),
          ),
          const SizedBox(width: 12),
          // Etiqueta y valor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Etiqueta del campo
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                // Valor del campo
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 15,
                    color: Color(0xFF141A2F),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formatea una fecha en formato DD/MM/YYYY HH:MM
  String _formatDate(DateTime? date) {
    return '${_twoDigits(date?.day ?? 0)}/${_twoDigits(date?.month ?? 0)}/${date?.year ?? 0} ${_twoDigits(date?.hour ?? 0)}:${_twoDigits(date?.minute ?? 0)}';
  }

  /// Convierte un número a string con dos dígitos (agrega cero a la izquierda si es necesario)
  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// Función auxiliar para precargar detalles antes de mostrar el bottom sheet
/// Intenta sincronizar los detalles desde el servidor si hay conexión

// Función auxiliar para precargar detalles antes de mostrar la hoja
Future<void> _precargarDetalles(DevolucionesViewModel devolucion) async {
  try {
    // Verificar si hay conexión a internet
    final tieneConexion = await VerificarService.verificarConexion();
    if (tieneConexion) {
      print('Precargando detalles para devolución ID: ${devolucion.devoId}');

      // Obtener detalles directamente desde el servidor
      final service = DevolucionesService();
      final detallesServidor = await service.getDevolucionDetalles(
        devolucion.devoId,
      );

      // Convertir detalles a formato JSON para almacenamiento
      final List<Map<String, dynamic>> detallesMap = detallesServidor
          .map((detalle) => detalle.toJson())
          .toList();

      if (detallesMap.isNotEmpty) {
        // Guardar los detalles en almacenamiento local
        await DevolucionesOffline.guardarDetallesDevolucion(
          devolucion.devoId,
          detallesMap,
        );
        print(
          '✓ Precarga completada: ${detallesMap.length} detalles guardados para ID: ${devolucion.devoId}',
        );
      } else {
        print(
          '⚠ La precarga no encontró detalles en el servidor para ID: ${devolucion.devoId}',
        );
      }

      // Verificar los detalles guardados (debug)
      await DevolucionesOffline.imprimirDetallesDevolucionesGuardados();
    } else {
      print(
        'Sin conexión, no se puede precargar detalles para ID: ${devolucion.devoId}',
      );
    }
  } catch (e) {
    print('Error en precarga de detalles para ID ${devolucion.devoId}: $e');
    // Continuar a pesar del error
  }
}

/// Función principal para mostrar el bottom sheet de detalles de devolución
/// Precarga los detalles antes de mostrar la interfaz

void showDevolucionDetalleBottomSheet({
  required BuildContext context,
  required DevolucionesViewModel devolucion,
}) async {
  // Precargar los detalles antes de mostrar el bottom sheet
  // Se hace de forma transparente para el usuario (sin indicador de carga)
  _precargarDetalles(devolucion).then((_) {
    // Mostrar el bottom sheet después de intentar la precarga
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          DevolucionDetalleBottomSheet(devolucion: devolucion),
    );
  });
}
