# Ejemplo Completo: Información de Usuario Offline/Online en Flutter

Este ejemplo muestra cómo implementar una pantalla de información de usuario que funciona completamente offline pero se sincroniza automáticamente con la API cuando hay internet disponible.

## 🎯 Características Principales

- **Offline-First**: Siempre lee desde el almacenamiento local (FlutterSecureStorage)
- **Sincronización Automática**: Se actualiza cada 5 minutos cuando hay internet
- **Actualizaciones en Tiempo Real**: Usa Streams para notificar cambios
- **Monitoreo de Conectividad**: Detecta automáticamente cambios de conexión
- **Persistencia Segura**: Datos guardados en FlutterSecureStorage
- **Patrón Singleton**: Un solo servicio para toda la aplicación

## 📁 Archivos Creados

### 1. `UserInfoService.dart` - Servicio Principal
Maneja toda la lógica offline/online:

```dart
// Inicializar el servicio
final userService = UserInfoService();
await userService.initialize();

// Escuchar cambios de datos
userService.userDataStream.listen((userData) {
  // Actualizar UI automáticamente
});

// Escuchar cambios de conectividad
userService.connectivityStream.listen((isConnected) {
  // Mostrar estado de conexión
});
```

### 2. `UserInfoScreen.Dart` - Pantalla Actualizada
Pantalla que usa el nuevo servicio:

- Indicador visual de conectividad (Online/Offline)
- Botón de actualización manual
- Datos que se actualizan automáticamente
- Manejo de estados de carga

### 3. `UserInfoExample.dart` - Ejemplo de Uso
Demostración completa con:

- Estado del servicio en tiempo real
- Controles de prueba
- Información técnica
- Datos del usuario formateados

## 🚀 Cómo Usar

### Paso 1: Inicializar en tu App
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar el servicio al inicio de la app
  final userService = UserInfoService();
  await userService.initialize();
  
  runApp(MyApp());
}
```

### Paso 2: Usar en cualquier Widget
```dart
class MiWidget extends StatefulWidget {
  @override
  _MiWidgetState createState() => _MiWidgetState();
}

class _MiWidgetState extends State<MiWidget> {
  final UserInfoService _userService = UserInfoService();
  Map<String, dynamic> _userData = {};
  
  @override
  void initState() {
    super.initState();
    
    // Escuchar cambios automáticos
    _userService.userDataStream.listen((data) {
      setState(() {
        _userData = data;
      });
    });
    
    // Cargar datos iniciales
    _userData = _userService.cachedUserData ?? {};
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Nombre: ${_userData['nombreCompleto'] ?? 'Cargando...'}'),
        Text('Cargo: ${_userData['cargo'] ?? 'Cargando...'}'),
        // ... más campos
      ],
    );
  }
}
```

### Paso 3: Obtener Campos Específicos
```dart
// Método seguro para obtener campos
String getNombreUsuario() {
  return _userService.getUserField('nombreCompleto', defaultValue: 'Usuario');
}

String getCargoUsuario() {
  return _userService.getUserField('cargo', defaultValue: 'Sin cargo');
}
```

## 📊 Campos Disponibles

El servicio proporciona los siguientes campos:

### Datos Personales
- `nombreCompleto`
- `numeroIdentidad`
- `numeroEmpleado`
- `correo`
- `telefono`
- `cargo`
- `imagenUsuario`

### Datos Laborales
- `rutaAsignada`
- `supervisorResponsable`

### Información Operativa
- `inventarioAsignado`
- `clientesAsignados`
- `metaVentasDiaria`
- `ventasDelDia`
- `ultimaRecargaSolicitada`

### Metadatos
- `fechaGeneracion`
- `fechaUltimaSync`

## 🔄 Flujo de Funcionamiento

1. **Inicio**: El servicio lee datos del caché local (FlutterSecureStorage)
2. **Conectividad**: Monitorea cambios de conexión automáticamente
3. **Sincronización**: Cada 5 minutos actualiza desde la API si hay internet
4. **Notificaciones**: Envía actualizaciones via Streams a todos los listeners
5. **Persistencia**: Guarda cambios automáticamente en el caché local

## 🛠 Métodos Principales

### UserInfoService

```dart
// Inicializar servicio
await userService.initialize();

// Forzar actualización
await userService.forceRefresh();

// Obtener campo específico
String valor = userService.getUserField('nombreCompleto');

// Verificar si datos están frescos
bool esFresco = userService.isDataFresh();

// Obtener estado del servicio
Map<String, dynamic> estado = userService.getServiceStatus();

// Limpiar y reiniciar
await userService.clearAndReset();
```

### Streams Disponibles

```dart
// Stream de datos de usuario
userService.userDataStream.listen((Map<String, dynamic> data) {
  // Datos actualizados
});

// Stream de conectividad
userService.connectivityStream.listen((bool isConnected) {
  // Estado de conexión
});
```

## 🎨 Características de UI

### Indicador de Conectividad
- 🟢 **Online**: Icono WiFi verde + texto "Online"
- 🔴 **Offline**: Icono WiFi tachado rojo + texto "Offline"

### Botón de Actualización
- Muestra spinner cuando está cargando
- Deshabilitado durante la carga
- Actualización manual disponible

### Datos Dinámicos
- Se actualizan automáticamente sin recargar la pantalla
- Muestran "Sin información" cuando no hay datos
- Formato consistente en toda la aplicación

## 🔧 Configuración

### Dependencias Requeridas
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  connectivity_plus: ^4.0.2
  http: ^1.1.0
```

### Permisos (Android)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## 📱 Ejemplo de Uso Completo

Para ver el ejemplo funcionando:

1. Navega a `UserInfoExample.dart`
2. Ejecuta la aplicación
3. Observa cómo los datos se cargan desde el caché
4. Desconecta/conecta internet para ver la sincronización automática
5. Usa el botón "Actualizar" para forzar una sincronización

## 🐛 Manejo de Errores

El servicio maneja automáticamente:
- Errores de conexión de red
- Datos corruptos en caché
- Fallos de sincronización
- Estados de carga inconsistentes

## 📈 Beneficios

1. **Experiencia de Usuario**: Funciona sin internet
2. **Rendimiento**: Carga instantánea desde caché
3. **Sincronización**: Datos siempre actualizados cuando es posible
4. **Mantenibilidad**: Código centralizado y reutilizable
5. **Escalabilidad**: Fácil de extender con nuevos campos

## 🔍 Debugging

Para debug, el servicio imprime logs detallados:
```
=== INICIALIZANDO UserInfoService ===
Cargando datos desde caché local...
✓ Datos cargados desde caché: 15 campos
Estado inicial de conectividad: Conectado
=== INICIANDO SINCRONIZACIÓN CON API ===
✓ Sincronización con API completada exitosamente
```

Este ejemplo proporciona una base sólida para cualquier aplicación que necesite manejar información de usuario de forma offline-first con sincronización automática.
