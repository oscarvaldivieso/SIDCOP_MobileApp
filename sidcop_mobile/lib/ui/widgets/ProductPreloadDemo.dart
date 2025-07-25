import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/UsuarioService.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';

/// Widget de demostración para mostrar el estado y funcionalidad de la precarga de productos
class ProductPreloadDemo extends StatefulWidget {
  const ProductPreloadDemo({super.key});

  @override
  State<ProductPreloadDemo> createState() => _ProductPreloadDemoState();
}

class _ProductPreloadDemoState extends State<ProductPreloadDemo> {
  final UsuarioService _usuarioService = UsuarioService();
  bool _isLoading = false;
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
  }

  Future<void> _startManualPreload() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _usuarioService.precargarProductos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? '✅ Precarga completada exitosamente' 
                : '❌ Error en la precarga'
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _updatePreloadInfo();
      }
    }
  }

  void _clearPreload() {
    _usuarioService.limpiarPrecarga();
    _updatePreloadInfo();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Precarga limpiada'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPreloaded = _preloadInfo['isPreloaded'] ?? false;
    final isPreloading = _preloadInfo['isPreloading'] ?? false;
    final productsCount = _preloadInfo['productsCount'] ?? 0;
    final imagesWithUrl = _preloadInfo['imagesWithUrl'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 16),

            // Estadísticas
            if (isPreloaded) ...[
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
              const SizedBox(height: 16),
            ],

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || isPreloading ? null : _startManualPreload,
                    icon: _isLoading || isPreloading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                    label: Text(
                      _isLoading || isPreloading 
                        ? 'Precargando...' 
                        : 'Precargar Ahora'
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isPreloaded ? _clearPreload : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Botón de actualizar estado
            Center(
              child: TextButton.icon(
                onPressed: _updatePreloadInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar Estado'),
              ),
            ),

            // Información adicional
            const Divider(),
            Text(
              'ℹ️ La precarga se ejecuta automáticamente después del login exitoso. '
              'Los productos e imágenes se cargan en segundo plano para mejorar la velocidad de navegación.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
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
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
