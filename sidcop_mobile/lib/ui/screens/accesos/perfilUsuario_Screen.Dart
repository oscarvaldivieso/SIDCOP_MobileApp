import 'package:flutter/material.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  bool isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF19213B),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Configuración',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Color(0xFF19213B),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Icon(Icons.settings, color: Colors.white, size: 48),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cuenta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wifi, color: Color(0xFF1CBF63)),
                              SizedBox(width: 8),
                              Text(
                                'Online',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Switch(
                            value: isOnline,
                            activeColor: Color(0xFF1CBF63),
                            onChanged: (val) {
                              setState(() => isOnline = val);
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Acerca de
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Acerca de',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.help_outline, color: Colors.black54),
                        title: Text('Ayuda y soporte'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      ListTile(
                        leading: Icon(Icons.info_outline, color: Colors.black54),
                        title: Text('Términos y condiciones'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      SizedBox(height: 12),
                      // Almacenamiento y sincronización
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Almacenamiento y sincronización',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.black54),
                        title: Text('Limpiar caché'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
