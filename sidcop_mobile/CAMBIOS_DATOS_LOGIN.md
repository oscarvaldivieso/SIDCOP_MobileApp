# Cambios - Datos desde Login

## 🎯 Cambio Implementado

**Problema**: Los datos de supervisor responsable y ruta asignada se estaban obteniendo desde `datosVendedor` en lugar de usar los datos que vienen directamente en la respuesta del login.

**Solución**: Actualicé los métodos de extracción para priorizar los datos que vienen directamente en la respuesta del login.

## 📁 Archivos Modificados

### 1. `InicioSesion_OfflineService.dart`

#### Método `_extraerRutaAsignada()` - Actualizado
```dart
// NUEVA PRIORIDAD:
// 1. Datos directos del login: ruta, rutaAsignada, ruta_Codigo, ruta_Descripcion
// 2. rutasDelDiaJson (si viene en el login)
// 3. datosVendedor.vend_Codigo (fallback)
// 4. codigo del usuario (fallback)
```

#### Método `_extraerSupervisorResponsable()` - Actualizado
```dart
// NUEVA PRIORIDAD:
// 1. Datos directos del login: supervisor, supervisorResponsable, supervisor_Nombre, nombreSupervisor
// 2. Campos combinados: supervisor_Nombres + supervisor_Apellidos
// 3. datosVendedor (fallback)
```

#### Método `obtenerInformacionOperativa()` - Simplificado
```dart
// Ahora usa directamente los métodos de extracción:
infoOperativa['rutaAsignada'] = _extraerRutaAsignada(userData);
infoOperativa['supervisorResponsable'] = _extraerSupervisorResponsable(userData);
```

### 2. `LoginDataDebugScreen.dart` (Nuevo)
- Pantalla de debug para ver exactamente qué campos vienen en la respuesta del login
- Muestra todos los campos disponibles
- Verifica campos específicos de ruta y supervisor
- Prueba los métodos de extracción en tiempo real

## 🔍 Campos que Busca Ahora

### Para Ruta Asignada:
**Prioridad 1 - Datos directos del login:**
- `ruta`
- `rutaAsignada`
- `ruta_Codigo`
- `ruta_Descripcion`

**Prioridad 2 - JSON del login:**
- `rutasDelDiaJson` (requiere parsing)

**Prioridad 3 - Fallback:**
- `datosVendedor.vend_Codigo`
- `codigo`

### Para Supervisor Responsable:
**Prioridad 1 - Datos directos del login:**
- `supervisor`
- `supervisorResponsable`
- `supervisor_Nombre`
- `nombreSupervisor`

**Prioridad 2 - Campos combinados del login:**
- `supervisor_Nombres` + `supervisor_Apellidos`

**Prioridad 3 - Fallback:**
- `datosVendedor.nombreSupervisor` + `datosVendedor.apellidoSupervisor`

## 🚀 Cómo Verificar

### 1. Usar la Pantalla de Debug
```dart
// Navegar a la pantalla de debug
Navigator.push(context, MaterialPageRoute(
  builder: (context) => LoginDataDebugScreen(),
));
```

### 2. Revisar el Log
La pantalla de debug mostrará:
- ✓ Campos que SÍ vienen en el login
- ✗ Campos que NO vienen en el login
- Resultado final de la extracción

### 3. Ejemplo de Log Esperado:
```
=== VERIFICANDO CAMPOS ESPECÍFICOS ===

CAMPOS DE RUTA:
  ✓ ruta: "Ruta Centro"
  ✗ rutaAsignada: null
  ✓ ruta_Codigo: "R001"
  ✗ ruta_Descripcion: null

CAMPOS DE SUPERVISOR:
  ✓ supervisor: "Mario Galeas"
  ✗ supervisorResponsable: null
  ✗ supervisor_Nombre: null

=== RESULTADOS DE EXTRACCIÓN ===
Ruta extraída: Ruta Centro
Supervisor extraído: Mario Galeas
```

## ✅ Resultado

Ahora el sistema:
- ✅ **Prioriza datos del login** sobre `datosVendedor`
- ✅ **Busca en múltiples campos** posibles del login
- ✅ **Mantiene fallback** a `datosVendedor` si no viene en login
- ✅ **Funciona offline** usando datos cacheados del login
- ✅ **Incluye debug tools** para verificar qué campos están disponibles

## 📋 Próximos Pasos

1. **Ejecutar la app** y hacer login
2. **Navegar a `LoginDataDebugScreen`** para ver qué campos específicos vienen en tu respuesta de login
3. **Ajustar los nombres de campos** si es necesario según lo que muestre el debug
4. **Verificar** que la información se muestre correctamente en `UserInfoScreen`

Los datos ahora se obtienen directamente desde la respuesta del login con la prioridad correcta, manteniendo `datosVendedor` solo como fallback.
