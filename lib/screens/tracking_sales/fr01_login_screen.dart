import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';

class FR01LoginScreen extends StatefulWidget {
  const FR01LoginScreen({Key? key}) : super(key: key);

  @override
  State<FR01LoginScreen> createState() => _FR01LoginScreenState();
}

class _FR01LoginScreenState extends State<FR01LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      _showErrorDialog(authProvider.errorMessage ?? 'Gagal masuk ke sistem.');
    }
  }

  void _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      _showErrorDialog(authProvider.errorMessage ?? 'Gagal masuk dengan akun Google.');
    }
  }

  void _fillMockCredentials(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Autentikasi Gagal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9), // Warna background abu-abu terang seragam dengan Dashboard
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              // Banner Header Branding (Sama persis dengan Banner di HomeDashboardScreen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: kPrimaryGradientColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon Circle Avatar khas brand
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.share_location, size: 36, color: kPrimaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CV Maju Bersama',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aplikasi Tracking Sales Mobile',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Sistem Informasi Sales & Distribusi',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Card Form Login (Konsisten dengan kartu putih di HomeDashboardScreen)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: kPrimaryLightColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.login, color: kPrimaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Masuk ke Sistem',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kTextColor,
                                ),
                              ),
                              Text(
                                'Silakan masukkan kredensial akun Anda',
                                style: TextStyle(fontSize: 12, color: kSecondaryColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Quick Demo / Testing Chips
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryLightColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.flash_on, size: 16, color: kPrimaryColor),
                                SizedBox(width: 6),
                                Text(
                                  'Akses Cepat Pengujian (Role Akun):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.shield, size: 14, color: Colors.purple),
                                  label: const Text('Owner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.white,
                                  onPressed: () => _fillMockCredentials(
                                    'owner@majubersama.com',
                                    'password123',
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.admin_panel_settings, size: 14, color: Colors.blue),
                                  label: const Text('Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.white,
                                  onPressed: () => _fillMockCredentials(
                                    'admin@majubersama.com',
                                    'password123',
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.badge, size: 14, color: Colors.teal),
                                  label: const Text('Sales', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.white,
                                  onPressed: () => _fillMockCredentials(
                                    'sales@majubersama.com',
                                    'password123',
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.block, size: 14, color: Colors.red),
                                  label: const Text('Nonaktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.white,
                                  onPressed: () => _fillMockCredentials(
                                    'inactive@majubersama.com',
                                    'password123',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'nama@majubersama.com',
                          prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryColor),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(val.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Masukkan password Anda',
                          prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: kSecondaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          if (val.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      // Tombol Masuk
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
