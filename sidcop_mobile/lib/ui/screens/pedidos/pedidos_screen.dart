import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Pedidos',
      icon: Icons.assignment,
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        child: const Center(child: Text('Pantalla de Pedidos')),
      ),
    );
  }
}
