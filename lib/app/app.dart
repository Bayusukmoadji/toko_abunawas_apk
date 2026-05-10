import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';

class StokAbunawasApp extends StatelessWidget {
  const StokAbunawasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stok Abunawas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryGreen),
        scaffoldBackgroundColor: AppTheme.background,
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
