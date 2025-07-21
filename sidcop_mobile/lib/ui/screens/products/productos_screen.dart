// import 'package:flutter/material.dart';
// import 'package:sidcop_mobile/models/ProductosViewModel.dart';
// import 'package:sidcop_mobile/services/ProductosService.dart';
// import 'dart:convert';

// class ProductosScreen extends StatefulWidget {
//   const ProductosScreen({Key? key}) : super(key: key);

//   @override
//   State<ProductosScreen> createState() => _ProductosScreenState();
// }

// class _ProductosScreenState extends State<ProductosScreen> {
//   late Future<List<Productos>> productosList;
//   String? selectedCategoria;
//   String? selectedMarca;

//   @override
//   void initState() {
//     super.initState();
//     productosList = ProductosService().getProductos();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Lista de Productos')),
//       body: Column(
//         children: [
//           const SizedBox(height: 10),

//           // Filtro de Categoría
//           DropdownButton<String>(
//             hint: const Text("Selecciona una categoría"),
//             value: selectedCategoria,
//             onChanged: (value) {
//               setState(() {
//                 selectedCategoria = value;
//               });
//             },
//             items:
//                 ['1', '2', '3'] // Sustituir con IDs reales
//                     .map(
//                       (categoria) => DropdownMenuItem(
//                         value: categoria,
//                         child: Text('Categoría $categoria'),
//                       ),
//                     )
//                     .toList(),
//           ),

//           // Filtro de Marca
//           DropdownButton<String>(
//             hint: const Text("Selecciona una marca"),
//             value: selectedMarca,
//             onChanged: (value) {
//               setState(() {
//                 selectedMarca = value;
//               });
//             },
//             items:
//                 ['1', '2', '3'] // Sustituir con IDs reales
//                     .map(
//                       (marca) => DropdownMenuItem(
//                         value: marca,
//                         child: Text('Marca $marca'),
//                       ),
//                     )
//                     .toList(),
//           ),

//           const SizedBox(height: 10),

//           Expanded(
//             child: FutureBuilder<List<Productos>>(
//               future: productosList,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 } else if (snapshot.hasError) {
//                   return Center(child: Text('Error: ${snapshot.error}'));
//                 } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(
//                     child: Text('No hay productos disponibles'),
//                   );
//                 }

//                 // Aplicar filtros
//                 final filteredProducts = snapshot.data!.where((producto) {
//                   final coincideCategoria =
//                       selectedCategoria == null ||
//                       producto.cate_Id.toString() == selectedCategoria;
//                   final coincideMarca =
//                       selectedMarca == null ||
//                       producto.marc_Id.toString() == selectedMarca;
//                   return coincideCategoria && coincideMarca;
//                 }).toList();

//                 return ListView.builder(
//                   itemCount: filteredProducts.length,
//                   itemBuilder: (context, index) {
//                     final producto = filteredProducts[index];
//                     return Card(
//                       margin: const EdgeInsets.symmetric(
//                         horizontal: 10,
//                         vertical: 5,
//                       ),

//                       child: ListTile(
//                         title: Text(producto.prod_Descripcion ?? ''),
//                         subtitle: Text(
//                           'Precio: L.${producto.prod_PrecioUnitario?.toStringAsFixed(2) ?? "0.00"}',
//                         ),
//                         trailing: Text('Stock: ${producto.prod_Codigo ?? 0}'),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
