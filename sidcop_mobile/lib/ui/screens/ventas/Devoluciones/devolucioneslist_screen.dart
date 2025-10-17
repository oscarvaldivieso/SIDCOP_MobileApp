// Importaciones necesarias para la pantalla de lista de devoluciones
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/ProductosService.Dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/Offline_Services/Devoluciones_OfflineServices.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucion_detalle_bottom_sheet.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucioncrear_screen.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';

/// Pantalla que muestra el listado de devoluciones
/// Soporta modo online y offline con sincronización automática
class DevolucioneslistScreen extends StatefulWidget {
  const DevolucioneslistScreen({super.key});

  @override
  State<DevolucioneslistScreen> createState() => _DevolucioneslistScreenState();
}

/// Estado que maneja la lógica y la interfaz de la pantalla de lista de devoluciones
class _DevolucioneslistScreenState extends State<DevolucioneslistScreen>
    with WidgetsBindingObserver {
  // Future que contiene la lista de devoluciones
  late Future<List<DevolucionesViewModel>> _devolucionesFuture;
  
  // Permisos del usuario
  List<dynamic> permisos = [];
  
  // Indicador de estado de conexión a internet
  bool isOnline = true;
  
  // Evita ejecutar prefetch repetidamente
  bool _prefetchCompleted = false;
  
  // Indica si se está sincronizando devoluciones pendientes
  bool _isSyncingPendientes = false;
  
  // Último estado de conexión conocido
  bool? _lastConnectionState;

  // Devoluciones pendientes locales (creadas offline)
  final Set<int> _pendingDevolucionesIds = <int>{};
  final Map<int, String> _pendingMessages = {};
  
  // Numeración de pendientes para mostrar en la UI
  final Map<int, int> _pendingDisplayNumber = {};

  /// Verifica la conexión a internet y sincroniza pendientes si se detecta reconexión
  /// Retorna true si hay conexión, false en caso contrario
  Future<bool> verificarConexion() async {
    try {
      final tieneConexion = await VerificarService.verificarConexion();
      // Detectar transición offline -> online para sincronizar pendientes
      if (_lastConnectionState == false && tieneConexion == true) {
        // Evitar sincronizaciones múltiples simultáneas
        if (!_isSyncingPendientes) {
          _isSyncingPendientes = true;
          try {
            print(
              'Transición: Offline -> Online detectada, sincronizando pendientes...',
            );
            // Sincronizar devoluciones pendientes con el servidor
            final resultado =
                await DevolucionesOffline.sincronizarPendientesDevoluciones();
            print('Resultado sincronización pendientes: $resultado');
            // Recargar el listado después de sincronizar
            if (mounted) {
              setState(() {
                _devolucionesFuture = _loadDevoluciones();
              });
              // Mostrar mensaje de éxito si se sincronizaron devoluciones
              try{
                final int sincronizados = (resultado['success'] ?? 0);
                if (sincronizados > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ' $sincronizados devoluciones sincronizadas',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (_) {}
            }
          } catch (e) {
            print('Error sincronizando pendientes tras reconexión: $e');
          } finally {
            _isSyncingPendientes = false;
          }
        }
      }

      // Actualizar el último estado de conexión conocido
      _lastConnectionState = tieneConexion;
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
    // Registrar observador del ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
    // Cargar permisos del usuario
    _loadPermisos();
    // Inicializar Future inmediatamente para evitar errores
    _devolucionesFuture = _loadDevoluciones();
    // Actualizar datos según el estado de conexión
    _actualizarDatosSegunConexion();
    print('DevolucioneslistScreen initialized');
  }

  @override
  void dispose() {
    // Remover observador del ciclo de vida
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al regresar a la app, verificar conexión y sincronizar
    if (state == AppLifecycleState.resumed) {
      _actualizarDatosSegunConexion();
    }
    super.didChangeAppLifecycleState(state);
  }

  /// Actualiza los datos de devoluciones según el estado de conexión
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

  /// Carga los permisos del usuario desde el perfil

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
      // Ya no verificamos la conexión aquí, usamos el estado actual de isOnline
      // que se actualiza mediante el método verificarConexion()
      List<DevolucionesViewModel> devoluciones = [];

      // Cargar devoluciones pendientes locales y prepararlas para mostrarse
      try {
        // Asegurar que las devoluciones pendientes tengan un ID asignado
        await DevolucionesOffline.PendientesTenganId();
      } catch (_) {}
      _pendingDevolucionesIds.clear();
      _pendingMessages.clear();
      final List<DevolucionesViewModel> _pendingModels = [];
      try {
        final pendingLocal =
            await DevolucionesOffline.obtenerDevolucionesPendientesLocal();
        if (pendingLocal.isNotEmpty) {
          for (int i = 0; i < pendingLocal.length; i++) {
            final pendingMap = Map<String, dynamic>.from(pendingLocal[i]);

            // Asegurar campos mínimos para convertir a modelo
            if (!pendingMap.containsKey('devo_Fecha')) {
              pendingMap['devo_Fecha'] = DateTime.now().toIso8601String();
            }
            if (!pendingMap.containsKey('devo_Motivo')) {
              pendingMap['devo_Motivo'] =
                  pendingMap['devo_Motivo'] ?? 'Devolución pendiente (offline)';
            }

            try {
              final model = DevolucionesViewModel.fromJson(pendingMap);
              // no agregamos aún a 'devoluciones' para evitar sobreescritura por la carga del servidor
              _pendingModels.add(model);
              _pendingDevolucionesIds.add(model.devoId);
              _pendingMessages[model.devoId] = 'Devolución pendiente';
              // Asignar número de visualización según el orden en el almacenamiento local (1..N)
              _pendingDisplayNumber[model.devoId] = i + 1;
            } catch (e) {
              // si falla la conversión, omitir pero intentar conservar el registro en pendientes
            }
          }
        }
      } catch (debugErr) {
        // no bloquear si falla la lectura de pendientes
      }

      // Sincronizar y guardar devoluciones pasando el estado de conexión actual
      final devolucionesData =
          await DevolucionesOffline.sincronizarYGuardarDevoluciones(
            forzarSincronizacionDetalles:
                isOnline, // Solo sincronizar detalles si estamos online
            isOnline:
                isOnline, // Pasar el estado de conexión para que el método sepa si debe obtener del servidor o localmente
          );

      if (isOnline) {
        try {
          await DevolucionesOffline.guardarDevolucionesHistorial(
            devolucionesData,
          );
        } catch (saveErr) {}
      }

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

      // If online, attempt to sync pending devoluciones that were saved offline
      if (isOnline) {
        try {
          final resultadoPendientes =
              await DevolucionesOffline.sincronizarPendientesDevoluciones();
          print(
            'DEBUG: Resultado sincronización pendientes: $resultadoPendientes',
          );
        } catch (e) {
          print('DEBUG: Error sincronizando pendientes: $e');
        }
      }

      if (isOnline) {
        // Si estamos online, sincronizar detalles para todas las devoluciones
        print(
          'Modo online: Sincronizando detalles para todas las devoluciones...',
        );

        // Obtener facturas por límite de devoluciones, filtrar por vendedor
        // actual (GlobalService.globalVendId), deduplicar fact_Id, comprobar
        // caché y prefetch con concurrencia limitada y tope (top-N).
        // Ejecutar prefetch una sola vez por instancia de pantalla
        if (!_prefetchCompleted) {
          _prefetchCompleted = true;
          try {
            final facturaService = FacturaService();
            final facturasData = await facturaService
                .getFacturasDevolucionesLimite();

            // Guardar las facturas obtenidas localmente para uso en la pantalla de crear
            try {
              if (facturasData.isNotEmpty) {
                final List<Map<String, dynamic>> facturasToSave = facturasData
                    .map<Map<String, dynamic>>((f) {
                      if (f is Map) return Map<String, dynamic>.from(f);
                      try {
                        // Algunos servicios devuelven objetos con toJson()
                        final dynamic json = f.toJson();
                        if (json is Map) return Map<String, dynamic>.from(json);
                      } catch (_) {}
                      return <String, dynamic>{};
                    })
                    .toList();

                if (facturasToSave.isNotEmpty) {
                  await DevolucionesOffline.guardarFacturasCreate(
                    facturasToSave,
                  );
                  print(
                    'Facturas guardadas localmente (${facturasToSave.length})',
                  );
                }
              }
            } catch (saveErr) {
              print('Error guardando facturas localmente: $saveErr');
            }

            final int? vendIdActual = globalVendId; // desde GlobalService
            final Set<int> factIdsSet = {};

            for (var f in facturasData) {
              try {
                final dynamic vendVal = f['vend_Id'] ?? f['vendId'];
                final int? vend = vendVal != null
                    ? int.tryParse(vendVal.toString())
                    : null;
                if (vend != null &&
                    vendIdActual != null &&
                    vend == vendIdActual) {
                  final dynamic fid = f['fact_Id'] ?? f['factId'];
                  if (fid != null) {
                    final int? factId = int.tryParse(fid.toString());
                    if (factId != null) factIdsSet.add(factId);
                  }
                }
              } catch (inner) {}
            }

            // Usar todos los IDs deduplicados retornados por el endpoint
            final List<int> factIdsToConsider = factIdsSet.toList();

            // Filtrar facturas que ya están cacheadas
            final List<int> toFetch = [];
            for (final id in factIdsToConsider) {
              try {
                final cached =
                    await DevolucionesOffline.obtenerProductosPorFacturaLocal(
                      id,
                    );
                // Si la caché está vacía, considerarla no cacheada
                if (cached.isEmpty) {
                  toFetch.add(id);
                }
              } catch (cacheErr) {
                print('Error comprobando cache para factura $id: $cacheErr');
                toFetch.add(id); // si falla la comprobación, intentar descargar
              }
            }

            // Descarga con concurrencia limitada
            final int concurrency = 5;
            final productosService = ProductosService();
            for (int i = 0; i < toFetch.length; i += concurrency) {
              final batch = toFetch.sublist(
                i,
                (i + concurrency) > toFetch.length
                    ? toFetch.length
                    : (i + concurrency),
              );
              await Future.wait(
                batch.map((factId) async {
                  try {
                    print(
                      'Obteniendo productos para factura $factId (prefetch)',
                    );
                    final productosPorFactura = await productosService
                        .getProductosPorFactura(factId);
                    if (productosPorFactura.isNotEmpty) {
                      await DevolucionesOffline.guardarProductosPorFactura(
                        factId,
                        productosPorFactura,
                      );
                    }
                  } catch (err) {
                    print('Error prefetch productos factura $factId: $err');
                  }
                }),
              );
            }
          } catch (e) {
            print('Error general al prefetch productos por factura: $e');
          }
        }

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

            // Asegurar que los productos de la factura asociada a esta devolución
            // estén guardados localmente (incluye descargar imágenes).
            try {
              final factId = devolucion.factId;
              if (factId != null) {
                final cachedProducts =
                    await DevolucionesOffline.obtenerProductosPorFacturaLocal(
                      factId,
                    );
                if (cachedProducts.isEmpty) {
                  try {
                    final productosService = ProductosService();
                    final productosPorFactura = await productosService
                        .getProductosPorFactura(factId);
                    if (productosPorFactura.isNotEmpty) {
                      await DevolucionesOffline.guardarProductosPorFactura(
                        factId,
                        productosPorFactura,
                      );
                      print(
                        'Productos (y sus imágenes) guardados para factura $factId desde la lista de devoluciones',
                      );
                    }
                  } catch (prodErr) {
                    print(
                      'Error obteniendo productos para factura $factId: $prodErr',
                    );
                  }
                }
              }
            } catch (ensureErr) {
              print(
                'Error asegurando productos para devolucion ${devolucion.devoId}: $ensureErr',
              );
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

      // Si estamos online, filtrar devoluciones pendientes que ya fueron sincronizadas
      if (isOnline && _pendingDevolucionesIds.isNotEmpty) {
        final endpointIds = devoluciones.map((d) => d.devoId).toSet();
        _pendingDevolucionesIds.removeWhere((id) => endpointIds.contains(id));
      }

      // Merge pending devoluciones into the final list using the original pending models
      // Pendientes no sincronizados deben ir al inicio (top) de la lista
      if (_pendingModels.isNotEmpty) {
        final toPrepend = _pendingModels
            .where((m) => _pendingDevolucionesIds.contains(m.devoId))
            .toList();
        if (toPrepend.isNotEmpty) {
          devoluciones = [...toPrepend, ...devoluciones];
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
        onPressed: () async {
          // Actualizar el estado de conexión en background y navegar automáticamente.
          await verificarConexion();
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
          if (devolucion.devoId < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pendiente de sincronizar'),
                backgroundColor: Color.fromARGB(255, 97, 97, 97),
              ),
            );
            return;
          }
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
                                devolucion.devoId > 0
                                    ? 'Devolución #${devolucion.devoId}'
                                    : (_pendingDisplayNumber[devolucion
                                                  .devoId] !=
                                              null
                                          ? 'Devolución pendiente #${_pendingDisplayNumber[devolucion.devoId]}'
                                          : 'Devolución pendiente'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              // No mostrar el mensaje visual aquí
                            ],
                          ),
                        ),
                        // Si es una devolución pendiente, mostrar botón de borrar
                        if (devolucion.devoId < 0)
                          IconButton(
                            onPressed: () async {
                              // Confirmar eliminación
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text(
                                    'Eliminar devolución pendiente',
                                  ),
                                  content: const Text(
                                    '¿Estás seguro de que quieres eliminar esta devolución pendiente? Esta acción no se puede deshacer.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final success =
                                    await DevolucionesOffline.eliminarDevolucionPendiente(
                                      devolucion.devoId,
                                    );
                                if (mounted) {
                                  setState(() {
                                    _devolucionesFuture = _loadDevoluciones();
                                  });
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Devolución pendiente eliminada'
                                          : 'No se pudo eliminar la devolución pendiente',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          )
                        else
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
                        _buildDetailRow(
                          Icons.business_outlined,
                          'Cliente',
                          devolucion.clieNombreNegocio ?? 'Cliente desconocido',
                        ),
                        const SizedBox(height: 8),
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
