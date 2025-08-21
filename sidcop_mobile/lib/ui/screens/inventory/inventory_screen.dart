import 'package:flutter/material.dart';
import '../../widgets/appBackground.dart';
import '../../../models/inventory_item.dart';
import '../../../services/inventory_service.dart';
import '../../../services/PerfilUsuarioService.dart';

class InventoryScreen extends StatefulWidget {
  final int usuaIdPersona;

  const InventoryScreen({super.key, required this.usuaIdPersona});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sellerName = 'Cargando...';
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
    _loadSellerName();
  }

  Future<void> _loadInventoryData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final items = await InventoryService().getInventoryByVendor(
        widget.usuaIdPersona,
      );

      setState(() {
        _inventoryItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSellerName() async {
    try {
      // Try to get name from nombres and apellidos fields
      final userData = await _perfilUsuarioService.obtenerDatosUsuario();
      if (userData != null) {
        final nombres = userData['nombres'] ?? '';
        final apellidos = userData['apellidos'] ?? '';

        if (nombres.isNotEmpty && apellidos.isNotEmpty) {
          setState(() {
            _sellerName = '$nombres $apellidos';
          });
          return;
        } else if (nombres.isNotEmpty) {
          setState(() {
            _sellerName = nombres;
          });
          return;
        } else if (apellidos.isNotEmpty) {
          setState(() {
            _sellerName = apellidos;
          });
          return;
        }
      }

      // Fallback to existing method
      final name = await _perfilUsuarioService.obtenerNombreCompleto();
      setState(() {
        _sellerName = name;
      });
    } catch (e) {
      setState(() {
        _sellerName = 'Usuario';
      });
    }
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final weekday = weekdays[now.weekday - 1];
    final day = now.day;
    final month = months[now.month - 1];
    final year = now.year;

    return '$weekday, $day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Inventario',
      icon: Icons.inventory_2,
      onRefresh: () async {
        _loadInventoryData();
        _loadSellerName();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de Jornada
            _buildDayHeader(),
            const SizedBox(height: 24),

            // Inventario Asignado del Día
            _buildAssignedInventory(),
            const SizedBox(height: 24),

            // Gestión de Movimientos
            _buildMovementsManagement(),
            const SizedBox(height: 24),

            // Resumen del Día
            _buildDailySummary(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader() {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1A2332).withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E2A3D),
              Color(0xFF1A2332),
              Color(0xFF141A2F),
              Color(0xFF0F1419),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Efectos de fondo decorativos
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC2AF86).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC2AF86).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header superior con fecha y estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información de fecha
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC2AF86).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFC2AF86).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.today_rounded,
                                        color: const Color(0xFFC2AF86),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Jornada Activa',
                                        style: TextStyle(
                                          color: Color(0xFFC2AF86),
                                          fontFamily: 'Satoshi',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatCurrentDate(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Satoshi',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF4CAF50),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'En línea • ${_getCurrentTime()}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontFamily: 'Satoshi',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Ícono de notificaciones
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              // Acción de notificaciones
                            },
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // Información del vendedor mejorada
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar mejorado del vendedor
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFC2AF86),
                                Color(0xFFB8A47A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC2AF86).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        
                        const SizedBox(width: 18),

                        // Información del vendedor
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _sellerName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Satoshi',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      'Activo',
                                      style: TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontFamily: 'Satoshi',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.badge_outlined,
                                        color: Colors.white.withOpacity(0.6),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'ID: ${widget.usuaIdPersona}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontFamily: 'Satoshi',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.white.withOpacity(0.6),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Zona Centro',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontFamily: 'Satoshi',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Método auxiliar para obtener la hora actual
String _getCurrentTime() {
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFC2AF86), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Satoshi',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontFamily: 'Satoshi',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedInventory() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC2AF86)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error al cargar inventario',
              style: const TextStyle(
                color: Colors.red,
                fontFamily: 'Satoshi',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontFamily: 'Satoshi',
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInventoryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2AF86),
                foregroundColor: const Color(0xFF141A2F),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título y resumen
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inventario Asignado',
              style: TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontFamily: 'Satoshi',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC2AF86).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC2AF86), width: 1),
              ),
              child: Text(
                '${_inventoryItems.length} productos',
                style: const TextStyle(
                  color: Color(0xFFC2AF86),
                  fontFamily: 'Satoshi',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lista de productos
        ..._inventoryItems.map((item) => _buildInventoryItemCard(item)),
      ],
    );
  }

  // Método auxiliar para obtener el icono del producto
  Widget _getProductIcon(String subcDescripcion) {
    IconData productIcon = Icons.inventory;
    if (subcDescripcion.toLowerCase().contains('bebida')) {
      productIcon = Icons.local_drink;
    } else if (subcDescripcion.toLowerCase().contains('panaderia')) {
      productIcon = Icons.bakery_dining;
    } else if (subcDescripcion.toLowerCase().contains('snack')) {
      productIcon = Icons.fastfood;
    }

    return Icon(productIcon, color: const Color(0xFF141A2F), size: 30);
  }


