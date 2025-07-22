import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';

class ProductDetailScreen extends StatelessWidget {
  final Productos product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.prod_Descripcion ?? 'Detalle del Producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen principal
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  product.prod_Imagen ?? '',
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Información del producto
            Text(
              product.prod_Descripcion ?? 'Sin descripción',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Código: ${product.prod_Codigo ?? 'No especificada'}',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 8),
            Text(
              'Marca: ${product.marc_Descripcion ?? 'No especificada'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Categoría: ${product.cate_Descripcion ?? 'No especificada'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Proveedor: ${product.prov_NombreEmpresa ?? 'No especificada'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Descripción: ${product.prod_DescripcionCorta ?? 'No especificada'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'L. ${product.prod_PrecioUnitario.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),

            // Botón de acción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),

                child: const Text('Solicitar Recarga'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
