import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';
import 'package:sidcop_mobile/models/VisitasViewModel.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/Offline_Services/SincronizacionService.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/visita_create.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/visita_details.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:math';

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
  List<VisitasViewModel> _filteredVisitas = [];
  bool _isLoading = true;
  bool _isLoadingEstados = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  // Estados para el filtro
  List<Map<String, dynamic>> _estadosVisita = [];
  Set<String> _selectedStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadVisitas();
    _loadEstadosVisita();
    _searchController.addListener(_onSearchChanged);
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

    // Verificar cuántas visitas pendientes hay al iniciar la pantalla
    try {
      final pendientes = await VisitasOffline.obtenerVisitasPendientesLocal();

      print(
        '\n===== VISITAS PENDIENTES AL INICIAR: ${pendientes.length} =====',
      );
      if (pendientes.isNotEmpty) {
        // Mostrar información detallada de cada visita pendiente
        for (int i = 0; i < pendientes.length; i++) {
          print('\n----- VISITA PENDIENTE #${i + 1} -----');
          try {
            print('Cliente ID: ${pendientes[i]['clie_Id']}');
            print('Dirección ID: ${pendientes[i]['diCl_Id']}');
            print('Estado Visita ID: ${pendientes[i]['esVi_Id']}');
            print('Usuario Creación: ${pendientes[i]['usua_Creacion']}');
            print('Fecha: ${pendientes[i]['clVi_Fecha']}');
            print('Firma: ${pendientes[i]['local_signature'] ?? 'sin firma'}');

            // Si hay origen, mostrarlo (para las visitas de maps)
            if (pendientes[i]['origen'] != null) {
              print('Origen: ${pendientes[i]['origen']}');
            }

            // Mostrar estructura completa para la primera visita
            if (i == 0) {
              print(
                '\nEstructura JSON completa de la primera visita pendiente:',
              );
              print(const JsonEncoder.withIndent('  ').convert(pendientes[i]));
            }
          } catch (e) {
            print('Error al mostrar detalles de visita pendiente: $e');
          }
        }
      }
    } catch (e) {
      print('Error al verificar visitas pendientes: $e');
    }

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

    // Iniciar sincronización de imágenes en segundo plano
    _sincronizarImagenesEnSegundoPlano();

    try {
      final visitas = await _service.listarPorVendedor();

      // Guardar la lista remota localmente para permitir lectura offline
      try {
        final visitasJson = visitas.map((v) => v.toJson()).toList();

        // Fusionar con visitas pendientes para no sobrescribir visitas guardadas
        // en modo offline cuando la API devuelva una lista vacía o parcial.
        try {
          final pendientes =
              await VisitasOffline.obtenerVisitasPendientesLocal();

          if (pendientes.isNotEmpty) {
            // Evitar duplicados simples: si la entrada pendiente tiene
            // `local_signature` y alguna visita remota la contiene, no la añadimos.
            final signaturesRemote = <String>{};
            for (final r in visitasJson) {
              try {
                if (r['local_signature'] != null) {
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

        // Guardar las visitas en el historial
        await VisitasOffline.guardarVisitasHistorial(visitasJson);

        // Verificamos las visitas pendientes para no perderlas
        try {
          final pendientes =
              await VisitasOffline.obtenerVisitasPendientesLocal();
          if (pendientes.isNotEmpty) {
            print(
              'Preservando ${pendientes.length} visitas pendientes durante guardado de historial',
            );

            // Mostrar detalles de las visitas pendientes para diagnóstico
            for (int i = 0; i < pendientes.length; i++) {
              print('\n===== VISITA PENDIENTE #${i + 1} DETALLE =====');
              try {
                print('Cliente ID: ${pendientes[i]['clie_Id']}');
                print('Dirección ID: ${pendientes[i]['diCl_Id']}');
                print('Estado Visita ID: ${pendientes[i]['esVi_Id']}');
                print('Fecha: ${pendientes[i]['clVi_Fecha']}');
                print('Usuario Creación: ${pendientes[i]['usua_Creacion']}');
                print('Offline: ${pendientes[i]['offline']}');
                print('Observaciones: ${pendientes[i]['clVi_Observaciones']}');
                print('Firma: ${pendientes[i]['local_signature']}');
                print(
                  'Imágenes: ${(pendientes[i]['imagenesBase64'] as List?)?.length ?? 0}',
                );

                // Mostrar el JSON completo para análisis
                print('\nJSON COMPLETO:');
                print(
                  const JsonEncoder.withIndent('  ').convert(pendientes[i]),
                );
              } catch (e) {
                print(
                  'Error al imprimir detalles de visita pendiente #${i + 1}: $e',
                );
              }
            }
          }
        } catch (e) {
          print('Error al verificar visitas pendientes: $e');
        }
      } catch (_) {
        // Si falla el guardado local, no interrumpir la carga en pantalla
      }

      setState(() {
        _visitas = visitas;
        _filteredVisitas = List.from(visitas);
        _isLoading = false;
      });
    } catch (e) {
      // Si hay error al obtener remoto, intentar cargar la copia local
      try {
        // Combinar datos históricos y pendientes
        final raw = await VisitasOffline.obtenerTodasLasVisitas();
        if (raw.isNotEmpty) {
          // Obtener la fecha actual para filtrar solo visitas de hoy
          final now = DateTime.now();
          final hoy = DateTime(now.year, now.month, now.day);

          final localVisitas = raw
              .map((m) => VisitasViewModel.fromJson(m as Map<String, dynamic>))
              .toList();

          // Filtrar solo las visitas de hoy (mismo filtro que en modo online)
          final visitasHoy = localVisitas.where((visita) {
            try {
              if (visita.clVi_Fecha == null) return false;

              final fechaVisitaSinHora = DateTime(
                visita.clVi_Fecha!.year,
                visita.clVi_Fecha!.month,
                visita.clVi_Fecha!.day,
              );

              return fechaVisitaSinHora.isAtSameMomentAs(hoy);
            } catch (e) {
              print('Error al procesar fecha de visita offline: $e');
              return false;
            }
          }).toList();

          // Ordenar por fecha de creación (más reciente primero)
          visitasHoy.sort((a, b) {
            try {
              final fechaA = a.clVi_FechaCreacion ?? DateTime(1900);
              final fechaB = b.clVi_FechaCreacion ?? DateTime(1900);
              return fechaB.compareTo(fechaA); // Orden descendente
            } catch (e) {
              return 0;
            }
          });

          setState(() {
            _visitas = visitasHoy;
            _filteredVisitas = List.from(visitasHoy);
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

  Future<void> _loadEstadosVisita() async {
    if (!mounted) return;

    setState(() {
      _isLoadingEstados = true;
    });

    try {
      // Primero intentar cargar estados desde el almacenamiento local
      List<Map<String, dynamic>> estados = [];

      try {
        // Intentar sincronizar estados desde el servidor
        estados = await VisitasOffline.sincronizarEstadosVisita();
        developer.log('✅ Estados de visita sincronizados correctamente');
      } catch (syncError) {
        developer.log(
          '⚠️ Error sincronizando estados: $syncError. Intentando usar caché local...',
        );

        // Si falla la sincronización, intentar obtener del almacenamiento local
        try {
          estados = await VisitasOffline.obtenerEstadosVisitaLocal();
        } catch (localError) {
          developer.log('❌ Error obteniendo estados locales: $localError');
          throw localError; // Propagar el error para usar valores por defecto
        }
      }

      if (!mounted) return;

      setState(() {
        _estadosVisita = estados;
      });
    } catch (e) {
      // Si fallan todos los intentos, usar estados por defecto
      developer.log('❌ Usando estados por defecto debido a: $e');
      _estadosVisita = [
        {'esVi_Id': 1, 'esVi_Descripcion': 'Pendiente'},
        {'esVi_Id': 2, 'esVi_Descripcion': 'Venta realizada'},
        {'esVi_Id': 3, 'esVi_Descripcion': 'Negocio cerrado'},
      ];
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEstados = false;
        });
      }
    }
  }

  /// Método para sincronizar imágenes de todas las visitas en segundo plano
  /// Esta función no bloquea la interfaz de usuario y muestra una notificación al finalizar
  Future<void> _sincronizarImagenesEnSegundoPlano() async {
    // Iniciar la sincronización en una tarea separada para no bloquear la UI
    Future.microtask(() async {
      try {
        developer.log(
          '🔄 Iniciando sincronización de imágenes en segundo plano',
        );

        // Usar el servicio de sincronización para descargar todas las imágenes
        final resultado =
            await SincronizacionService.sincronizarImagenesVisitas();

        // Solo registrar en log, no mostrar notificación al usuario
        if (resultado['imagenesDescargadas'] > 0) {
          developer.log(
            '✅ Sincronización de imágenes completada: ${resultado['imagenesDescargadas']} imágenes de ${resultado['visitasConImagenes']} visitas descargadas',
          );
        } else {
          developer.log(
            'ℹ️ Sincronización de imágenes completada: no hay nuevas imágenes para descargar',
          );
        }
      } catch (e) {
        developer.log(
          '❌ Error en sincronización de imágenes en segundo plano: $e',
        );
        // No mostrar error al usuario para no interrumpir su experiencia
      }
    });
  }

  String normalizeAndClean(String str) {
    if (str.isEmpty) return '';

    // Convertimos a minúsculas
    String normalized = str.toLowerCase();

    // Reemplazamos acentos y caracteres especiales
    const accents = 'áàäâãåéèëêíìïîóòöôõúùüûñç';
    const withoutAccents = 'aaaaaaeeeeiiiiooooouuuunc';

    for (int i = 0; i < accents.length; i++) {
      normalized = normalized.replaceAll(accents[i], withoutAccents[i]);
    }

    // Eliminamos caracteres que no sean letras, números o espacios
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    // Eliminamos espacios dobles
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final searchTerm = normalizeAndClean(_searchController.text);

    setState(() {
      _filteredVisitas = _visitas.where((visita) {
        final clienteNombre = normalizeAndClean(
          '${visita.clie_Nombres ?? ''} ${visita.clie_Apellidos ?? ''}',
        );
        final negocio = normalizeAndClean(visita.clie_NombreNegocio ?? '');
        final observaciones = normalizeAndClean(
          visita.clVi_Observaciones ?? '',
        );
        final estado = normalizeAndClean(visita.esVi_Descripcion ?? '');

        final matchesSearch =
            searchTerm.isEmpty ||
            clienteNombre.contains(searchTerm) ||
            negocio.contains(searchTerm) ||
            observaciones.contains(searchTerm) ||
            estado.contains(searchTerm);

        final matchesStatus =
            _selectedStatuses.isEmpty ||
            _selectedStatuses.any(
              (status) => normalizeAndClean(status) == estado,
            );

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool?>(
            context,
            MaterialPageRoute(builder: (context) => const VisitaCreateScreen()),
          );
          if (mounted && result == true) {
            await _loadVisitas();
          }
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
    return Column(
      children: [
        // Search Bar mejorada con botón de filtro
        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildFilterAndCount(),
        const SizedBox(height: 16), // Visitas List
        _filteredVisitas.isEmpty
            ? _buildEmptyWidget()
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredVisitas.length,
                itemBuilder: (context, index) {
                  final visita = _filteredVisitas[index];
                  return _buildVisitaCard(visita);
                },
              ),
      ],
    );
  }

  // Nuevo método para construir la barra de búsqueda con filtro
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontFamily: 'Satoshi'),
                decoration: InputDecoration(
                  hintText: 'Buscar visitas...',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Satoshi',
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF141A2F),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(
                      color: Color(0xFF141A2F),
                      width: 2,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(width: 1),
            ),
            child: IconButton(
              onPressed: _showStatusFilters,
              icon: const Icon(Icons.filter_list, color: Color(0xFF141A2F)),
              tooltip: 'Filtrar por estado',
            ),
          ),
        ],
      ),
    );
  }

  // Nuevo método para mostrar contador y limpiar filtros
  Widget _buildFilterAndCount() {
    final bool hasTextFilter = _searchController.text.isNotEmpty;
    final bool hasStatusFilter = _selectedStatuses.isNotEmpty;
    final bool hasAnyFilter = hasTextFilter || hasStatusFilter;

    final int resultCount = _filteredVisitas.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          Text(
            '$resultCount resultados',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: 'Satoshi',
            ),
          ),
          const Spacer(),
          if (hasAnyFilter)
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedStatuses.clear();
                });
                _applyFilters();
              },
              child: const Text(
                'Limpiar filtros',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Nuevo método para construir la sección de filtros (similar a clientes)
  Widget _buildFilterSection(
    String title,
    IconData icon,
    List<Map<String, dynamic>> items,
    Set<String> selectedValues,
    Function(String, bool) onSelectionChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.map((item) {
              final description = item['esVi_Descripcion'] as String;
              final isSelected = selectedValues.contains(
                description.toLowerCase(),
              );

              return ChoiceChip(
                label: Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    color: isSelected ? const Color(0xFF141A2F) : Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.1,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFD6B68A),
                backgroundColor: const Color(0xFF141A2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.white : const Color(0xFFD6B68A),
                  ),
                ),
                onSelected: (selected) {
                  onSelectionChanged(description.toLowerCase(), selected);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Nuevo método para mostrar el modal de filtros de estado
  void _showStatusFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: DraggableScrollableSheet(
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 0.8,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF141A2F),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Header with title and close/clear buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Filtrar por estado',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Satoshi',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _selectedStatuses.clear();
                                  });
                                  setState(() {
                                    _selectedStatuses.clear();
                                  });
                                  _applyFilters();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFD6B68A),
                                ),
                                child: const Text('Limpiar'),
                              ),
                            ],
                          ),
                        ),

                        // Filter sections
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                children: [
                                  // Estados section
                                  _buildFilterSection(
                                    'Estados de Visita',
                                    Icons.assignment_turned_in,
                                    _estadosVisita,
                                    _selectedStatuses,
                                    (estado, selected) {
                                      setModalState(() {
                                        if (selected) {
                                          _selectedStatuses.add(estado);
                                        } else {
                                          _selectedStatuses.remove(estado);
                                        }
                                      });
                                      setState(() {
                                        if (selected) {
                                          _selectedStatuses.add(estado);
                                        } else {
                                          _selectedStatuses.remove(estado);
                                        }
                                      });
                                    },
                                  ),

                                  // Apply button
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _applyFilters();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF141A2F,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFD6B68A),
                                        ),
                                        elevation: 0,
                                        foregroundColor: const Color(
                                          0xFFD6B68A,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Aplicar filtros',
                                        style: TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height:
                                        MediaQuery.of(
                                          context,
                                        ).viewInsets.bottom +
                                        16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVisitaCard(VisitasViewModel visita) {
    // Verificar si es una visita offline (aún no insertada)
    final bool esVisitaOffline = visita.clVi_Id == null || visita.clVi_Id == 0;

    final clienteNombre =
        '${visita.clie_Nombres ?? ''} ${visita.clie_Apellidos ?? ''}'.trim();
    final negocio = visita.clie_NombreNegocio ?? 'Negocio no disponible';
    final estadoDescripcion = visita.esVi_Descripcion ?? 'Estado desconocido';
    final observaciones = visita.clVi_Observaciones ?? 'Sin observaciones';
    final fecha =
        visita.clVi_Fecha?.toLocal().toString().split(' ')[0] ??
        'Fecha no disponible';

    // Para visitas offline, no mostrar vendedor ni ruta
    final vendedor = esVisitaOffline
        ? 'No disponible - Visita pendiente'
        : '${visita.vend_Nombres ?? ''} ${visita.vend_Apellidos ?? ''}'.trim();
    final ruta = esVisitaOffline
        ? 'No disponible - Visita pendiente'
        : visita.ruta_Descripcion ?? 'Ruta no disponible';

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
        primaryColor = const Color.fromARGB(255, 20, 108, 180);
        secondaryColor = const Color.fromARGB(255, 66, 137, 195);
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clienteNombre,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              // Indicador si es visita offline
                              if (esVisitaOffline)
                                Text(
                                  'Sincronización pendiente',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    fontFamily: 'Satoshi',
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                    // Mostrar vendedor y ruta solo si no es una visita offline
                    if (!esVisitaOffline) ...[
                      _infoRow(Icons.person_rounded, 'Vendedor', vendedor),
                      const SizedBox(height: 16),
                      _infoRow(Icons.route, 'Ruta', ruta),
                      const SizedBox(height: 16),
                    ],
                    _infoRow(
                      Icons.notes_rounded,
                      'Observaciones',
                      observaciones,
                    ),
                    const SizedBox(height: 16),
                    _infoRow(Icons.calendar_today_rounded, 'Fecha', fecha),
                    const SizedBox(height: 16),

                    // Botón para ver imágenes - solo si no es una visita offline
                    if (!esVisitaOffline)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VisitaDetailsScreen(
                                  visitaId: visita.clVi_Id ?? 0,
                                  clienteNombre: clienteNombre,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor.withOpacity(0.1),
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: primaryColor),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.photo_library, size: 20),
                          label: const Text(
                            'Ver Imágenes',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