Widget _buildInventoryItemCard(InventoryItem item) {
  // Validar y sanitizar los valores numéricos
  final int assigned = item.cantidadAsignada ?? 0;
  final int current = item.currentQuantity ?? 0;
  final int sold = item.soldQuantity ?? 0;
  
  // Calcular el porcentaje de forma segura
  double percentage = 0.0;
  if (assigned > 0) {
    percentage = (assigned - current) / assigned;
  }
  
  // Asegurar que el porcentaje esté en el rango válido [0.0, 1.0]
  percentage = percentage.clamp(0.0, 1.0);
  
  // Validar que percentage no sea NaN o infinito
  if (percentage.isNaN || percentage.isInfinite) {
    percentage = 0.0;
  }

  final Color statusColor = item.statusColor ?? Colors.grey;
  final String statusText = item.statusText ?? 'Sin estado';

  // Widget para la imagen del producto
  Widget productImage = item.prodImagen != null && item.prodImagen.isNotEmpty
      ? ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            item.prodImagen,
            width: 55,
            height: 55,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _getProductIcon(item.subcDescripcion ?? '');
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: const Color(0xFFC2AF86),
                    strokeWidth: 2,
                  ),
                ),
              );
            },
          ),
        )
      : Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(14),
          ),
          child: _getProductIcon(item.subcDescripcion ?? ''),
        );

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 2,
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            productImage,
            const SizedBox(width: 16),

            // Información del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombreProducto ?? 'Producto sin nombre',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Código: ${item.codigoProducto ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subcDescripcion ?? 'Sin categoría',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Estado y precio
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontFamily: 'Satoshi',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'L.${(item.precio ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontFamily: 'Satoshi',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Cantidades y estadísticas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatText('Asignado', assigned.toString(), Colors.grey[600]!),
            _buildStatText('Actual', current.toString(), Colors.black),
            _buildStatText('Vendido', sold.toString(), const Color(0xFFC2AF86)),
          ],
        ),
        const SizedBox(height: 12),

        // Barra de progreso mejorada
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso de ventas',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${(percentage * 100).toInt()}%',
                  style: TextStyle(
                    color: statusColor,
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Validación adicional para evitar valores NaN
                  final double validWidth = constraints.maxWidth;
                  final double progressWidth = validWidth * percentage;
                  
                  // Asegurar que el ancho calculado sea válido
                  final double finalWidth = progressWidth.isNaN || 
                                          progressWidth.isInfinite || 
                                          progressWidth < 0
                      ? 0.0 
                      : progressWidth.clamp(0.0, validWidth);

                  return Stack(
                    children: [
                      Container(
                        width: finalWidth,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor,
                              statusColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Widget auxiliar mejorado para textos de estadísticas
Widget _buildStatText(String label, String value, Color color) {
  return Flexible(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontFamily: 'Satoshi',
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontFamily: 'Satoshi',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}



  Widget _buildMovementsManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gestión de Movimientos',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontFamily: 'Satoshi',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // Botones de acciones rápidas
        Row(
          children: [
            Expanded(
              child: _buildMovementButton(
                icon: Icons.shopping_cart,
                label: 'Nueva venta',
                color: Colors.green,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMovementButton(
                icon: Icons.keyboard_return,
                label: 'Devolución',
                color: Colors.blue,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        // Historial de movimientos recientes
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2A3A), Color(0xFF1A2332)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFC2AF86).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Movimientos Recientes',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC2AF86).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFC2AF86),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: const Text(
                        'Ver todos',
                        style: TextStyle(
                          color: Color(0xFFC2AF86),
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista de movimientos
              _buildMovementItem(
                type: 'Venta',
                product: 'Coca Cola 600ml',
                quantity: -2,
                time: '10:30 AM',
                icon: Icons.shopping_cart,
                color: Colors.green,
              ),
              _buildMovementItem(
                type: 'Venta',
                product: 'Papas Lays Original',
                quantity: -1,
                time: '10:15 AM',
                icon: Icons.shopping_cart,
                color: Colors.green,
              ),
              _buildMovementItem(
                type: 'Ajuste',
                product: 'Agua Mineral 500ml',
                quantity: 1,
                time: '09:45 AM',
                icon: Icons.tune,
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovementButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMovementItem({
    required String type,
    required String product,
    required int quantity,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type - $product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: quantity > 0 ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (quantity > 0 ? Colors.green : Colors.red).withOpacity(
                    0.3,
                  ),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              quantity > 0 ? '+$quantity' : '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen del Día',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontFamily: 'Satoshi',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // Métricas principales
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2A3A), Color(0xFF1A2332)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFC2AF86).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Fila superior de métricas
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      icon: Icons.shopping_cart,
                      label: 'Productos Vendidos',
                      value: '33',
                      total: '69',
                      color: Colors.green,
                      percentage: 0.48,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryMetric(
                      icon: Icons.attach_money,
                      label: 'Dinero Recaudado',
                      value: '\$127.50',
                      total: '\$172.50',
                      color: const Color(0xFFC2AF86),
                      percentage: 0.74,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fila inferior de métricas
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      icon: Icons.keyboard_return,
                      label: 'Por Devolver',
                      value: '36',
                      total: '69',
                      color: Colors.blue,
                      percentage: 0.52,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryMetric(
                      icon: Icons.trending_up,
                      label: 'Eficiencia',
                      value: '74%',
                      total: '100%',
                      color: Colors.orange,
                      percentage: 0.74,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required String total,
    required Color color,
    required double percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                '${(percentage * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Satoshi',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Satoshi',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Satoshi',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),

          Text(
            'de $total',
            style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'Satoshi',
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          // Barra de progreso
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1419),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [color, color.withOpacity(0.8)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
