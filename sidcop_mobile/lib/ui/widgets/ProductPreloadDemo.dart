import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/UsuarioService.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';

/// Widget para mostrar el estado de la precarga de productos
class ProductPreloadDemo extends StatefulWidget {
  const ProductPreloadDemo({super.key});

  @override
  State<ProductPreloadDemo> createState() => _ProductPreloadDemoState();
}

class _ProductPreloadDemoState extends State<ProductPreloadDemo> {
  final UsuarioService _usuarioService = UsuarioService();
  Map<String, dynamic> _preloadInfo = {};

  @override
  void initState() {
    super.initState();
    _updatePreloadInfo();
  }

  void _updatePreloadInfo() {
    setState(() {
      _preloadInfo = _usuarioService.obtenerEstadoPrecarga();
    });
    // Actualizar periódicamente el estado
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _updatePreloadInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPreloaded = _preloadInfo['isPreloaded'] ?? false;
    final isPreloading = _preloadInfo['isPreloading'] ?? false;
    final productsCount = _preloadInfo['productsCount'] ?? 0;
    final imagesWithUrl = _preloadInfo['imagesWithUrl'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              const Icon(Icons.cached, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Estado de Precarga de Productos',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Estado actual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPreloaded 
                ? Colors.green.withOpacity(0.1)
                : isPreloading 
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPreloaded 
                  ? Colors.green
                  : isPreloading 
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPreloaded 
                    ? Icons.check_circle
                    : isPreloading 
                      ? Icons.hourglass_empty
                      : Icons.info_outline,
                  color: isPreloaded 
                    ? Colors.green
                    : isPreloading 
                      ? Colors.orange
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPreloaded 
                      ? '✅ Productos precargados'
                      : isPreloading 
                        ? '⏳ Precarga en progreso...'
                        : '⚪ Sin precargar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Satoshi',
                      color: isPreloaded 
                        ? Colors.green[700]
                        : isPreloading 
                          ? Colors.orange[700]
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Estadísticas
          if (isPreloaded || isPreloading) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Productos',
                  productsCount.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Con Imagen',
                  imagesWithUrl.toString(),
                  Icons.image,
                  Colors.purple,
                ),
              ],
            ),
          ],

          // Información adicional
          const SizedBox(height: 8),
          Text(
            'ℹ️ La precarga se ejecuta automáticamente al activar el modo online.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Satoshi',
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Satoshi',
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
