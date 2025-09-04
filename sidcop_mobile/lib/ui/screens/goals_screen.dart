import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/GoalsService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';

class GoalsScreen extends StatefulWidget {
  final int usuaIdPersona;

  const GoalsScreen({Key? key, required this.usuaIdPersona}) : super(key: key);

  @override
  _GoalsScreenState createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  final GoalsService _goalsService = GoalsService();
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _goals = [];
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadGoals();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    debugPrint('[_loadGoals] Iniciando carga de metas...');
    debugPrint('[_loadGoals] ID de usuario: ${widget.usuaIdPersona}');
    
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      debugPrint('[_loadGoals] Llamando a _goalsService.getGoalsByVendor...');
      final goals = await _goalsService.getGoalsByVendor(widget.usuaIdPersona);
      debugPrint('[_loadGoals] Respuesta recibida: ${goals?.length ?? 0} metas');
      
      if (goals != null) {
        debugPrint('[_loadGoals] Datos de metas: $goals');
      } else {
        debugPrint('[_loadGoals] La respuesta de metas es nula');
      }

      if (mounted) {
        setState(() {
          if (goals != null && goals.isNotEmpty) {
            _goals = goals;
            debugPrint('[_loadGoals] Metas actualizadas en el estado: ${_goals.length}');
          } else {
            _errorMessage = 'No se encontraron metas para mostrar';
            debugPrint('[_loadGoals] No se encontraron metas');
          }
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[_loadGoals] Error al cargar metas: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión. Intente nuevamente.';
          _isLoading = false;
        });
      }
    } finally {
      _refreshController.reset();
      debugPrint('[_loadGoals] Carga de metas finalizada');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy', 'es_ES').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getGoalTypeName(String type) {
    switch (type) {
      case 'IP':
        return 'Ingresos por Producto';
      case 'CN':
        return 'Clientes Nuevos';
      case 'IM':
        return 'Ingresos Mensuales';
      default:
        return type;
    }
  }

  Color _getGoalTypeColor(String type) {
    switch (type) {
      case 'IP':
        return const Color(0xFF4CAF50);
      case 'CN':
        return const Color(0xFF2196F3);
      case 'IM':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getGoalTypeIcon(String type) {
    switch (type) {
      case 'IP':
        return Icons.shopping_bag_outlined;
      case 'CN':
        return Icons.people_alt_outlined;
      case 'IM':
        return Icons.attach_money_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  Widget _buildCircularProgress(double progress, Color color) {
    return Container(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 6,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                  ),
                ),
                Text(
                  'Progreso',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey[600],
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final goalType = goal['Meta_Tipo'] ?? '';
    final color = _getGoalTypeColor(goalType);
    final icon = _getGoalTypeIcon(goalType);
    
    double progress = 0.0;
    String progressText = '';
    String targetText = '';
    String progressLabel = 'Progreso';

    if (goal['Meta_Ingresos'] != null && goal['Meta_Ingresos'] > 0) {
      final metaIngresos = (goal['Meta_Ingresos'] as num).toDouble();
      final progresoIngresos = (goal['ProgresoIngresos'] as num?)?.toDouble() ?? 0.0;
      progress = (progresoIngresos / metaIngresos).clamp(0.0, 1.0);
      progressText = NumberFormat.currency(symbol: 'L ').format(progresoIngresos);
      targetText = NumberFormat.currency(symbol: 'L ').format(metaIngresos);
      progressLabel = 'Ingresos';
    } else if (goal['Meta_Unidades'] != null && goal['Meta_Unidades'] > 0) {
      final metaUnidades = (goal['Meta_Unidades'] as num).toDouble();
      final progresoUnidades = (goal['ProgresoUnidades'] as num?)?.toDouble() ?? 0.0;
      progress = (progresoUnidades / metaUnidades).clamp(0.0, 1.0);
      progressText = '${progresoUnidades.toInt()}';
      targetText = '${metaUnidades.toInt()}';
      progressLabel = 'Clientes';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGoalTypeName(goalType),
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal['Meta_Descripcion'] ?? 'Sin descripción',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A2F),
                          fontFamily: 'Satoshi',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress Section
            Row(
              children: [
                _buildCircularProgress(progress, color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actual: $progressText',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A2F),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Meta: $targetText',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatDate(goal['Meta_FechaInicio'] ?? '')} - ${_formatDate(goal['Meta_FechaFin'] ?? '')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  if (goal['Producto'] != null)
                    Flexible(
                      child: Text(
                        goal['Producto'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF141A2F),
                          fontFamily: 'Satoshi',
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_goals.isEmpty) return const SizedBox.shrink();

    int completedGoals = 0;
    for (var goal in _goals) {
      if (goal['Meta_Ingresos'] != null && goal['Meta_Ingresos'] > 0) {
        if ((goal['ProgresoIngresos'] ?? 0) >= goal['Meta_Ingresos']) {
          completedGoals++;
        }
      } else if (goal['Meta_Unidades'] != null && goal['Meta_Unidades'] > 0) {
        if ((goal['ProgresoUnidades'] ?? 0) >= goal['Meta_Unidades']) {
          completedGoals++;
        }
      }
    }

    final totalGoals = _goals.length;
    final overallProgress = totalGoals > 0 ? completedGoals / totalGoals : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141A2F), Color(0xFF2D3748)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: overallProgress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 4,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(overallProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen General',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Satoshi',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedGoals de $totalGoals metas completadas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar las metas',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGoals,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141A2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay metas asignadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Las metas aparecerán aquí cuando sean asignadas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Metas',
      icon: Icons.flag_outlined,
      onRefresh: _loadGoals,
      permisos: const [], // Add actual permissions if needed
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF141A2F),
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _goals.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildSummaryCard(),
                          const SizedBox(height: 16),
                        ...List.generate(
                          _goals.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildGoalCard(_goals[index]),
                          ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }
}