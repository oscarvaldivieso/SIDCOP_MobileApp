import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/clientdetails_screen.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/clientcreate_screen.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class clientScreen extends StatefulWidget {
  const clientScreen({super.key});

  @override
  State<clientScreen> createState() => _clientScreenState();
}

class _clientScreenState extends State<clientScreen> {
  late Future<List<dynamic>> clientesList;
  List<dynamic> filteredClientes = [];
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;
  List<dynamic> permisos = [];

  @override
  void initState() {
    super.initState();
    _loadPermisos();
    clientesList = ClientesService().getClientes();
    clientesList.then((clientes) {
      setState(() {
        filteredClientes = clientes;
      });
    });
  }

  Future<void> _loadPermisos() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    if (userData != null &&
        (userData['PermisosJson'] != null ||
            userData['permisosJson'] != null)) {
      try {
        final permisosJson =
            userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterClientes(String query) {
    clientesList.then((clientes) {
      setState(() {
        if (query.isEmpty) {
          filteredClientes = clientes;
        } else {
          filteredClientes = clientes.where((cliente) {
            final nombreNegocio =
                cliente['clie_NombreNegocio']?.toString().toLowerCase() ?? '';
            final direccion =
                cliente['clie_DireccionExacta']?.toString().toLowerCase() ?? '';
            final searchLower = query.toLowerCase();
            return nombreNegocio.contains(searchLower) ||
                direccion.contains(searchLower);
          }).toList();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: CustomDrawer(permisos: permisos),
      backgroundColor: const Color(0xFFF6F6F6),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF141A2F),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClientCreateScreen()),
          );

          if (result == true) {
            // Refresh the client list if a new client was added
            setState(() {
              clientesList = ClientesService().getClientes();
              clientesList.then((clientes) {
                _filterClientes(_searchController.text);
              });
            });
          }
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
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF141A2F),
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage('assets/asset-breadcrumb.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Clientes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const Icon(Icons.people, color: Colors.white, size: 30),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
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
                  // Usar la lista filtrada en lugar de la original
                  final clientes =
                      filteredClientes.isEmpty && _searchController.text.isEmpty
                      ? snapshot.data!
                      : filteredClientes;

                  if (clientes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron clientes con ese criterio',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: clientes.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    itemBuilder: (context, index) {
                      final cliente = clientes[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClientdetailsScreen(
                                clienteId: cliente['clie_Id'],
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Image on the left
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        cliente['clie_ImagenDelNegocio'] ?? '',
                                    width: 140,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 140,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          width: 140,
                                          color: Colors.grey[200],
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cliente['clie_NombreNegocio'] ??
                                                  'Sin nombre',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              cliente['clie_DireccionExacta'] ??
                                                  'Sin dirección',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const Spacer(),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 36,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF141A2F,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          ClientdetailsScreen(
                                                            clienteId:
                                                                cliente['clie_Id'],
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: const Text(
                                                  'Detalles',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFFD6B68A),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Badge de monto
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getBadgeColor(
                                                cliente['clie_Monto'],
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    bottomLeft: Radius.circular(
                                                      8,
                                                    ),
                                                    topRight: Radius.circular(
                                                      16,
                                                    ),
                                                  ),
                                            ),
                                            child: Text(
                                              'L. ${(cliente['clie_Monto'] ?? 0).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(dynamic monto) {
    if (monto == null) return Colors.grey;
    final value = double.tryParse(monto.toString()) ?? 0;
    if (value >= 5000) return Colors.green;
    if (value >= 1700) return Colors.orange;
    return Colors.red;
  }
}
