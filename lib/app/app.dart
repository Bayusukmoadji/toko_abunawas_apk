import 'package:flutter/material.dart';

import '../features/auth/login_page.dart';

class StokAbunawasApp extends StatelessWidget {
  const StokAbunawasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stok Abunawas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF038E1B),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
