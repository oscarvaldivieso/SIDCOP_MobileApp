import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';

class PedidosCreateScreen extends StatelessWidget {
  final int clienteId;
  const PedidosCreateScreen({Key? key, required this.clienteId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Nuevo Pedido',
      icon: Icons.add_shopping_cart,
      child: Center(
        child: Text(
          'Id cliente #$clienteId',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
