

import 'package:flutter/material.dart';
import 'general/client_screen.dart';
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
