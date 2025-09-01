import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';
import 'package:sidcop_mobile/models/VisitasViewModel.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/visita_create.dart';

class VendedorVisitasScreen extends StatefulWidget {
  final int usuaIdPersona;
  const VendedorVisitasScreen({super.key, required this.usuaIdPersona});

  @override
  State<VendedorVisitasScreen> createState() => _VendedorVisitasScreenState();
}

class _VendedorVisitasScreenState extends State<VendedorVisitasScreen> {
  final ClientesVisitaHistorialService _service =
      ClientesVisitaHistorialService();
  List<VisitasViewModel> _visitas = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadVisitas();
  }

  Future<void> _loadVisitas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Intentar sincronizar datos maestros para que los dropdowns en
    // `VisitaCreateScreen` estén actualizados cada vez que se entra a
    // la pantalla de visitas. Errores no deben bloquear la carga.
    try {
      await VisitasOffline.sincronizarEstadosVisita();
    } catch (_) {}
    try {
      await VisitasOffline.sincronizarClientes();
    } catch (_) {}
    try {
      await VisitasOffline.sincronizarDirecciones();
    } catch (_) {}

    // Intentar enviar visitas pendientes guardadas en modo offline.
    try {
      final pendientesEnviadas = await VisitasOffline.sincronizarPendientes();
      if (mounted && pendientesEnviadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$pendientesEnviadas visita(s) sincronizada(s) con éxito',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      // No interrumpir la carga si falla la sincronización de pendientes
    }

    try {
      final visitas = await _service.listarPorVendedor();

      // Guardar la lista remota localmente para permitir lectura offline
      try {
        final visitasJson = visitas.map((v) => v.toJson()).toList();

        // Fusionar con visitas locales pendientes (offline == true) para no
        // sobrescribir visitas guardadas en modo offline cuando la API
        // devuelva una lista vacía o parcial.
        try {
          final localRaw = await VisitasOffline.obtenerVisitasHistorialLocal();
          final pendientes = localRaw.where((e) {
            try {
              return e is Map && (e['offline'] == true);
            } catch (_) {
              return false;
            }
          }).toList();

          if (pendientes.isNotEmpty) {
            // Evitar duplicados simples: si la entrada pendiente tiene
            // `local_signature` y alguna visita remota la contiene, no la añadimos.
            final signaturesRemote = <String>{};
            for (final r in visitasJson) {
              try {
                if (r is Map && r['local_signature'] != null) {
                  signaturesRemote.add(r['local_signature'].toString());
                }
              } catch (_) {}
            }

            for (final p in pendientes) {
              try {
                final sig = (p as Map)['local_signature']?.toString();
                if (sig == null || !signaturesRemote.contains(sig)) {
                  visitasJson.add(p as Map<String, dynamic>);
                }
              } catch (_) {
                // si falla, añadir de todas formas
                try {
                  visitasJson.add(p as Map<String, dynamic>);
                } catch (_) {}
              }
            }
          }
        } catch (_) {}

        await VisitasOffline.guardarVisitasHistorial(visitasJson);
      } catch (_) {
        // Si falla el guardado local, no interrumpir la carga en pantalla
      }

      setState(() {
        _visitas = visitas;
        _isLoading = false;
      });
    } catch (e) {
      // Si hay error al obtener remoto, intentar cargar la copia local
      try {
        final raw = await VisitasOffline.obtenerVisitasHistorialLocal();
        if (raw.isNotEmpty) {
          final localVisitas = raw
              .map((m) => VisitasViewModel.fromJson(m as Map<String, dynamic>))
              .toList();
          setState(() {
            _visitas = localVisitas;
            _isLoading = false;
            _errorMessage = '';
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _errorMessage = 'Error al cargar las visitas';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VisitaCreateScreen()),
          );
        },
        backgroundColor: const Color(0xFF141A2F),
        child: const Icon(Icons.add, color: Colors.white),
        shape: const CircleBorder(),
        elevation: 4.0,
      ),
      body: AppBackground(
        title: 'Historial de Visitas',
        icon: Icons.location_history,
        onRefresh: _loadVisitas,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _visitas.isEmpty
              ? _buildEmptyWidget()
              : _buildVisitasList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF3B30)),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.location_off, size: 64, color: Color(0xFF8E8E93)),
          SizedBox(height: 16),
          Text(
            'No hay visitas registradas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
              color: Color(0xFF141A2F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Las visitas realizadas aparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Satoshi',
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _visitas.length,
      itemBuilder: (context, index) {
        final visita = _visitas[index];
        return _buildVisitaCard(visita);
      },
    );
  }

  Widget _buildVisitaCard(VisitasViewModel visita) {
    final clienteNombre =
        '${visita.clie_Nombres ?? ''} ${visita.clie_Apellidos ?? ''}'.trim();
    final negocio = visita.clie_NombreNegocio ?? 'Negocio no disponible';
    final estadoDescripcion = visita.esVi_Descripcion ?? 'Estado desconocido';
    final observaciones = visita.clVi_Observaciones ?? 'Sin observaciones';
    final fecha =
        visita.clVi_Fecha?.toLocal().toString().split(' ')[0] ??
        'Fecha no disponible';
    final vendedor =
        '${visita.vend_Nombres ?? ''} ${visita.vend_Apellidos ?? ''}'.trim();
    final ruta = visita.ruta_Descripcion ?? 'Ruta no disponible';

    // COLORES Y ETIQUETA DE ESTADO
    Color primaryColor;
    Color secondaryColor;
    Color backgroundColor;
    IconData iconoEstado;

    switch (estadoDescripcion.toLowerCase()) {
      case 'negocio cerrado':
        primaryColor = const Color(0xFFFF3B30);
        secondaryColor = const Color(0xFFFF6B60);
        backgroundColor = const Color(0xFFFFE8E6);
        iconoEstado = Icons.cancel_rounded;
        break;
      case 'venta realizada':
        primaryColor = const Color(0xFF141A2F);
        secondaryColor = const Color(0xFF2C3655);
        backgroundColor = const Color(0xFFE8EAF6);
        iconoEstado = Icons.check_circle_rounded;
        break;
      default:
        primaryColor = const Color(0xFF2196F3);
        secondaryColor = const Color(0xFF64B5F6);
        backgroundColor = const Color(0xFFE3F2FD);
        iconoEstado = Icons.info_outline_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
              // Header
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
                      child: Icon(iconoEstado, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estadoDescripcion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clienteNombre,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow(Icons.storefront_rounded, 'Negocio', negocio),
                    const SizedBox(height: 16),
                    _infoRow(Icons.person_rounded, 'Vendedor', vendedor),
                    const SizedBox(height: 16),
                    _infoRow(Icons.route, 'Ruta', ruta),
                    const SizedBox(height: 16),
                    _infoRow(
                      Icons.notes_rounded,
                      'Observaciones',
                      observaciones,
                    ),
                    const SizedBox(height: 16),
                    _infoRow(Icons.calendar_today_rounded, 'Fecha', fecha),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF141A2F)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Satoshi',
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Satoshi',
                  color: Color(0xFF141A2F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
