import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';
import 'package:sidcop_mobile/Offline_Services/Devoluciones_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';

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
  // Inicializando con un Future vacío para evitar problemas de late initialization
  Future<List<DevolucionDetalleModel>> _detallesFuture = Future.value([]);
  // bool isOnline = true; // Eliminado indicador online/offline

  @override
  void initState() {
    super.initState();
    // Cargar los datos inmediatamente
    _cargarDatos();
  }

  // Verificar conexión a internet
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

  // Cargar datos con manejo de modo offline
  Future<void> _cargarDatos() async {
    // Verificar conexión primero
    final tieneConexion = await verificarConexion();

    // Si hay conexión, intentar sincronizar detalles específicos primero
    if (tieneConexion) {
      try {
        print(
          'Hay conexión, sincronizando detalles para devolución ID: ${widget.devolucion.devoId}',
        );

        // Forzar una sincronización fresca desde el servidor
        final service = DevolucionesService();
        final detalles = await service.getDevolucionDetalles(
          widget.devolucion.devoId,
        );

        if (detalles.isNotEmpty) {
          print('Se obtuvieron ${detalles.length} detalles del servidor');

          // Convertir y guardar manualmente
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
      print('Sin conexión, se cargarán datos del almacenamiento local');
    }

    // Usar setState para actualizar la UI cuando la conexión cambia
    if (mounted) {
      setState(() {
        // Inicializar _detallesFuture para evitar errores
        _detallesFuture = _cargarDetallesDevolucion();
      });
    }
  }

  // Método para cargar detalles con manejo online/offline
  Future<List<DevolucionDetalleModel>> _cargarDetallesDevolucion() async {
    try {
      // Asegurarnos de que tenemos un ID válido
      int devolucionId = widget.devolucion.devoId;
      print('Intentando cargar detalles para devolución ID: $devolucionId');

      List<DevolucionDetalleModel> detalles = [];

      // Verificar conexión
      final tieneConexion = await verificarConexion();
      print(
        'Estado de conexión al cargar detalles: ${tieneConexion ? 'Online' : 'Offline'}',
      );

      // Comprobar primero si ya tenemos detalles en el almacenamiento local
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

      // ENFOQUE MEJORADO: Usar el método sincronizarYGuardarDetallesDevolucion con parámetros adecuados
      try {
        print(
          'Usando enfoque optimizado para cargar detalles de la devolución ID: $devolucionId',
        );

        // Si estamos online y no tenemos detalles locales, o estamos forzando una actualización
        // forzar sincronización, de lo contrario usar caché local
        final forceSync = tieneConexion && !tieneDetallesLocales;

        print(
          'Estrategia: ${tieneConexion ? 'Online' : 'Offline'}, ${forceSync ? 'Forzar sincronización' : 'Usar caché si está disponible'}',
        );

        // Usar el método mejorado que maneja todos los escenarios
        final List<Map<String, dynamic>> detallesData =
            await DevolucionesOffline.sincronizarYGuardarDetallesDevolucion(
              devolucionId,
              isOnline: tieneConexion, // Pasar estado de conexión
              forceSync: forceSync, // Forzar solo si es necesario
            );

        // Convertir a modelos con manejo de errores para cada elemento
        int exitosos = 0;
        int errores = 0;

        for (int i = 0; i < detallesData.length; i++) {
          try {
            final detalle = detallesData[i];
            detalles.add(DevolucionDetalleModel.fromJson(detalle));
            exitosos++;
          } catch (conversionError) {
            errores++;
            print('❌ Error al convertir detalle #$i: $conversionError');

            // Mostrar información de diagnóstico
            try {
              final detalle = detallesData[i];
              print('Claves disponibles: ${detalle.keys.toList()}');
              if (detalle.containsKey('prod_Id')) {
                print('ID del producto: ${detalle['prod_Id']}');
              }
              if (detalle.containsKey('prod_Descripcion')) {
                print(
                  'Descripción del producto: ${detalle['prod_Descripcion']}',
                );
              }
            } catch (e) {
              print(
                'Error al mostrar diagnóstico del detalle problemático: $e',
              );
            }
          }
        }

        print('Resultado de conversión: $exitosos exitosos, $errores fallidos');

        // Recuperación en caso de no encontrar detalles
        if (detalles.isEmpty && tieneConexion) {
          print(
            '⚠ No se encontraron detalles utilizando el método principal. Intentando recuperación directa...',
          );

          try {
            // Último intento de recuperación directamente del servidor
            final service = DevolucionesService();
            final detallesServidor = await service.getDevolucionDetalles(
              devolucionId,
            );

            if (detallesServidor.isNotEmpty) {
              print(
                '✓ Recuperación exitosa: ${detallesServidor.length} detalles obtenidos directamente',
              );

              // También guardarlos para futuras consultas
              final detallesMap = detallesServidor
                  .map((d) => d.toJson())
                  .toList();
              await DevolucionesOffline.guardarDetallesDevolucion(
                devolucionId,
                detallesMap,
              );

              return detallesServidor;
            }
          } catch (emergencyError) {
            print('❌ Error en recuperación directa: $emergencyError');
          }
        }

        print(
          '✓ Cargados ${detalles.length} detalles de devolución para ID: $devolucionId',
        );
        return detalles;
      } catch (syncError) {
        print('❌ Error en el enfoque optimizado: $syncError');

        // Plan B: Intentar directamente con los métodos individuales
        print('🔄 Cambiando al enfoque de respaldo...');

        // Si estamos online, intentar sincronizar desde el servidor
        if (tieneConexion) {
          try {
            print('Intentando obtener detalles directamente del servidor...');

            final service = DevolucionesService();
            final detallesServidor = await service.getDevolucionDetalles(
              devolucionId,
            );

            if (detallesServidor.isNotEmpty) {
              print(
                '✓ Se obtuvieron ${detallesServidor.length} detalles del servidor',
              );

              // Convertir y guardar
              try {
                final detallesMap = detallesServidor
                    .map((d) => d.toJson())
                    .toList();
                await DevolucionesOffline.guardarDetallesDevolucion(
                  devolucionId,
                  detallesMap,
                );
                print('✓ Detalles guardados localmente para uso futuro');
              } catch (e) {
                print('Error al guardar detalles localmente: $e');
              }

              return detallesServidor;
            } else {
              print('El servidor no devolvió detalles para la devolución');
            }
          } catch (e) {
            print('Error al obtener detalles del servidor: $e');
          }
        }

        // Intentar cargar desde almacenamiento local como último recurso
        try {
          print('Intentando cargar desde almacenamiento local...');

          final detallesData =
              await DevolucionesOffline.obtenerDetallesDevolucionLocal(
                devolucionId,
                isOnline: false,
              );

          // Convertir a modelos
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

      // Si todo ha fallado, mostramos un mensaje y devolvemos lista vacía
      if (detalles.isEmpty) {
        print(
          '⚠ No se pudieron cargar detalles para la devolución ID: $devolucionId',
        );
        // La UI ya maneja correctamente el caso de lista vacía mostrando un mensaje apropiado
      }

      return detalles;
    } catch (e) {
      print('❌ Error general en _cargarDetallesDevolucion: $e');
      print('Stacktrace: ${e is Error ? e.stackTrace : ''}');
      return []; // Devolver lista vacía en caso de cualquier error no manejado
    }
  }

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
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
                  _buildModernDetailRow(
                    'Fecha',
                    _formatDate(widget.devolucion.devoFecha),
                    Icons.calendar_today_outlined,
                  ),
                ],
              ),
            ),
            // Sección de productos
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
                            'Cantidad: 1', // Asumiendo 1 artículo por detalle de devolución
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

  Widget _buildModernDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0C7A0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFE0C7A0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

  String _formatDate(DateTime? date) {
    return '${_twoDigits(date?.day ?? 0)}/${_twoDigits(date?.month ?? 0)}/${date?.year ?? 0} ${_twoDigits(date?.hour ?? 0)}:${_twoDigits(date?.minute ?? 0)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

// Función auxiliar para precargar detalles antes de mostrar la hoja
Future<void> _precargarDetalles(DevolucionesViewModel devolucion) async {
  try {
    final tieneConexion = await VerificarService.verificarConexion();
    if (tieneConexion) {
      print('Precargando detalles para devolución ID: ${devolucion.devoId}');

      // Intentar obtener detalles directamente desde el servidor
      final service = DevolucionesService();
      final detallesServidor = await service.getDevolucionDetalles(
        devolucion.devoId,
      );

      // Convertir a formato Map para almacenamiento
      final List<Map<String, dynamic>> detallesMap = detallesServidor
          .map((detalle) => detalle.toJson())
          .toList();

      if (detallesMap.isNotEmpty) {
        // Guardar directamente los detalles localmente
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

      // Verificar lo que realmente se guardó
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

void showDevolucionDetalleBottomSheet({
  required BuildContext context,
  required DevolucionesViewModel devolucion,
}) async {
  // Intentar precargar los detalles antes de mostrar la hoja
  // Lo hacemos sin un indicador de carga para que sea transparente para el usuario
  _precargarDetalles(devolucion).then((_) {
    // Mostrar la hoja modal después del intento de precarga
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          DevolucionDetalleBottomSheet(devolucion: devolucion),
    );
  });
}
