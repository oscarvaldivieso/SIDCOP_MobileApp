import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/DevolucionesViewModel.dart';
import 'package:sidcop_mobile/models/devolucion_detalle_model.dart';
import 'package:sidcop_mobile/Offline_Services/Devoluciones_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';

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
  bool isOnline = true;

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
      setState(() {
        isOnline = tieneConexion;
      });
      print(
        'Estado de conexión en detalles: ${tieneConexion ? 'Online' : 'Offline'}',
      );
      return tieneConexion;
    } catch (e) {
      print('Error al verificar la conexión en detalles: $e');
      setState(() {
        isOnline = false;
      });
      return false;
    }
  }

  // Cargar datos con manejo de modo offline
  Future<void> _cargarDatos() async {
    // Verificar conexión primero
    isOnline = await verificarConexion();

    // Usar setState para actualizar la UI cuando la conexión cambia
    setState(() {
      // Inicializar _detallesFuture para evitar errores
      _detallesFuture = _cargarDetallesDevolucion();
    });
  }

  // Método para cargar detalles con manejo online/offline
  Future<List<DevolucionDetalleModel>> _cargarDetallesDevolucion() async {
    try {
      // Asegurarnos de que tenemos un ID válido
      int devolucionId = widget.devolucion.devoId;
      print('Intentando cargar detalles para devolución ID: $devolucionId');

      List<DevolucionDetalleModel> detalles = [];

      if (isOnline) {
        try {
          print('Cargando detalles de devolución online ID: $devolucionId');
          // Si hay conexión, obtenemos datos del servidor y los guardamos localmente
          final detallesData =
              await DevolucionesOffline.sincronizarYGuardarDetallesDevolucion(
                devolucionId,
              );

          // Convertimos a modelos con manejo de errores para cada elemento
          for (final detalle in detallesData) {
            try {
              detalles.add(DevolucionDetalleModel.fromJson(detalle));
            } catch (conversionError) {
              print('Error al convertir detalle: $conversionError');
              // Continuar con el siguiente elemento
            }
          }

          print(
            'Cargados ${detalles.length} detalles de devolución del servidor',
          );
          if (detalles.isNotEmpty) {
            return detalles;
          }
        } catch (e) {
          print('Error al cargar detalles online: $e');
          // Continuar con el fallback a datos locales
        }
      }

      // Si no hay conexión o falló la carga online, intentar con datos locales
      try {
        print('Cargando detalles de devolución offline ID: $devolucionId');
        final detallesData =
            await DevolucionesOffline.obtenerDetallesDevolucionLocal(
              devolucionId,
            );

        // Convertimos a modelos con manejo de errores para cada elemento
        detalles = [];
        for (final detalle in detallesData) {
          try {
            detalles.add(DevolucionDetalleModel.fromJson(detalle));
          } catch (conversionError) {
            print('Error al convertir detalle local: $conversionError');
            // Continuar con el siguiente elemento
          }
        }

        print(
          'Cargados ${detalles.length} detalles de devolución del almacenamiento local',
        );
        return detalles;
      } catch (localError) {
        print('Error al cargar datos locales: $localError');
      }

      // Si todo falló, devolver lista vacía
      print(
        'No se pudieron cargar detalles para la devolución ID: $devolucionId',
      );
      return [];
    } catch (e) {
      print('Error general en _cargarDetallesDevolucion: $e');
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
                // Pequeño indicador de offline/online y botón de recargar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOnline
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isOnline ? "Online" : "Offline",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isOnline
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          // Reintentar carga de datos
                          _cargarDatos();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          Icons.refresh,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
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

void showDevolucionDetalleBottomSheet({
  required BuildContext context,
  required DevolucionesViewModel devolucion,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DevolucionDetalleBottomSheet(devolucion: devolucion),
  );
}
