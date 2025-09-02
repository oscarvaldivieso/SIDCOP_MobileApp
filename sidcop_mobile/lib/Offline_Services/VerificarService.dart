Future<void> verificarConexion() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      if (response.statusCode == 200) {
        isOnline = true;
      } else {
        isOnline = false;
      }
    } catch (e) {
      isOnline = false;
    }
  }