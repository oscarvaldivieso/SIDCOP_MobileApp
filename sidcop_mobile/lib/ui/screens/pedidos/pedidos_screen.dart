import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';

class PedidosScreen extends StatelessWidget {
  const PedidosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Pedidos',
      icon: Icons.assignment,
      child: const Center(child: Text('Pantalla de Pedidos')),
    );
  }
}
