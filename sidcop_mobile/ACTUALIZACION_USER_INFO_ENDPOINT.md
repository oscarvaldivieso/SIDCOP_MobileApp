# Actualización UserInfoScreen con Endpoint /Usuarios/IniciarSesion

## 🚀 Cambios Implementados

### 1. **PerfilUsuarioService.Dart**
Se agregaron dos nuevos métodos:

```dart
// Ejecuta el endpoint /Usuarios/IniciarSesion para obtener información completa
Future<Map<String, dynamic>?> obtenerInformacionCompletaUsuario()

// Extrae campos específicos: telefono, correo, rutaAsignada, supervisor
Future<Map<String, String>> obtenerCamposEspecificos()
```

### 2. **UserInfoService.dart**
Se actualizaron los métodos existentes:

```dart
// Prioriza el endpoint completo en la sincronización
Future<bool> syncWithAPI()

// Integran el nuevo endpoint cuando hay conexión
Future<String> obtenerCorreo()
Future<String> obtenerTelefono()

// Nuevos métodos específicos
Future<String> obtenerRutaAsignada()
Future<String> obtenerSupervisorResponsable()

// Sincronización silenciosa para segundo plano
Future<bool> silentSync()
```

### 3. **UserInfoScreen.Dart**
Se mejoró la pantalla con:

- ✅ **Mejor logging y debug**
- ✅ **Auto-sincronización al conectarse**
- ✅ **Botón de debug temporal** (ícono de bug naranja)
- ✅ **Manejo robusto de estados de carga**
- ✅ **Método `_forceSync()` para sincronización manual**

## 🔧 Cómo Usar

### **Pantalla de Usuario**
1. **Botón Debug** (🐛): Muestra todos los campos disponibles y permite forzar sincronización
2. **Botón Refresh** (🔄): Actualiza la información usando el nuevo endpoint
3. **Auto-sync**: Se sincroniza automáticamente al detectar conexión

### **Programáticamente**
```dart
// Obtener información completa
final perfilService = PerfilUsuarioService();
final info = await perfilService.obtenerInformacionCompletaUsuario();

// Obtener campos específicos
final campos = await perfilService.obtenerCamposEspecificos();
print('Teléfono: ${campos['telefono']}');
print('Correo: ${campos['correo']}');
print('Ruta: ${campos['rutaAsignada']}');
print('Supervisor: ${campos['supervisor']}');

// Usar UserInfoService
final userService = UserInfoService();
await userService.initialize();
final correo = await userService.obtenerCorreo();
final telefono = await userService.obtenerTelefono();
```

## 📊 Campos Obtenidos del Endpoint

Desde la respuesta del endpoint `/Usuarios/IniciarSesion`:

```json
{
  "telefono": "89626691",
  "correo": "fernandoscar04@gmail.com",
  "rutaAsignada": "Sucursal Rio De Piedra", // Mapeado desde 'sucursal'
  "supervisor": "Alex Jose",
  "cantidadInventario": "11",
  "rutasDelDiaJson": "[{...}]",
  "permisosJson": "[{...}]",
  "nombres": "Brayan",
  "apellidos": "Reyes xd",
  "dni": "0501200401160",
  "codigo": "VEND-00008",
  "cargo": "Vendedor"
}
```

## 🔄 Flujo de Funcionamiento

### **Offline-First**
1. **Prioridad 1**: Datos desde `FlutterSecureStorage`
2. **Prioridad 2**: Endpoint `/Usuarios/IniciarSesion` (si hay conexión)
3. **Prioridad 3**: Métodos tradicionales (fallback)
4. **Prioridad 4**: Datos por defecto

### **Estados de la UI**
- **Cargando...**: Mientras se inicializa o sincroniza
- **Actualizando...**: Cuando hay conexión pero falta información
- **Sin información**: Cuando no hay datos disponibles
- **Valor real**: Cuando se obtiene información exitosamente

## 🐛 Debug y Troubleshooting

### **Usar el Botón Debug**
1. Abrir pantalla de información de usuario
2. Presionar el ícono de bug naranja (🐛)
3. Ver todos los campos disponibles
4. Usar "Forzar Sync" si es necesario

### **Logs en Consola**
```
=== INICIALIZANDO UserInfoScreen ===
UserInfoScreen: Datos recibidos - X campos
UserInfoScreen: Cambio de conectividad - Online/Offline
UserInfoScreen: Campo nombreCompleto = Brayan Reyes xd
=== INICIANDO SINCRONIZACIÓN CON API ===
Obteniendo información completa desde endpoint /Usuarios/IniciarSesion...
✓ Información completa obtenida desde endpoint
```

### **Problemas Comunes**

1. **"Sin información" en todos los campos**
   - Verificar conectividad
   - Usar botón debug para ver campos disponibles
   - Forzar sincronización

2. **"Actualizando..." permanente**
   - Verificar que el endpoint responda correctamente
   - Revisar logs de consola
   - Verificar credenciales de usuario

3. **Error en sincronización**
   - Verificar API key
   - Verificar estructura del body del request
   - Revisar logs de error en consola

## 📱 Testing

### **Archivo de Pruebas**
Usar `TestEndpointIniciarSesion.dart` para probar:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const TestEndpointIniciarSesion(),
  ),
);
```

### **Casos de Prueba**
1. ✅ Sin conexión → Debe mostrar datos locales
2. ✅ Con conexión → Debe sincronizar automáticamente
3. ✅ Endpoint falla → Debe usar fallback
4. ✅ Datos vacíos → Debe mostrar "Sin información"
5. ✅ Cambio de conectividad → Debe auto-sincronizar

## 🔮 Próximos Pasos

1. **Remover botón debug** una vez confirmado el funcionamiento
2. **Optimizar frecuencia de sincronización** según necesidades
3. **Agregar más campos** si el endpoint los proporciona
4. **Implementar caché inteligente** para reducir llamadas API

---

**Nota**: El botón debug (🐛) es temporal y debe ser removido en producción.
