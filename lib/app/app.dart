import 'package:flutter/material.dart';
import '../features/auth/login_page.dart';

class StokAbunawasApp extends StatelessWidget {
  const StokAbunawasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stok Abunawas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
