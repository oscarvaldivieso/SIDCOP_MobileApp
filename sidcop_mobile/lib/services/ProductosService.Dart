import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart'; 
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';


class ProductosService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;
  
Future<List<Productos>> getProductos() async {


    final url = Uri.parse('$_apiServer/Productos/Listar');
    developer.log('Get Productos Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );

      developer.log('Get Productos Response Status: ${response.statusCode}');
      developer.log('Get Productos Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          developer.log('Response body is empty');
          return [];
        }
        
        final List<dynamic> productosList = jsonDecode(responseBody);
 return productosList
    .map((json) => Productos.fromJson(json as Map<String, dynamic>))
    .toList();

      } else {
        throw Exception(
          'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Productos Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCategorias() async {
    final url = Uri.parse('$_apiServer/Categorias/Listar');
    developer.log('Get Categorias Request URL: $url');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );

      developer.log('Get Categorias Response Status: ${response.statusCode}');
      developer.log('Get Categorias Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }
        
        final List<dynamic> categoriasList = jsonDecode(responseBody);
        return List<Map<String, dynamic>>.from(
          categoriasList.map((item) => item as Map<String, dynamic>)
        );
      } else {
        throw Exception('Error al obtener categorías: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Get Categorias Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMarcas() async {
    final url = Uri.parse('$_apiServer/Marcas/Listar');
    developer.log('Get Marcas Request URL: $url');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );

      developer.log('Get Marcas Response Status: ${response.statusCode}');
      developer.log('Get Marcas Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }
        
        final List<dynamic> marcasList = jsonDecode(responseBody);
        return List<Map<String, dynamic>>.from(
          marcasList.map((item) => item as Map<String, dynamic>)
        );
      } else {
        throw Exception('Error al obtener marcas: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Get Marcas Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSubcategorias() async {
    final url = Uri.parse('$_apiServer/Subcategoria/Listar');
    developer.log('Get Subcategorias Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'X-Api-Key': _apiKey
        },
      );

      developer.log('Get Subcategorias Response Status: ${response.statusCode}');
      developer.log('Get Subcategorias Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return [];
        }
        
        final List<dynamic> subcategoriasList = jsonDecode(responseBody);
        return List<Map<String, dynamic>>.from(
          subcategoriasList.map((item) => item as Map<String, dynamic>)
        );
      } else {
        throw Exception('Error al obtener subcategorías: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Get Subcategorias Error: $e');
      rethrow;
    }
  }

  /// Obtiene los productos asociados a una factura específica
  Future<List<Map<String, dynamic>>> getProductosPorFactura(int facturaId) async {
    final url = Uri.parse('$_apiServer/Productos/BuscarPorFactura/$facturaId');
    developer.log('Get Productos por Factura Request URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );

      developer.log('Get Productos por Factura Response Status: ${response.statusCode}');
      developer.log('Get Productos por Factura Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          developer.log('Response body is empty');
          return [];
        }
        
        final List<dynamic> productosList = jsonDecode(responseBody);
        return List<Map<String, dynamic>>.from(productosList);
      } else {
        throw Exception(
          'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Get Productos por Factura Error: $e');
      rethrow;
    }
  }

  Future<List<ProductoConDescuento>> getProductosConDescuentoPorClienteVendedor(int clieId, int vendId) async {
  final url = Uri.parse('$_apiServer/Productos/ProductosDescuentoPorClienteVendedor/$clieId/$vendId');
  developer.log('Get Productos con Descuento Request URL: $url');

  try {
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey
      },
    );

    developer.log('Get Productos con Descuento Response Status: ${response.statusCode}');
    developer.log('Get Productos con Descuento Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseBody = response.body;
      if (responseBody.isEmpty) {
        developer.log('Response body is empty');
        return [];
      }
      
      final List<dynamic> productosList = jsonDecode(responseBody);
      return productosList
          .map((json) => ProductoConDescuento.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        'Error en la solicitud: Código ${response.statusCode}, Respuesta: ${response.body}',
      );
    }
  } catch (e) {
    developer.log('Error en getProductosConDescuentoPorClienteVendedor: $e');
    rethrow;
  }
}
 

  
}