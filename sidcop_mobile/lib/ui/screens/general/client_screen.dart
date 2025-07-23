import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';

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

  @override
  void initState() {
    super.initState();
    clientesList = ClientesService().getClientes();
    clientesList.then((clientes) {
      setState(() {
        filteredClientes = clientes;
      });
    });
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
            final nombreNegocio = cliente['clie_NombreNegocio']?.toString().toLowerCase() ?? '';
            final direccion = cliente['clie_DireccionExacta']?.toString().toLowerCase() ?? '';
            final searchLower = query.toLowerCase();
            return nombreNegocio.contains(searchLower) || direccion.contains(searchLower);
          }).toList();
        }
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                    Icon(Icons.people, color: Colors.white, size: 30),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF141A2F)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF141A2F)),
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
            final clientes = filteredClientes.isEmpty && _searchController.text.isEmpty ? snapshot.data! : filteredClientes;
            
            if (clientes.isEmpty) {
              return const Center(child: Text('No se encontraron clientes con ese criterio'));
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView.builder(
                itemCount: clientes.length,
                itemBuilder: (context, index) {
                final cliente = clientes[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 140,
                              width: 140,
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 40, color: Colors.grey),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         const SizedBox(height: 10),
                                        Text(
                                          '${cliente['clie_NombreNegocio'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                    cliente['clie_DireccionExacta'] ?? 'Sin dirección',
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
                                          backgroundColor: const Color(0xFF141A2F),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getBadgeColor(cliente['clie_Monto']), 
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      topLeft: Radius.circular(0),
                                      bottomRight: Radius.circular(0),
                                    ),
                                  ),
                                  child: Text(
                                    'L. 	${(cliente['clie_Monto'] ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
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

  Color _getBadgeColor(dynamic monto) {
    if (monto == null) return Colors.grey;
    final value = double.tryParse(monto.toString()) ?? 0;
    if (value >= 5000) return Colors.green;
    if (value >= 1700) return Colors.orange;
    return Colors.red;
  }
  

}