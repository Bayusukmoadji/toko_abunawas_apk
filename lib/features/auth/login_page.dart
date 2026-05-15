import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../data/models/app_user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIKA LOGIN DENGAN SNACKBAR ALERT ---
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email dan Password wajib diisi!'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user?.uid;
      if (uid == null) throw Exception('UID user tidak ditemukan.');

      final AppUserModel? appUser = await _userRepository.getUserByUid(uid);
      if (appUser == null) throw Exception('Data profil tidak ditemukan.');

      if (!appUser.isActive) {
        await _authService.signOut();
        throw Exception('Akun ini tidak aktif.');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage(user: appUser)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- WIDGET LOGO ---
  Widget _buildLogoSection() {
    return Column(
      children: [
        Transform.translate(
          offset: const Offset(0, 42),
          child: Image.asset(
            'assets/images/logo.png',
            width: 364,
            height: 199,
            fit: BoxFit.contain,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -15),
          child: const Text(
            'APLIKASI MANAJEMEN STOK\nBERBASIS MOBILE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET INPUT FIELD ---
  Widget _buildGlassInputField({
    required String label,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Center(
      child: SizedBox(
        width: 316,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 67,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.asset('assets/login/glasscard.png',
                        fit: BoxFit.fill),
                  ),
                  TextFormField(
                    controller: controller,
                    obscureText: isPassword ? _obscurePassword : false,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                      suffixIcon: isPassword
                          ? Padding(
                              padding: const EdgeInsets.only(
                                  right: 10.0, bottom: 4.0),
                              child: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(22, 18, 16, 26),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: validator,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF015816), Color(0xFF10B508), Color(0xFF06F43E)],
            stops: [0.0, 0.49, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildLogoSection(),
                    const SizedBox(height: 0),

                    _buildGlassInputField(
                      label: 'Email',
                      hintText: 'Masukan email',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      validator: (value) => value!.isEmpty ? "" : null,
                    ),
                    const SizedBox(height: 20),

                    _buildGlassInputField(
                      label: 'Password',
                      hintText: 'Masukan Password',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      isPassword: true,
                      validator: (value) => value!.isEmpty ? "" : null,
                    ),
                    const SizedBox(height: 40),

                    // --- TOMBOL LOGIN (ANIMASI MENYUSUT & RADIUS 10) ---
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 35,
                        // LEBAR DINAMIS: Mengecil jadi 45 saat loading, kembali 90 saat selesai
                        width: _isLoading ? 45 : 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/login/glasscard.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login_rounded,
                                              size: 14, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('Login',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 110),
                    const Text(
                      '© Toko Beras Abunawas',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
