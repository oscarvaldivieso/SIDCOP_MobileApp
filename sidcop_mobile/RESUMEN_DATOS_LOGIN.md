# 📋 Datos que Guarda el Inicio de Sesión

## 🔍 Flujo de Datos del Login

### 1. **API Response Structure**
```json
{
  "data": {
    // Todos los campos del usuario vienen aquí
    "code_Status": 1,
    "message_Status": "Login exitoso",
    "usua_Id": 123,
    "usua_IdPersona": 456,
    "personaId": 456,
    // ... más campos del usuario
  }
}
```

### 2. **Proceso de Caché**
```dart
// En UsuarioService.iniciarSesion()
return data; // Devuelve responseData['data']

// En login_screen.dart
InicioSesionOfflineService.cachearDatosInicioSesion(result);

// En InicioSesion_OfflineService
_cachearDatosUsuario(userData); // Guarda TODOS los campos menos contraseñas
```

## 📊 Datos Específicos que se Guardan

### **Datos del Usuario Principal** (`_userDataKey`)
El método `_cachearDatosUsuario()` guarda **TODOS** los campos que vienen en `responseData['data']` excepto:
- ❌ `usua_Clave` (contraseña)
- ❌ `password` (contraseña)

### **Campos Típicos que se Guardan:**
```dart
{
  // IDs y códigos
  "usua_Id": 123,
  "usua_IdPersona": 456,
  "personaId": 456,
  "code_Status": 1,
  "message_Status": "Login exitoso",
  
  // Datos personales
  "nombres": "Juan Carlos",
  "apellidos": "Pérez López", 
  "dni": "0801199012345",
  "correo": "juan.perez@empresa.com",
  "telefono": "+504 9876-5432",
  
  // Datos laborales
  "usua_TipoUsuario": "Vendedor",
  "role_Descripcion": "Vendedor",
  "cargo": "Vendedor Senior",
  
  // Datos de ruta y supervisor (si vienen en el login)
  "ruta": "Ruta Centro",
  "supervisor": "Mario Galeas",
  "rutaAsignada": "R001",
  "supervisorResponsable": "Mario Galeas",
  
  // Fechas
  "usua_FechaCreacion": "2023-01-15T00:00:00",
  "fechaIngreso": "2023-01-15",
  
  // Datos adicionales del vendedor
  "datosVendedor": {
    "vend_Id": 789,
    "vend_Codigo": "V001", 
    "vend_Correo": "vendedor@empresa.com",
    "vend_Telefono": "+504 1234-5678",
    "vend_FechaCreacion": "2023-01-15T00:00:00",
    "nombreSupervisor": "Mario",
    "apellidoSupervisor": "Galeas"
  },
  
  // JSON de rutas del día
  "rutasDelDiaJson": "[{\"Ruta_Codigo\":\"R001\",\"Ruta_Descripcion\":\"Centro\",\"Clientes\":[...]}]"
}
```

## 🗂️ Otros Datos que se Cachean

### **Clientes por Ruta** (`_clientesRutaKey`)
```dart
// Array de clientes asignados al vendedor
[
  {
    "clie_Id": 1,
    "clie_Nombre": "Cliente 1",
    "clie_RTN": "12345678901234",
    // ... más campos del cliente
  }
]
```

### **Productos Básicos** (`_productosBasicosKey`)
```dart
// Array de productos para pedidos offline
[
  {
    "prod_Id": 1,
    "prod_Descripcion": "Producto A",
    "prod_Precio": 100.00,
    // ... más campos del producto
  }
]
```

### **Pedidos con Detalles** (`_pedidosKey` + `_pedidosDetalleKey`)
```dart
// Pedidos del vendedor
[
  {
    "pedi_Id": 1,
    "pedi_FechaPedido": "2024-09-17T10:00:00",
    "pedi_Total": 1500.00,
    // ... más campos del pedido
  }
]

// Detalles de cada pedido
{
  "1": [ // pedi_Id como key
    {
      "pede_Id": 1,
      "pede_ProductoId": 123,
      "pede_Cantidad": 5,
      // ... más campos del detalle
    }
  ]
}
```

### **Diccionario de Usuario** (`_userInfoDictionaryKey`)
```dart
// Diccionario consolidado generado por generarYGuardarDiccionarioUsuario()
{
  // Datos personales extraídos y procesados
  "nombreCompleto": "Juan Carlos Pérez López",
  "numeroIdentidad": "0801199012345", 
  "numeroEmpleado": "123",
  "correo": "juan.perez@empresa.com",
  "telefono": "+504 9876-5432",
  "cargo": "Vendedor Senior",
  
  // Datos laborales procesados
  "rutaAsignada": "Ruta Centro",
  "supervisorResponsable": "Mario Galeas",
  
  // Información operativa calculada
  "inventarioAsignado": "52", // productos.length
  "clientesAsignados": "15", // clientesRuta.length  
  "metaVentasDiaria": "L.7,500.00",
  "ventasDelDia": "L.5,200.00",
  "ultimaRecargaSolicitada": "15 sep 2024 - 14:30",
  
  // Metadatos
  "fechaGeneracion": "2024-09-17T10:19:12.000Z",
  "totalProductos": 52,
  "totalPedidos": 8
}
```

## 🔧 Métodos de Acceso

### **Para Obtener Datos Originales del Login:**
```dart
final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
// Devuelve TODOS los campos originales del login (menos contraseñas)
```

### **Para Obtener Datos Procesados:**
```dart
final diccionario = await InicioSesionOfflineService.obtenerDiccionarioUsuario();
// Devuelve datos procesados y organizados para mostrar en UI
```

### **Para Obtener Info Operativa:**
```dart
final infoOperativa = await InicioSesionOfflineService.obtenerInformacionOperativa();
// Devuelve datos calculados: inventario, clientes, última recarga, etc.
```

## 🚀 Para Ver los Datos Exactos

### **Usar LoginDataDebugScreen:**
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (context) => LoginDataDebugScreen(),
));
```

### **O agregar debug en el login:**
```dart
// En _cachearDatosUsuario después de la línea 88
print('=== DATOS COMPLETOS DEL LOGIN ===');
datosLimpios.forEach((key, value) {
  print('$key: $value');
});
print('=== FIN DATOS LOGIN ===');
```

## ✅ Resumen

**El inicio de sesión guarda:**
1. ✅ **TODOS los campos** que vienen en `responseData['data']` de la API
2. ✅ **Datos filtrados** (sin contraseñas) en `FlutterSecureStorage`
3. ✅ **Clientes, productos y pedidos** asociados al usuario
4. ✅ **Diccionario procesado** para fácil acceso en la UI

**Los datos específicos de ruta y supervisor** pueden venir:
- 🎯 **Directamente en el login** (campos como `ruta`, `supervisor`, etc.)
- 🎯 **En `datosVendedor`** (subcampo del login)
- 🎯 **En `rutasDelDiaJson`** (JSON con rutas del día)

Para ver exactamente qué campos tienes disponibles, usa la pantalla de debug que creé.
