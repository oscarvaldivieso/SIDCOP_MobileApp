import 'package:flutter/material.dart';

/// Servicio para manejar la navegación global en la aplicación
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Navega a una ruta con nombre
  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }
  
  /// Navega a una ruta reemplazando la actual
  static Future<dynamic> navigateToReplace(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
  }
  
  /// Navega hacia atrás
  static void goBack() {
    return navigatorKey.currentState!.pop();
  }
  
  /// Navega hacia atrás con resultado
  static void goBackWithResult(dynamic result) {
    return navigatorKey.currentState!.pop(result);
  }
  
  /// Navega hacia atrás hasta una ruta específica
  static void goBackUntil(String routeName) {
    return navigatorKey.currentState!.popUntil(
      (route) => route.settings.name == routeName,
    );
  }
}
