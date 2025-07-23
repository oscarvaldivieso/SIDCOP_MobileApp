import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:flutter_svg/svg.dart';

class clientScreen extends StatefulWidget {
  const clientScreen({Key? key}) : super(key: key);

  @override
  State<clientScreen> createState() => _clientScreenState();
}

class _clientScreenState extends State<clientScreen> {
  late Future<List<dynamic>> clientesList;
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
    clientesList = ClientesService().getClientes();
    // Cargar TODOS los datos de ubicación al inicializar - REEMPLAZA _loadDepartamentos();
    _loadAllLocationData();
    
    // Cargar cuentas por cobrar
    _clienteService.getCuentasPorCobrar().then((cuentas) {
      setState(() {
        _cuentasPorCobrar = cuentas;
      });
    });
    
    // Cargar direccionesPorCliente antes de inicializar la lista filtrada
    _clienteService.getDireccionesPorCliente().then((direcciones) {
      setState(() {
        _direccionesPorCliente = direcciones;
      });
      clientesList.then((clientes) {
        setState(() {
          filteredClientes = clientes;
        });
      });
    });
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
    
    // Verificar datos cargados
    print('Datos disponibles - Departamentos: ${_departamentos.length}, Municipios: ${_municipios.length}, Colonias: ${_colonias.length}, Direcciones: ${_direccionesPorCliente.length}');
    
