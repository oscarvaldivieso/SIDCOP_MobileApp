import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';

class clientScreen extends StatefulWidget {
  const clientScreen({Key? key}) : super(key: key);

  @override
  State<clientScreen> createState() => _clientScreenState();
}

class _clientScreenState extends State<clientScreen> {
  late Future<List<dynamic>> clientesList;

  @override
  void initState() {
    super.initState();
    clientesList = ClientesService().getClientes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder<List<dynamic>>(
        future: clientesList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay clientes'));
          } else {
            final clientes = snapshot.data!;
            return ListView.builder(
              itemCount: clientes.length,
              itemBuilder: (context, index) {
                final cliente = clientes[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(
                        'https://link-invalido.com/imagen.png',
                      ),
                    ),
                    title: Text(
                      '${cliente['clie_Nombres'] ?? ''} ${cliente['clie_Apellidos'] ?? ''}',
                    ),
                    subtitle: Text(cliente['clie_Correo'] ?? ''),
                    trailing: Text(cliente['clie_Telefono'] ?? ''),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
