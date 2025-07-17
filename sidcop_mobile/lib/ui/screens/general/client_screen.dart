import 'package:flutter/material.dart';

import 'package:flutter/material.dart';


class clientScreen extends StatefulWidget
{
    const clientScreen({Key? key}) : super(key: key);
    @override
    State<clientScreen> createState() => _clientScreenState();
}

class _clientScreenState extends State<clientScreen> 
{
  // Aquí van las variables de estado

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejemplo de clientScreen'),
      ),
      body: Center(
        // Center solo acepta un child
        child: Column(
          // Column acepta varios widgets en children
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hola, este es un ejemplo'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: Text('Botón de ejemplo'),
            ),
          ],
        ),
      ),
    );
  }
}