    // Si hay municipio seleccionado, mostrar colonias de ese municipio
    if (_selectedMuni != null) {
      final coloniasDelMunicipio = _colonias.where((c) => c['muni_Codigo'] == _selectedMuni).toList();
      print('Colonias en municipio $_selectedMuni: ${coloniasDelMunicipio.length}');
      if (coloniasDelMunicipio.isNotEmpty) {
        print('Ejemplo de colonia: ${coloniasDelMunicipio.first}');
      }
    }

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
            final bool clienteTieneMunicipioSeleccionado = direccionesCliente
                .any((direccionCliente) {
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
                    print('No se encontró la colonia $coloId para el cliente ${cliente['clie_Id']}');
                    return false;
                  }

                  // Verificar si la colonia pertenece al municipio seleccionado
                  final String? muniCodigo = colonia['muni_Codigo'];
                  final bool coincideMunicipio = muniCodigo == _selectedMuni;
                  
                  if (coincideMunicipio) {
                    print('Cliente ${cliente['clie_Id']} tiene dirección en colonia $coloId que pertenece al municipio $_selectedMuni');
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
            final bool clienteTieneDepartamentoSeleccionado = direccionesCliente
                .any((direccionCliente) {
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
                    print('Error al buscar colonia $coloId para filtro de departamento: $e');
                    return false;
                  }

                  if (colonia.isEmpty) {
                    print('No se encontró la colonia $coloId para el cliente ${cliente['clie_Id']} en filtro de departamento');
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
                    print('No se encontró el municipio $muniCodigo para el cliente ${cliente['clie_Id']}');
                    return false;
                  }

                  final String? depaCodigo = municipio['depa_Codigo'];
                  final bool coincideDepartamento = depaCodigo == _selectedDepa;
                  
                  if (coincideDepartamento) {
                    print('Cliente ${cliente['clie_Id']} tiene dirección en colonia $coloId, municipio $muniCodigo que pertenece al departamento $_selectedDepa');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: const CustomDrawer(),
      backgroundColor: const Color(0xFFF6F6F6),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF141A2F),
        onPressed: () {
          // Acción para agregar un nuevo cliente
        },
        shape: const CircleBorder(),
        elevation: 4.0,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Card.filled(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              color: const Color(0xFF141A2F),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.18,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Transform.flip(
                        flipX: true,
                        child: SvgPicture.asset(
                          'BreadCrumSVG2.svg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          'Clientes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Satoshi',
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 12,
                      right: 18,
                      child: Icon(
                        Icons.people,
                        color: Color(0xFFE0C7A0),
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterClientes,
                      decoration: InputDecoration(
                        hintText: 'Filtrar por nombre...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF141A2F),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Color(0xFF141A2F),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterClientes('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt, color: Color(0xFF141A2F)),
                  onPressed: _showLocationFilters,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: clientesList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay clientes'));
                } else {
                  // Verificar si hay algún filtro activo (texto o ubicación)
                  final bool hasTextFilter = _searchController.text.isNotEmpty;
                  final bool hasLocationFilter = _selectedDepa != null || _selectedMuni != null || _selectedColo != null;
                  final bool hasAnyFilter = hasTextFilter || hasLocationFilter;
                  
                  // Usar la lista filtrada si hay algún filtro activo, sino usar todos los datos
                  final clientes = hasAnyFilter ? filteredClientes : snapshot.data!;

                  if (clientes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron clientes con ese criterio',
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      itemCount: clientes.length,
                      itemBuilder: (context, index) {
                        final cliente = clientes[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: SizedBox(
                            height: 140,
                            child: Row(
                              children: [
                                // Image on the left
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    '${cliente['clie_ImagenDelNegocio'] ?? ''}',
                                    height: 140,
                                    width: 140, // Fixed width for the image
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 140,
                                              width: 140,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.person,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                  ),
                                ),
                                // Content on the right
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 10),
                                                Text(
                                                  '${cliente['clie_NombreNegocio'] ?? ''}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  cliente['clie_Nombres'] + ' ' + cliente['clie_Apellidos'] ??
                                                      'Sin dirección',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 40,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF141A2F,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                ),
                                                onPressed: () {},
                                                child: const Text(
                                                  'Detalles',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFFD6B68A),
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Badge de monto
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Builder(builder: (context) {
                                          final amount = _getBadgeAmount(cliente['clie_Id'], cliente['clie_LimiteCredito']);
                                          final isZero = amount == 0;
                                          
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getBadgeColor(
                                                cliente['clie_Id'],
                                                amount: amount,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topRight: Radius.circular(16),
                                                    bottomLeft: Radius.circular(
                                                      16,
                                                    ),
                                                    topLeft: Radius.circular(0),
                                                    bottomRight: Radius.circular(
                                                      0,
                                                    ),
                                                  ),
                                            ),
                                            child: Text(
                                              isZero ? 'Sin crédito' : 'L. ${amount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(dynamic clienteId, {double? amount}) {
    if (clienteId == null) return Colors.grey;
    
    // Si el monto es 0, mostrar gris (sin crédito)
    if (amount != null && amount == 0) {
      return Colors.grey;
    }
    
    // Buscar cuentas por cobrar del cliente
    final cuentasCliente = _cuentasPorCobrar.where((cuenta) => 
      cuenta['Clie_Id'] == clienteId && 
      cuenta['CPCo_Anulado'] == false && 
      cuenta['CPCo_Saldada'] == false
    ).toList();
    
    // Si no tiene cuentas por cobrar, mostrar verde (solo tiene crédito disponible)
    if (cuentasCliente.isEmpty) {
      return Colors.green;
    }
    
    // Verificar si tiene alguna cuenta vencida
    final now = DateTime.now();
    bool tieneCuentaVencida = cuentasCliente.any((cuenta) {
      if (cuenta['CPCo_FechaVencimiento'] == null) return false;
      
      final fechaVencimiento = DateTime.tryParse(cuenta['CPCo_FechaVencimiento'].toString());
      if (fechaVencimiento == null) return false;
      
      return fechaVencimiento.isBefore(now);
    });
    
    // Rojo si tiene cuenta vencida, naranja si tiene cuenta por cobrar pero no vencida
    return tieneCuentaVencida ? Colors.red : Colors.orange;
  }
  
  double _getBadgeAmount(dynamic clienteId, dynamic limiteCredito) {
    if (clienteId == null) return 0;
    
    // Buscar cuentas por cobrar del cliente
    final cuentasCliente = _cuentasPorCobrar.where((cuenta) => 
      cuenta['Clie_Id'] == clienteId && 
      cuenta['CPCo_Anulado'] == false && 
      cuenta['CPCo_Saldada'] == false
    ).toList();
    
    // Si no tiene cuentas por cobrar, mostrar el límite de crédito
    if (cuentasCliente.isEmpty) {
      return double.tryParse(limiteCredito?.toString() ?? '0') ?? 0;
    }
    
    // Sumar los saldos de todas las cuentas por cobrar
    double totalSaldo = 0;
    for (var cuenta in cuentasCliente) {
      final saldo = double.tryParse(cuenta['CPCo_Saldo']?.toString() ?? '0') ?? 0;
      totalSaldo += saldo;
    }
    
    return totalSaldo;
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

  void _showLocationFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filtros de Ubicación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Dropdown Departamento
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                    ),
                    value: _selectedDepa,
                    items: _departamentos.map<DropdownMenuItem<String>>((d) {
                      return DropdownMenuItem<String>(
                        value: d['depa_Codigo'],
                        child: Text(d['depa_Descripcion']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedDepa = value;
                        _selectedMuni = null;
                        _selectedColo = null;
                      });
                      setState(() {
                        _selectedDepa = value;
                        _selectedMuni = null;
                        _selectedColo = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Dropdown Municipio
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Municipio'),
                    value: _selectedMuni,
                    items: municipiosFiltrados.map<DropdownMenuItem<String>>((
                      m,
                    ) {
                      return DropdownMenuItem<String>(
                        value: m['muni_Codigo'],
                        child: Text(m['muni_Descripcion']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedMuni = value;
                        _selectedColo = null;
                      });
                      setState(() {
                        _selectedMuni = value;
                        _selectedColo = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Dropdown Colonia
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Colonia'),
                    value: _selectedColo,
                    items: coloniasFiltradas.map<DropdownMenuItem<int>>((c) {
                      return DropdownMenuItem<int>(
                        value: c['colo_Id'],
                        child: Text(c['colo_Descripcion']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() => _selectedColo = value);
                      setState(() => _selectedColo = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                        child: const Text('Limpiar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyAllFilters(_searchController.text);
                        },
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
