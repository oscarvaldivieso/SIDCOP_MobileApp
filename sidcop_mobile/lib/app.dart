import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiUrl = dotenv.env['API_URL'] ?? 'api no definida';
    final apiKey = dotenv.env['API_KEY'] ?? 'api key no definida';

    return MaterialApp(
      title: 'SIDCOP Mobile App',
      theme: ThemeData(
        primarySwatch:Colors.indigo,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SIDCOP Mobile App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('API URL: $apiUrl'),
              Text('API Key: $apiKey'),
            ],
          ),
        ),
      ),
    );


  }
}