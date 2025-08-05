import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RecargasViewModel.dart';
import 'package:sidcop_mobile/ui/screens/recharges/recharges_screen.dart';

class RecargaDetalleBottomSheet extends StatelessWidget {
  // Sistema de colores modernizado
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color lightBlue = Color(0xFF1E293B);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color lightGold = Color(0xFFFBBF24);
  static const Color backgroundGray = Color(0xFFFAFAFA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);
  String _estadoLegible(dynamic estado) {
    switch (estado) {
      case 'A':
        return 'Aprobado';
      case 'R':
        return 'Rechazado';
      case 'P':
        return 'Pendiente';
      default:
        return '-';
    }
  }

  Color _getStatusColor(dynamic estado) {
    switch (estado) {
      case 'A':
        return primaryBlue;
      case 'R':
        return const Color(0xFFDC2626);
      case 'P':
        return accentGold;
      default:
        return textTertiary;
    }
  }

  IconData _getStatusIcon(dynamic estado) {
    switch (estado) {
      case 'A':
        return Icons.check_circle;
      case 'R':
        return Icons.cancel;
      case 'P':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }

  final List<RecargasViewModel> recargasGrupo;
  final VoidCallback? onRecargaUpdated;

  const RecargaDetalleBottomSheet({Key? key, required this.recargasGrupo, this.onRecargaUpdated}) : super(key: key);

  void _openEditRecargaModal(BuildContext context, List<RecargasViewModel> recargasGrupo) {
    final recaId = recargasGrupo.isNotEmpty ? recargasGrupo.first.reca_Id : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecargaBottomSheet(
        recargasGrupoParaEditar: recargasGrupo,
        isEditMode: true,
        recaId: recaId,
      ),
    ).then((result) {
      // Si la edición fue exitosa, ejecutar callback y cerrar modal
      print('🔍 DEBUG: Modal de detalles recibió resultado: $result');
      if (result == true) {
        print('🔍 DEBUG: Ejecutando callback de actualización');
        // Ejecutar callback para refrescar la lista principal
        if (onRecargaUpdated != null) {
          onRecargaUpdated!();
        }
        // Cerrar el modal de detalles
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recarga = recargasGrupo.first;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                surfaceColor,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, -8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: textTertiary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              // Header section
              Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detalle de Recarga',
                                style: const TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: accentGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: accentGold.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${recargasGrupo.length} producto${recargasGrupo.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: accentGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: textSecondary, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Info cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.calendar_today,
                            title: 'Fecha',
                            value: recarga.reca_Fecha != null 
                                ? recarga.reca_Fecha!.toIso8601String().substring(0, 10)
                                : '-',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatusCard(
                            estado: recarga.reca_Confirmacion,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Products section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Text(
                  'Productos',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  itemCount: recargasGrupo.length,
                  itemBuilder: (context, index) {
                    final detalle = recargasGrupo[index];
                    return _buildProductCard(detalle, index);
                  },
                ),
              ),
              
              // Botón de editar para solicitudes pendientes
              if (recarga.reca_Confirmacion == 'P')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Cerrar el detalle
                        _openEditRecargaModal(context, recargasGrupo);
                      },
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Editar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0C7A0),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              color: textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard({required dynamic estado}) {
    final color = _getStatusColor(estado);
    final icon = _getStatusIcon(estado);
    final text = _estadoLegible(estado);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          const Text(
            'Estado',
            style: TextStyle(
              fontFamily: 'Satoshi',
              color: textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductCard(RecargasViewModel detalle, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.08),
                  primaryBlue.withOpacity(0.12),
                ],
              ),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: detalle.prod_Imagen != null && detalle.prod_Imagen!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Image.network(
                      detalle.prod_Imagen!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.inventory_2_rounded,
                          color: primaryBlue.withOpacity(0.6),
                          size: 32,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.inventory_2_rounded,
                    color: primaryBlue.withOpacity(0.6),
                    size: 32,
                  ),
          ),
          
          const SizedBox(width: 20),
          
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.prod_DescripcionCorta ?? 'Producto',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cantidad solicitada',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${detalle.reDe_Cantidad ?? '-'}',
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      color: primaryBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
