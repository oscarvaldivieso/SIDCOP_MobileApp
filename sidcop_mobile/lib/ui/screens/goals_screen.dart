import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/GoalsService.dart';
import 'package:sidcop_mobile/Offline_Services/Metas_OfflineService.dart';
import 'package:sidcop_mobile/models/MetasViewModel.dart';
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
  List<Metas> _goals = [];
  late AnimationController _refreshController;

  List<Metas> _allMetas = [];
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

    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      // 1. Intentar cargar desde backend
      final goalsRaw = await _goalsService.getGoalsByVendor(widget.usuaIdPersona);

      List<Metas> metasList = [];
      if (goalsRaw != null && goalsRaw.isNotEmpty) {
        metasList = goalsRaw.map<Metas>((json) => Metas.fromJson(json)).toList();
        // Guardar en cache offline
        await MetasOffline.guardarMetas(metasList);
      } else {
        // Si no hay metas online, intentar cargar offline
        metasList = await MetasOffline.obtenerMetasLocal();
      }

      if (mounted) {
        setState(() {
          if (metasList.isNotEmpty) {
            _goals = metasList;
            _errorMessage = '';
          } else {
            _errorMessage = 'Conéctate a una red para sincronizar tus metas.';
          }
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      // Si hay error, intentar cargar offline
      final offlineMetas = await MetasOffline.obtenerMetasLocal();
      if (mounted) {
        setState(() {
          if (offlineMetas.isNotEmpty) {
            _goals = offlineMetas;
            _errorMessage = '';
          } else {
            _errorMessage = 'Conéctate a una red para sincronizar tus metas.';
          }
          _isLoading = false;
        });
      }
    } finally {
      _refreshController.reset();
    }
  }

   // Sincroniza metas en background
  Future<void> _sincronizarMetasEnBackground() async {
  try {
    final nuevasMetas = await MetasOffline.sincronizarMetasPorVendedor(widget.usuaIdPersona);
    if (nuevasMetas.isNotEmpty && mounted) {
      setState(() {
        _goals = nuevasMetas;
        // Si tienes filtros, reaplícalos aquí
      });
    }
  } catch (e) {
    debugPrint('Error en sincronización background: $e');
  }
}

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      // Formato: "dd 'de' MMMM 'del' yyyy" (ejemplo: "04 de septiembre del 2023")
      return DateFormat("dd 'de' MMMM 'del' yyyy", 'es_ES').format(date);
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

  Widget _buildGoalCard(Metas goal) {
  final goalType = goal.metaTipo;
    final color = _getGoalTypeColor(goalType);
    final icon = _getGoalTypeIcon(goalType);
    
    double progress = 0.0;
    String progressText = '';
    String targetText = '';
      // String progressLabel = 'Progreso'; // No se usa

      if (goal.metaIngresos != null && goal.metaIngresos! > 0) {
        final metaIngresos = goal.metaIngresos!;
        final progresoIngresos = goal.progresoIngresos;
        progress = (progresoIngresos / metaIngresos).clamp(0.0, 1.0);
        progressText = NumberFormat.currency(symbol: 'L ').format(progresoIngresos);
        targetText = NumberFormat.currency(symbol: 'L ').format(metaIngresos);
        // progressLabel = 'Ingresos';
      } else if (goal.metaUnidades != null && goal.metaUnidades! > 0) {
        final metaUnidades = goal.metaUnidades!;
        final progresoUnidades = goal.progresoUnidades;
        progress = (progresoUnidades / metaUnidades).clamp(0.0, 1.0);
        progressText = '${progresoUnidades.toInt()}';
        targetText = '${metaUnidades.toInt()}';
        // progressLabel = 'Clientes';
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.metaDescripcion,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Meta: $targetText',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Satoshi',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                children: [
                  Expanded(
                    child: Text(
                      '${_formatDate(goal.metaFechaInicio ?? '')} - ${_formatDate(goal.metaFechaFin ?? '')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontFamily: 'Satoshi',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (goal.producto != null)
                    Expanded(
                      child: Text(
                        goal.producto!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF141A2F),
                          fontFamily: 'Satoshi',
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
      if (goal.metaIngresos != null && goal.metaIngresos! > 0) {
        if (goal.progresoIngresos >= goal.metaIngresos!) {
          completedGoals++;
        }
      } else if (goal.metaUnidades != null && goal.metaUnidades! > 0) {
        if (goal.progresoUnidades >= goal.metaUnidades!) {
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
              'No hay metas disponibles offline',
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  _buildSummaryCard(),
                                  const SizedBox(height: 16),
                                  ..._goals.map((goal) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: _buildGoalCard(goal),
                                  )),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            );
                      },
                    ),
    );
  }
}