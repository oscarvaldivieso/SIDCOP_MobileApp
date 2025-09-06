import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientImageCacheService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.Dart';

/// Ejemplo de uso del servicio de caché de imágenes de clientes
class ClientImageCacheExample extends StatefulWidget {
  @override
  _ClientImageCacheExampleState createState() => _ClientImageCacheExampleState();
}

class _ClientImageCacheExampleState extends State<ClientImageCacheExample> {
  final ClientImageCacheService _imageService = ClientImageCacheService();
  List<Cliente> _clients = [];
  bool _isLoading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando clientes...';
    });

    try {
      final clientsData = await SyncService.getClients();
      final clients = clientsData.map((data) => Cliente.fromJson(data)).toList();
      
      setState(() {
        _clients = clients;
        _status = 'Clientes cargados: ${clients.length}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error cargando clientes: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cacheAllImages() async {
    setState(() {
      _isLoading = true;
      _status = 'Cacheando imágenes...';
    });

    try {
      final success = await _imageService.cacheAllClientImages(_clients);
      setState(() {
        _status = success 
          ? 'Imágenes cacheadas exitosamente'
          : 'Error cacheando imágenes';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _status = 'Limpiando caché...';
    });

    try {
      await _imageService.clearImageCache();
      setState(() {
        _status = 'Caché limpiado';
      });
    } catch (e) {
      setState(() {
        _status = 'Error limpiando caché: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Caché de Imágenes de Clientes'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Estado: $_status',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    if (_isLoading)
                      CircularProgressIndicator()
                    else
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: _loadClients,
                            child: Text('Cargar Clientes'),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _clients.isNotEmpty ? _cacheAllImages : null,
                            child: Text('Cachear Todas las Imágenes'),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _clearCache,
                            child: Text('Limpiar Caché'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _clients.length,
                itemBuilder: (context, index) {
                  final client = _clients[index];
                  return Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: _imageService.getCachedClientImage(
                          imageUrl: client.clie_ImagenDelNegocio,
                          clientId: client.clie_Id.toString(),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(client.clie_NombreNegocio ?? 'Sin nombre'),
                      subtitle: Text(client.clie_Nombres ?? 'Sin nombres'),
                      trailing: FutureBuilder<bool>(
                        future: _imageService.isImageCached(
                          client.clie_ImagenDelNegocio ?? '',
                          client.clie_Id.toString(),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data == true) {
                            return Icon(Icons.check_circle, color: Colors.green);
                          }
                          return Icon(Icons.cloud_download, color: Colors.grey);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
