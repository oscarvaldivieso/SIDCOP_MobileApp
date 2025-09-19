# Corrección de Extracción de Correo y Teléfono

## Problema Identificado

El correo electrónico y teléfono no se mostraban en la pantalla de información de usuario a pesar de que los datos estaban disponibles en el endpoint de inicio de sesión.

### Datos Disponibles en el Endpoint
```json
{
  "correo": "fernandoscar04@gmail.com",
  "telefono": "89626691"
}
```

## Causa del Problema

El `UserInfoService` tenía métodos duplicados de extracción (`_extraerCorreoDesdeUserData` y `_extraerTelefonoDesdeUserData`) que no funcionaban correctamente, cuando ya existían métodos funcionales en `InicioSesion_OfflineService`.

## Solución Implementada

### 1. Eliminación de Métodos Duplicados
- Eliminados `_extraerCorreoDesdeUserData()` y `_extraerTelefonoDesdeUserData()` del `UserInfoService`
- Estos métodos duplicaban lógica que ya existía en `InicioSesion_OfflineService`

### 2. Uso de Métodos Centralizados
- Convertidos los métodos `_extraerCorreo()` y `_extraerTelefono()` en `InicioSesion_OfflineService` a públicos
- Ahora se llaman `extraerCorreo()` y `extraerTelefono()`

### 3. Actualización de Referencias
- `UserInfoService` ahora usa directamente los métodos del `InicioSesion_OfflineService`
- Eliminada duplicación de código y lógica

## Archivos Modificados

### 1. `UserInfoService.dart`
```dart
// ANTES (métodos duplicados)
_cachedUserData!['correo'] = await _extraerCorreoDesdeUserData(userData);
_cachedUserData!['telefono'] = await _extraerTelefonoDesdeUserData(userData);

// DESPUÉS (usando métodos centralizados)
_cachedUserData!['correo'] = InicioSesionOfflineService.extraerCorreo(userData);
_cachedUserData!['telefono'] = InicioSesionOfflineService.extraerTelefono(userData);
```

### 2. `InicioSesion_OfflineService.dart`
```dart
// ANTES (métodos privados)
static String _extraerCorreo(Map<String, dynamic>? userData)
static String _extraerTelefono(Map<String, dynamic>? userData)

// DESPUÉS (métodos públicos)
static String extraerCorreo(Map<String, dynamic>? userData)
static String extraerTelefono(Map<String, dynamic>? userData)
```

## Lógica de Extracción

Los métodos siguen esta prioridad:

### Para Correo:
1. `userData['correo']` ← **AQUÍ ESTÁN LOS DATOS**
2. `userData['correoElectronico']`
3. `userData['email']`
4. `userData['usua_Correo']`
5. `userData['usuario_Correo']`
6. Fallback a `datosVendedor['vend_Correo']`
7. Fallback a `datosVendedor['correo']`

### Para Teléfono:
1. `userData['telefono']` ← **AQUÍ ESTÁN LOS DATOS**
2. `userData['phone']`
3. `userData['celular']`
4. `userData['usua_Telefono']`
5. `userData['usuario_Telefono']`
6. Fallback a `datosVendedor['vend_Telefono']`
7. Fallback a `datosVendedor['telefono']`

## Validación

Se creó un script de prueba (`TestUserDataExtraction.dart`) que valida:
- ✅ Extracción correcta de correo: "fernandoscar04@gmail.com"
- ✅ Extracción correcta de teléfono: "89626691"
- ✅ Manejo de datos nulos
- ✅ Manejo de datos vacíos

## Resultado Esperado

Ahora la pantalla de información de usuario debería mostrar:
- **Correo electrónico:** fernandoscar04@gmail.com
- **Teléfono:** 89626691

En lugar de:
- **Correo electrónico:** No disponible
- **Teléfono:** No disponible

## Archivos Creados

1. `lib/debug/TestUserDataExtraction.dart` - Script de prueba para validar la extracción
2. `CORRECCION_CORREO_TELEFONO.md` - Esta documentación

## Notas Importantes

- Los métodos ahora son síncronos (no `async`) ya que no requieren operaciones asíncronas
- Se mantiene la compatibilidad con el sistema offline-first existente
- La lógica de fallback sigue funcionando para casos edge
- Los datos se extraen directamente del JSON de respuesta del endpoint de login
