

import 'package:flutter/material.dart';
import 'general/client_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const clientScreen()),
            );
          },
          child: const Text('Ir a Client Screen'),
        ),
      ),
    );
  }
}
