import 'package:flutter/material.dart';
import 'general/Clientes/client_screen.dart';
import 'products/products_list_screen.dart';
import '../widgets/appBar.dart';
import '../widgets/drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: const CustomDrawer(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const clientScreen()),
                );
              },
              child: const Text('Ir a Client Screen'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute( builder: (context) => const ProductScreen()),
                );
              },
              child: const Text('Ir a Productos Screen'),
            ),
          ],
        ),
      ),
    );
  }
}
