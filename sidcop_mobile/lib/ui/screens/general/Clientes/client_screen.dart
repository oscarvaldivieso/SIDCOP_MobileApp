import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/ClientImageCacheService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/clientdetails_screen.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/clientcreate_screen.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';

class clientScreen extends StatefulWidget {
  const clientScreen({super.key});

  @override
  State<clientScreen> createState() => _clientScreenState();
}

class _clientScreenState extends State<clientScreen> {
  List<dynamic> permisos = [];
  late Future<List<dynamic>> clientesList = Future.value([]);
  List<dynamic> filteredClientes = [];
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;
  final ClientesService _clienteService = ClientesService();

  // --- Ubicaciones: Departamentos, Municipios, Colonias ---
  List<dynamic> _departamentos = [];
  List<dynamic> _municipios = [];
  List<dynamic> _colonias = [];
  List<dynamic> _direccionesPorCliente = [];
  List<dynamic> _cuentasPorCobrar = [];

  String? _selectedDepa;
  String? _selectedMuni;
  int? _selectedColo;

  @override
  @override
  void initState() {
    super.initState();
    _loadAllClientData();
  }

  Future<void> _loadAllClientData() async {
    try {
      // Verificar conexión a internet
      final hasConnection = await SyncService.hasInternetConnection();
      List<Map<String, dynamic>> clientes = [];

      if (hasConnection) {
        // Cargar direcciones por cliente
        final direcciones = await _clienteService.getDireccionesPorCliente();
        setState(() {
          _direccionesPorCliente = direcciones;
        });

        // Cargar clientes desde el servidor
        final usuaIdPersona = await _getUsuarioIdPersona();
        if (usuaIdPersona != null) {
          clientes = (await _clienteService.getClientesPorRuta(usuaIdPersona))
              .cast<Map<String, dynamic>>();
        } else {
          clientes = (await SyncService.getClients()).cast<Map<String, dynamic>>();
        }

        // Guardar clientes en almacenamiento local para uso offline
        await ClientesOfflineService.guardarClientes(clientes);

        // Sincronizar clientes pendientes
        final clientesSincronizados = await ClientesOfflineService.sincronizarClientesPendientes();
        
        // Mostrar mensaje de sincronización si se sincronizaron clientes
        if (clientesSincronizados > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$clientesSincronizados Cliente(s) sincronizados exitosamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Sincronizar clientes pendientes
        //await ClientesOfflineService.sincronizarClientesPendientes();
      } else {
        print('Sin conexión - cargando datos offline');

        // Cargar clientes desde almacenamiento local
        clientes = await ClientesOfflineService.cargarClientes();
      }

      // Procesar URLs de imágenes - concatenar baseUrl solo si no contiene 'http'
      for (var cliente in clientes) {
        if (cliente['clie_ImagenDelNegocio'] != null && 
            cliente['clie_ImagenDelNegocio'].toString().isNotEmpty) {
          String imagenUrl = cliente['clie_ImagenDelNegocio'].toString();
          cliente['clie_ImagenDelNegocio'] = imagenUrl.contains('http') 
              ? imagenUrl 
              : apiServer + imagenUrl;
        }
      }

      setState(() {
        filteredClientes = clientes;
        clientesList = Future.value(clientes);
      });
    } catch (e) {
      print('Error cargando datos de clientes: $e');
    }
  }

  Future<int?> _getUsuarioIdPersona() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    return userData?['usua_IdPersona'] as int?;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterClientes(String query) {
    setState(() {
      _applyAllFilters(query);
    });
  }

  void _applyAllFilters(String query) async {
    print('--- FILTRO APLICADO ---');
    print('Texto buscado: "' + query + '"');
    print('Depa seleccionado: ${_selectedDepa}');
    print('Muni seleccionado: ${_selectedMuni}');
    print('Colo seleccionado: ${_selectedColo}');
    //print( 'Datos disponibles - Departamentos: ${_departamentos.length}, Municipios: ${_municipios.length}, Colonias: ${_colonias.length}, Direcciones: ${_direccionesPorCliente.length}',);

    // Si hay municipio seleccionado, mostrar colonias de ese municipio
    if (_selectedMuni != null) {
      final coloniasDelMunicipio = _colonias
          .where((c) => c['muni_Codigo'] == _selectedMuni)
          .toList();
      print(
        'Colonias en municipio $_selectedMuni: ${coloniasDelMunicipio.length}',
      );
      if (coloniasDelMunicipio.isNotEmpty) {
        print('Ejemplo de colonia: ${coloniasDelMunicipio.first}');
      }
    }

    //  Future<void> _loadPermisos() async {
    //     final perfilService = PerfilUsuarioService();
    //     final userData = await perfilService.obtenerDatosUsuario();
    //     if (userData != null && (userData['PermisosJson'] != null || userData['permisosJson'] != null)) {
    //       try {
    //         final permisosJson = userData['PermisosJson'] ?? userData['permisosJson'];
    //         permisos = jsonDecode(permisosJson);
    //       } catch (_) {
    //         permisos = [];
    //       }
    //     }
    //     setState(() {});
    //   }

    final searchLower = query.toLowerCase();

    clientesList.then((clientes) {
      setState(() {
        filteredClientes = clientes.where((cliente) {
          print('\n--- Analizando cliente ---');
          print(
            'ID: ${cliente['clie_Id']}, Nombre: ${cliente['clie_NombreNegocio']}, Dirección: ${cliente['clie_DireccionExacta']}',
          );

          // Filtro por texto
          final nombreNegocio =
              cliente['clie_NombreNegocio']?.toString().toLowerCase() ?? '';
          final direccion =
              cliente['clie_DireccionExacta']?.toString().toLowerCase() ?? '';
          final matchesText =
              searchLower.isEmpty ||
              nombreNegocio.contains(searchLower) ||
              direccion.contains(searchLower);

          // Si no hay filtros de ubicación, solo aplicar filtro de texto
          if (_selectedDepa == null &&
              _selectedMuni == null &&
              _selectedColo == null) {
            print(
              'Sin filtro de ubicación, solo texto: ${matchesText ? "INCLUIDO" : "EXCLUIDO"}',
            );
            return matchesText;
          }

          // Obtener todas las direcciones del cliente desde _direccionesPorCliente
          final direccionesCliente = _direccionesPorCliente
              .where((d) => d['clie_Id'] == cliente['clie_Id'])
              .toList();

          if (direccionesCliente.isEmpty) {
            print(
              'Cliente sin dirección en direccionesPorCliente, EXCLUIDO por filtro de ubicación',
            );
            return false;
          }

          // FILTRO POR COLONIA - Esta es la parte corregida
          if (_selectedColo != null) {
            // Verificar si alguna de las direcciones del cliente tiene la colonia seleccionada
            final bool clienteTieneColoniaSeleccionada = direccionesCliente.any(
              (direccion) {
                return direccion['colo_Id'] == _selectedColo;
              },
            );

            print(
              'Filtro por colonia: Cliente clie_Id=${cliente['clie_Id']} tiene colonia $_selectedColo? ' +
                  (clienteTieneColoniaSeleccionada ? 'SI' : 'NO'),
            );

            return matchesText && clienteTieneColoniaSeleccionada;
          }

          // FILTRO POR MUNICIPIO
          if (_selectedMuni != null) {
            // Verificar si alguna dirección del cliente pertenece al municipio seleccionado
            final bool
            clienteTieneMunicipioSeleccionado = direccionesCliente.any((
              direccionCliente,
            ) {
              final int? coloId = direccionCliente['colo_Id'] as int?;
              if (coloId == null) return false;

              // Buscar la colonia en la lista de colonias
              dynamic colonia;
              try {
                colonia = _colonias.firstWhere(
                  (c) => c['colo_Id'] == coloId,
                  orElse: () => <String, dynamic>{},
                );
              } catch (e) {
                print('Error al buscar colonia $coloId: $e');
                return false;
              }

              if (colonia.isEmpty) {
                print(
                  'No se encontró la colonia $coloId para el cliente ${cliente['clie_Id']}',
                );
                return false;
              }

              // Verificar si la colonia pertenece al municipio seleccionado
              final String? muniCodigo = colonia['muni_Codigo'];
              final bool coincideMunicipio = muniCodigo == _selectedMuni;

              if (coincideMunicipio) {
                print(
                  'Cliente ${cliente['clie_Id']} tiene dirección en colonia $coloId que pertenece al municipio $_selectedMuni',
                );
              }

              return coincideMunicipio;
            });

            print(
              'Filtro por municipio: Cliente tiene municipio $_selectedMuni? ' +
                  (clienteTieneMunicipioSeleccionado ? 'SI' : 'NO'),
            );

            return matchesText && clienteTieneMunicipioSeleccionado;
          }

          // FILTRO POR DEPARTAMENTO
          if (_selectedDepa != null) {
            // Verificar si alguna dirección del cliente pertenece al departamento seleccionado
            final bool clienteTieneDepartamentoSeleccionado = direccionesCliente.any((
              direccionCliente,
            ) {
              final int? coloId = direccionCliente['colo_Id'] as int?;
              if (coloId == null) return false;

              // Buscar la colonia
              dynamic colonia;
              try {
                colonia = _colonias.firstWhere(
                  (c) => c['colo_Id'] == coloId,
                  orElse: () => <String, dynamic>{},
                );
              } catch (e) {
                print(
                  'Error al buscar colonia $coloId para filtro de departamento: $e',
                );
                return false;
              }

              if (colonia.isEmpty) {
                print(
                  'No se encontró la colonia $coloId para el cliente ${cliente['clie_Id']} en filtro de departamento',
                );
                return false;
              }

              final String? muniCodigo = colonia['muni_Codigo'];
              if (muniCodigo == null) return false;

              // Buscar el municipio
              dynamic municipio;
              try {
                municipio = _municipios.firstWhere(
                  (m) => m['muni_Codigo'] == muniCodigo,
                  orElse: () => <String, dynamic>{},
                );
              } catch (e) {
                print('Error al buscar municipio $muniCodigo: $e');
                return false;
              }

              if (municipio.isEmpty) {
                print(
                  'No se encontró el municipio $muniCodigo para el cliente ${cliente['clie_Id']}',
                );
                return false;
              }

              final String? depaCodigo = municipio['depa_Codigo'];
              final bool coincideDepartamento = depaCodigo == _selectedDepa;

              if (coincideDepartamento) {
                print(
                  'Cliente ${cliente['clie_Id']} tiene dirección en colonia $coloId, municipio $muniCodigo que pertenece al departamento $_selectedDepa',
                );
              }

              return coincideDepartamento;
            });

            print(
              'Filtro por departamento: Cliente tiene departamento $_selectedDepa? ' +
                  (clienteTieneDepartamentoSeleccionado ? 'SI' : 'NO'),
            );

            return matchesText && clienteTieneDepartamentoSeleccionado;
          }

          // Si llegamos aquí, no hay filtros activos, devolver solo el filtro de texto
          return matchesText;
        }).toList();

        // Remover duplicados basados en clie_Id (por si acaso)
        final Map<dynamic, dynamic> uniqueClientes = {};
        for (var cliente in filteredClientes) {
          uniqueClientes[cliente['clie_Id']] = cliente;
        }
        filteredClientes = uniqueClientes.values.toList();

        print('Total clientes después del filtro: ${filteredClientes.length}');
      });
    });
  }

  // Método para construir la barra de búsqueda

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              child: TextField(
                controller: _searchController,
                onChanged: _filterClientes,
                style: const TextStyle(fontFamily: 'Satoshi'),
                decoration: InputDecoration(
                  hintText: 'Filtrar por nombre...',
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
                    borderRadius: BorderRadius.circular(24.0), // Más redondeado
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
                            _filterClientes('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48, // Misma altura que el TextField
            width: 48, // Hacer el botón cuadrado
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                24,
              ), // Completamente redondeado
              border: Border.all(width: 1),
            ),
            child: IconButton(
              onPressed: _showLocationFilters,
              icon: const Icon(Icons.filter_list, color: Color(0xFF141A2F)),
              tooltip: 'Filtrar',
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir el botón de filtro y mostrar el contador de resultados
  Widget _buildFilterAndCount() {
    final bool hasTextFilter = _searchController.text.isNotEmpty;
    final bool hasLocationFilter =
        _selectedDepa != null || _selectedMuni != null || _selectedColo != null;
    final bool hasAnyFilter = hasTextFilter || hasLocationFilter;

    // Usar la lista filtrada si hay algún filtro activo
    final int resultCount = filteredClientes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0),
      child: Row(
        children: [
          // Contador de resultados
          Text(
            '$resultCount resultados',
            style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Satoshi'),
          ),
          const Spacer(),
          // Mostrar botón "Limpiar filtros" si hay filtros activos
          if (hasAnyFilter)
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedDepa = null;
                  _selectedMuni = null;
                  _selectedColo = null;
                });
                _applyAllFilters('');
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

  Widget _buildClientesList() {
  return FutureBuilder<List<dynamic>>(
    future: clientesList,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF141A2F)),
          ),
        );
      } else if (snapshot.hasError) {
        return Center(
          child: Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(
              fontFamily: 'Satoshi',
              color: Colors.red,
            ),
          ));
      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(
          child: Text(
            'No hay clientes',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        );
      } else {
        // Verificar si hay algún filtro activo (texto o ubicación)
        final bool hasTextFilter = _searchController.text.isNotEmpty;
        final bool hasLocationFilter =
            _selectedDepa != null ||
            _selectedMuni != null ||
            _selectedColo != null;
        final bool hasAnyFilter = hasTextFilter || hasLocationFilter;

        // Usar la lista filtrada si hay algún filtro activo, sino usar todos los datos
        final clientes = hasAnyFilter ? filteredClientes : snapshot.data!;

        if (clientes.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron clientes con ese criterio',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clientes.length,
          itemBuilder: (context, index) {
            final cliente = clientes[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    offset: const Offset(0, 4),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClientdetailsScreen(
                          clienteId: cliente['clie_Id'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 190,
                    child: Row(
                      children: [
                        // Imagen del cliente con overlay de estado
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              child: ClientImageCacheService().getCachedClientImage(
                                imageUrl: cliente['clie_ImagenDelNegocio'],
                                clientId: cliente['clie_Id'].toString(),
                                height: 190,
                                width: 130,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  height: 190,
                                  width: 130,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.grey[200]!,
                                        Colors.grey[300]!,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.storefront,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Badge de estado (crédito/deuda)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Builder(
                                builder: (context) {
                                  final amount = _getBadgeAmount(
                                    cliente['clie_Id'],
                                    cliente['clie_LimiteCredito'],
                                  );
                                  final badgeColor = _getBadgeColor(
                                    cliente['clie_Id'],
                                    amount: amount,
                                  );
                                  final isRed = badgeColor == Colors.red;
                                  final shouldShowSinCredito = amount == 0 && !isRed;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: badgeColor.withOpacity(0.3),
                                          offset: const Offset(0, 2),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      shouldShowSinCredito
                                          ? 'Sin crédito'
                                          : isRed
                                          ? 'L. ${amount.toStringAsFixed(2)}'
                                          : 'L. ${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // Contenido de la card
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header con nombre del negocio
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${cliente['clie_NombreNegocio'] ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          fontFamily: 'Satoshi',
                                          color: Color(0xFF141A2F),
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF141A2F).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Color(0xFF141A2F),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Información del cliente
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${cliente['clie_Nombres']} ${cliente['clie_Apellidos']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontFamily: 'Satoshi',
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 6),
                                
                                // Teléfono
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cliente['clie_Telefono'] ?? 'Sin teléfono',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    const SizedBox(height: 6)
                                  ],
                                ),
                                
                                const Spacer(),
                                
                                // Botón de acción moderno
                                Container(
                                  width: double.infinity,
                                  height: 44,
                                  child: CustomButton(
                                    text: 'Ver Detalles',
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ClientdetailsScreen(
                                            clienteId: cliente['clie_Id'],
                                          ),
                                        ),
                                      );
                                    },
                                    height: 40,
                                    fontSize: 14,
                                    width: double.infinity,
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ));
            },
        );
      }
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //drawer: CustomDrawer(permisos: permisos),
      backgroundColor: Colors.transparent,
      body: AppBackground(
        title: 'Clientes',
        icon: Icons.people,
        onRefresh: () async {
          // Limpiar filtros antes de recargar
          _searchController.clear();
          _selectedDepa = null;
          _selectedMuni = null;
          _selectedColo = null;
          await _loadAllClientData();
          if (mounted) setState(() {}); // Forzar rebuild tras refresh
        },
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilterAndCount(),
            const SizedBox(height: 16),
            _buildClientesList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF141A2F),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClientCreateScreen()),
          );

          if (result == true) {
            // Refresh the client list if a new client was added
            // Recargar toda la data usando el mismo método que initState
            await _loadAllClientData();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
        shape: const CircleBorder(),
        elevation: 4.0,
      ),
    );
  }

  // -  MÉTODO CORREGIDO - Evalúa vencimiento ANTES que monto cero
  Color _getBadgeColor(dynamic clienteId, {double? amount}) {
    print('DEBUG _getBadgeColor: clienteId=$clienteId, amount=$amount');
    if (clienteId == null) return Colors.grey;

    // Buscar cuentas por cobrar del cliente
    final cuentasCliente = _cuentasPorCobrar
        .where(
          (cuenta) =>
              cuenta['clie_Id'] == clienteId &&
              cuenta['cpCo_Anulado'] == false &&
              cuenta['cpCo_Saldada'] == false,
        )
        .toList();

    // -  EVALUAR VENCIMIENTO PRIMERO (antes de verificar si tiene cuentas)
    if (cuentasCliente.isNotEmpty) {
      final now = DateTime.now();
      bool tieneCuentaVencida = cuentasCliente.any((cuenta) {
        print(
          'DEBUG _getBadgeColor: cuenta vencimiento=${cuenta['cpCo_FechaVencimiento']}',
        );
        if (cuenta['cpCo_FechaVencimiento'] == null) return false;

        final fechaVencimiento = DateTime.tryParse(
          cuenta['cpCo_FechaVencimiento'].toString(),
        );
        if (fechaVencimiento == null) return false;

        return fechaVencimiento.isBefore(now);
      });

      // -  PRIORIDAD MÁXIMA: Rojo si tiene cuenta vencida (sin importar el monto)
      if (tieneCuentaVencida) {
        print('DEBUG _getBadgeColor: CUENTA VENCIDA -> ROJO (monto: $amount)');
        return Colors.red;
      }

      // Si tiene cuentas activas pero no vencidas -> NARANJA
      print('DEBUG _getBadgeColor: Cuenta activa no vencida -> NARANJA');
      return Colors.orange;
    }

    // Si no tiene cuentas por cobrar
    if (amount != null && amount == 0) {
      print('DEBUG _getBadgeColor: Sin cuentas y sin crédito -> GRIS');
      return Colors.grey;
    }

    // Si tiene límite de crédito disponible -> VERDE
    print('DEBUG _getBadgeColor: SIN cuentas por cobrar -> VERDE');
    return Colors.green;
  }

  double _getBadgeAmount(dynamic clienteId, dynamic limiteCredito) {
    if (clienteId == null) return 0;

    final limiteCredito_double =
        double.tryParse(limiteCredito?.toString() ?? '0') ?? 0;

    // Buscar cuentas por cobrar del cliente
    final cuentasCliente = _cuentasPorCobrar
        .where(
          (cuenta) =>
              cuenta['clie_Id'] == clienteId &&
              cuenta['cpCo_Anulado'] == false &&
              cuenta['cpCo_Saldada'] == false,
        )
        .toList();

    // Si no tiene cuentas por cobrar, mostrar el límite de crédito
    if (cuentasCliente.isEmpty) {
      return limiteCredito_double;
    }

    // Si hay cuentas por cobrar, obtener el saldo de la cuenta más reciente
    cuentasCliente.sort((a, b) {
      final fechaA =
          DateTime.tryParse(a['cpCo_Fecha']?.toString() ?? '') ??
          DateTime(1970);
      final fechaB =
          DateTime.tryParse(b['cpCo_Fecha']?.toString() ?? '') ??
          DateTime(1970);
      return fechaB.compareTo(fechaA);
    });

    final saldoReciente =
        double.tryParse(
          cuentasCliente.first['clie_Saldo']?.toString() ?? '0',
        ) ??
        0;

    // VERIFICAR SI TIENE CUENTA VENCIDA
    final now = DateTime.now();
    bool tieneCuentaVencida = cuentasCliente.any((cuenta) {
      if (cuenta['cpCo_FechaVencimiento'] == null) return false;
      final fechaVencimiento = DateTime.tryParse(
        cuenta['cpCo_FechaVencimiento'].toString(),
      );
      if (fechaVencimiento == null) return false;
      return fechaVencimiento.isBefore(now);
    });

    // Si tiene cuenta vencida, mostrar el saldo actual (cpCo_Saldo)
    if (tieneCuentaVencida) {
      print(
        'DEBUG _getBadgeAmount: CUENTA VENCIDA - Mostrando saldo actual: $saldoReciente',
      );
      return saldoReciente;
    }

    // Si tiene cuentas activas pero no vencidas, mostrar el saldo actual
    return saldoReciente;
  }

  // --- Ubicaciones networking y UI ---
  Future<void> _loadAllLocationData() async {
    try {
      // Cargar todos los datos en paralelo
      final results = await Future.wait([
        _clienteService.getDepartamentos(),
        _clienteService.getMunicipios(),
        _clienteService.getColonias(),
      ]);
      setState(() {
        _departamentos = results[0];
        _municipios = results[1]; // TODOS los municipios
        _colonias = results[2]; // TODAS las colonias
      });
      print(
        'Datos cargados - Departamentos: \\${_departamentos.length}, Municipios: \\${_municipios.length}, Colonias: \\${_colonias.length}',
      );
    } catch (e) {
      print('Error loading location data: $e');
    }
  }

  Future<void> _loadMunicipios(String depaCodigo) async {
    try {
      final list = await _clienteService.getMunicipios();
      setState(
        () => _municipios = list
            .where((m) => m['depa_Codigo'] == depaCodigo)
            .toList(),
      );
    } catch (e) {
      print('Error loading municipios: $e');
    }
  }

  Future<void> _loadColonias(String muniCodigo) async {
    try {
      final list = await _clienteService.getColonias();
      setState(
        () => _colonias = list
            .where((c) => c['muni_Codigo'] == muniCodigo)
            .toList(),
      );
    } catch (e) {
      print('Error loading colonias: $e');
    }
  }

  Widget _buildFilterSection(
    String title,
    IconData icon,
    List<dynamic> items,
    String idKey,
    String nameKey,
    String? selectedValue,
    Function(String) onSelected,
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
              Icon(
                icon,
                size: 20,
                color: const Color.fromARGB(255, 255, 255, 255),
              ),
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
              final id = item[idKey].toString();
              final name = item[nameKey] as String? ?? 'Sin nombre';
              final isSelected = selectedValue == id;

              return ChoiceChip(
                label: Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    color: isSelected
                        ? const Color(0xFF141A2F)
                        : const Color(0xFFFFFFFF),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.1,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(
                  0xFFD6B68A,
                ), // cuando está seleccionado
                backgroundColor: const Color(0xFF141A2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color.fromARGB(255, 255, 255, 255)
                        : const Color(0xFFD6B68A),
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    onSelected(id);
                  } else {
                    onSelected('');
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showLocationFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Listas filtradas para los dropdowns
            final municipiosFiltrados = _selectedDepa == null
                ? <dynamic>[]
                : _municipios
                      .where((m) => m['depa_Codigo'] == _selectedDepa)
                      .toList();
            final coloniasFiltradas = _selectedMuni == null
                ? <dynamic>[]
                : _colonias
                      .where((c) => c['muni_Codigo'] == _selectedMuni)
                      .toList();

            return GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.5,
                maxChildSize: 0.9,
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
                                'Filtrar clientes',
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
                                    _selectedDepa = null;
                                    _selectedMuni = null;
                                    _selectedColo = null;
                                  });
                                  setState(() {
                                    _selectedDepa = null;
                                    _selectedMuni = null;
                                    _selectedColo = null;
                                  });
                                  _applyAllFilters(_searchController.text);
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
                                  // Departamento section
                                  _buildFilterSection(
                                    'Departamentos',
                                    Icons.location_city,
                                    _departamentos,
                                    'depa_Codigo',
                                    'depa_Descripcion',
                                    _selectedDepa,
                                    (value) {
                                      setModalState(() {
                                        _selectedDepa = value.isEmpty
                                            ? null
                                            : value;
                                        _selectedMuni = null;
                                        _selectedColo = null;
                                      });
                                      setState(() {
                                        _selectedDepa = value.isEmpty
                                            ? null
                                            : value;
                                        _selectedMuni = null;
                                        _selectedColo = null;
                                      });
                                    },
                                  ),

                                  // Municipio section
                                  _buildFilterSection(
                                    'Municipios',
                                    Icons.apartment,
                                    municipiosFiltrados,
                                    'muni_Codigo',
                                    'muni_Descripcion',
                                    _selectedMuni,
                                    (value) {
                                      setModalState(() {
                                        _selectedMuni = value.isEmpty
                                            ? null
                                            : value;
                                        _selectedColo = null;
                                      });
                                      setState(() {
                                        _selectedMuni = value.isEmpty
                                            ? null
                                            : value;
                                        _selectedColo = null;
                                      });
                                    },
                                  ),

                                  // Colonia section
                                  _buildFilterSection(
                                    'Colonias',
                                    Icons.home_work,
                                    coloniasFiltradas,
                                    'colo_Id',
                                    'colo_Descripcion',
                                    _selectedColo?.toString(),
                                    (value) {
                                      final intValue = value.isEmpty
                                          ? null
                                          : int.tryParse(value);
                                      setModalState(
                                        () => _selectedColo = intValue,
                                      );
                                      setState(() => _selectedColo = intValue);
                                    },
                                  ),

                                  // Apply button
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _applyAllFilters(
                                          _searchController.text,
                                        );
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
                                      child: const Text('Aplicar filtros'),
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
              ));
            },
          );
        },
    );
  }
} 
