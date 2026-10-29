import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

class FR11ProfilScreen extends StatefulWidget {
  const FR11ProfilScreen({Key? key}) : super(key: key);

  @override
  State<FR11ProfilScreen> createState() => _FR11ProfilScreenState();
}

class _FR11ProfilScreenState extends State<FR11ProfilScreen> {
  // Form & Controller untuk Ubah Password (Khusus Role Sales)
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSavingPassword = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // UPLOAD FILE GAMBAR PROFIL (DARI KAMERA / GALERI)
  // ============================================================
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null || !mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final bytes = await pickedFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final ok = await authProvider.updateProfilePhoto(base64Image);
      if (!mounted) return;

      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Foto profil berhasil diperbarui dari file!')),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Gagal memperbarui foto profil.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih file gambar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // LOGIKA UBAH PASSWORD (KHUSUS SALES)
  // ============================================================
  Future<void> _handleUpdatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isSavingPassword = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.updatePassword(
      _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isSavingPassword = false);

    if (success) {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Password akun Sales berhasil diperbarui!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  authProvider.errorMessage ?? 'Gagal mengubah password.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // POP-UP DIALOG UBAH FOTO PROFIL (KAMERA, FOTO, BATAL)
  // ============================================================
  void _showChangePhotoModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          title: const Row(
            children: [
              Icon(Icons.camera_alt_rounded, color: kPrimaryColor, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ambil Foto Menggunakan :',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              // Pilihan 1: Kamera
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadImage(ImageSource.camera);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: kPrimaryColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Kamera',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextColor,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Pilihan 2: Foto (Galeri)
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadImage(ImageSource.gallery);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.photo_library_outlined, color: kPrimaryColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Foto',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextColor,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kSecondaryColor,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // TAUTKAN & PUTUSKAN AKUN GOOGLE (GMAIL)
  // ============================================================
  Future<void> _performNativeGoogleLink(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb
            ? '548808151397-2119mf63filiaftlt7tvpqlvd5klvqia.apps.googleusercontent.com'
            : null,
        scopes: ['email', 'profile'],
      );

      final gUser = await googleSignIn.signIn();
      if (gUser == null) {
        return;
      }

      final ok = await authProvider.linkGoogleAccount(
        googleEmail: gUser.email,
        googleId: gUser.id,
        photoUrl: gUser.photoUrl,
      );

      if (!mounted) return;
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Akun Google (${gUser.email}) berhasil ditautkan ke akun Anda!'),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Gagal menautkan akun Google.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal memilih akun Google: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showManualLinkDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final emailController = TextEditingController(
      text: user.googleEmail?.isNotEmpty == true
          ? user.googleEmail
          : (user.email.endsWith('@gmail.com') ? user.email : ''),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            SvgPicture.asset('assets/icons/google-icon.svg', width: 22, height: 22),
            const SizedBox(width: 10),
            Text(
              user.isSales ? 'Tautkan Akun Google Sales' : 'Tautkan Akun Google',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.isSales
                  ? 'Sebagai Sales Lapangan, tautkan akun Gmail agar dapat masuk dengan satu ketukan tanpa mengetik password setiap waktu.'
                  : 'Masukkan email Google (Gmail) yang ingin Anda tautkan dengan akun CV Maju Bersama:',
              style: const TextStyle(fontSize: 13, color: kTextColor, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Akun Google (Gmail)',
                hintText: 'nama.sales@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              onPressed: () async {
                try {
                  final googleSignIn = GoogleSignIn(
                    clientId: kIsWeb
                        ? '548808151397-2119mf63filiaftlt7tvpqlvd5klvqia.apps.googleusercontent.com'
                        : null,
                    scopes: ['email', 'profile'],
                  );
                  final gUser = await googleSignIn.signIn();
                  if (gUser != null) {
                    emailController.text = gUser.email;
                  }
                } catch (e) {
                  debugPrint('Google Sign In Picker Error: $e');
                }
              },
              icon: SvgPicture.asset('assets/icons/google-icon.svg', width: 16, height: 16),
              label: const Text(
                'Pilih Akun Google Asli (Dialog Google)',
                style: TextStyle(fontSize: 12, color: kTextColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                emailController.text = user.email;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 14, color: kPrimaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Gunakan email saat ini (${user.email})',
                      style: const TextStyle(fontSize: 11.5, color: kPrimaryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: kSecondaryColor)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.link, size: 18, color: Colors.white),
            label: const Text('Tautkan Akun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Silakan masukkan alamat email Gmail yang ingin ditautkan.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              final ok = await authProvider.linkGoogleAccount(googleEmail: email);
              if (!mounted) return;
              if (ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Akun Google ($email) berhasil ditautkan ke akun Anda!'),
                    backgroundColor: const Color(0xFF047857),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(authProvider.errorMessage ?? 'Gagal menautkan akun Google.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleUnlinkGoogle(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Putuskan Tautan Google', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextColor)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin memutuskan tautan akun Google? Anda tetap dapat masuk menggunakan email dan password biasa.',
          style: TextStyle(fontSize: 13, color: kTextColor, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: kSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await authProvider.unlinkGoogleAccount();
              if (!mounted) return;
              if (ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Tautan Akun Google telah diputuskan.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(authProvider.errorMessage ?? 'Gagal memutuskan tautan akun Google.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Putuskan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KONFIRMASI LOGOUT
  // ============================================================
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi akun ini?',
          style: TextStyle(fontSize: 14, color: kTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: kSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final displayName = (user != null && user.name.isNotEmpty)
        ? user.name
        : 'Pengguna CV Maju Bersama';
    final displayEmail = user?.email ?? 'user@majubersama.com';
    final displayPhone = user?.phone ?? '+62 812-3456-7890';
    final photoUrl = user?.photoUrl;
    final isSalesRole = user?.isSales ?? true;
    final isOwnerRole = user?.isSuperAdmin ?? false;
    final isAdminRole = user?.isAdmin ?? false;

    // Styling & Aksen Dinamis Berdasarkan Role Resmi Akun
    Color roleColor;
    Color roleBgColor;
    IconData roleIcon;
    String roleLabel;

    if (isOwnerRole) {
      roleColor = const Color(0xFF6B21A8); // Deep Royal Purple
      roleBgColor = const Color(0xFFF3E8FF);
      roleIcon = Icons.military_tech_rounded;
      roleLabel = 'Owner / Superadmin';
    } else if (isAdminRole) {
      roleColor = const Color(0xFF1D4ED8); // Classic Sapphire Blue
      roleBgColor = const Color(0xFFEFF6FF);
      roleIcon = Icons.admin_panel_settings_rounded;
      roleLabel = 'Administrator';
    } else {
      // Sales Lapangan
      roleColor = const Color(0xFF047857); // Deep Emerald Teal
      roleBgColor = const Color(0xFFECFDF5);
      roleIcon = Icons.badge_rounded;
      roleLabel = 'Sales Lapangan';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profil Akun',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // HERO IDENTITY CARD (BESPOKE EXECUTIVE PROFILE HEADER)
            // ============================================================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Banner Header dengan Nuansa Deep Navy Corporate
                  Container(
                    width: double.infinity,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          roleColor,
                          roleColor.withValues(alpha: 0.82),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Sesi Aktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Avatar & Identitas
                  Transform.translate(
                    offset: const Offset(0, -42),
                    child: Column(
                      children: [
                        // Lingkaran Avatar Interaktif dengan Badge Kamera
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap: () => _showChangePhotoModal(context),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: UserAvatar(
                                  photoUrl: photoUrl,
                                  name: displayName,
                                  radius: 46,
                                  backgroundColor: roleBgColor,
                                  textColor: roleColor,
                                  fontSize: 32,
                                ),
                              ),
                            ),
                            // Tombol Kamera Upload
                            GestureDetector(
                              onTap: () => _showChangePhotoModal(context),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Nama Pengguna
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Badge Role Resmi Akun
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: roleBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(roleIcon, size: 14, color: roleColor),
                              const SizedBox(width: 6),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ============================================================
            // SEKSI 1: INFORMASI DATA PRIBADI
            // ============================================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'INFORMASI PRIBADI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.email_outlined, color: kPrimaryColor, size: 20),
                    ),
                    title: const Text('Email Akun', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    subtitle: Text(
                      displayEmail,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone_outlined, color: kPrimaryColor, size: 20),
                    ),
                    title: const Text('Nomor Handphone', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    subtitle: Text(
                      displayPhone,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_outlined, color: Color(0xFF047857), size: 20),
                    ),
                    title: const Text('Status Keaktifan Akun', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    subtitle: const Text(
                      'Aktif & Terverifikasi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ============================================================
            // SEKSI 2: INTEGRASI AKUN GOOGLE (GMAIL)
            // ============================================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'KEAMANAN & INTEGRASI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: user?.googleId != null
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/google-icon.svg',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isSalesRole ? 'Tautan Akun Google Sales' : 'Akun Google (Gmail)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: user?.googleId != null ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: user?.googleId != null ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              user?.googleId != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 12,
                              color: user?.googleId != null ? const Color(0xFF047857) : const Color(0xFFB45309),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user?.googleId != null ? 'Terhubung' : 'Belum Terhubung',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: user?.googleId != null ? const Color(0xFF047857) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.googleId != null
                        ? 'Akun Google aktif (${user?.displayGoogleEmail}). Anda dapat langsung login cepat 1-klik dengan Google tanpa mengetik password.'
                        : 'Tautkan akun Google agar dapat langsung masuk ke aplikasi secara instan dan aman saat bertugas di lapangan.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (user?.googleId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          foregroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _handleUnlinkGoogle(context),
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        label: const Text(
                          'Putuskan Tautan Akun Google',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _performNativeGoogleLink(context),
                        icon: SvgPicture.asset('assets/icons/google-icon.svg', width: 18, height: 18),
                        label: const Text(
                          'Tautkan dengan Akun Google',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _showManualLinkDialog(context),
                        child: const Text(
                          'Atau tautkan manual dengan memasukkan email',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ============================================================
            // SEKSI 4: FORM UBAH PASSWORD (KHUSUS ROLE SALES)
            // ============================================================
            if (isSalesRole) ...[
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'KREDENSIAL AKUN SALES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_reset_rounded, color: kPrimaryColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Ubah Password Sales',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pastikan password menggunakan minimal 6 karakter kombinasi yang aman.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),

                      // Input Password Baru
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          hintText: 'Minimal 6 karakter',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: kPrimaryColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password baru wajib diisi';
                          }
                          if (value.length < 6) {
                            return 'Password baru minimal 6 karakter';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Input Konfirmasi Password Baru
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password Baru',
                          hintText: 'Ulangi password baru Anda',
                          prefixIcon: const Icon(Icons.lock_clock_outlined, color: kPrimaryColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Konfirmasi password tidak cocok';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Tombol Simpan Password Baru
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: _isSavingPassword ? null : _handleUpdatePassword,
                          icon: _isSavingPassword
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          label: Text(
                            _isSavingPassword ? 'Menyimpan...' : 'Perbarui Password Sales',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ============================================================
            // TOMBOL KELUAR / LOGOUT
            // ============================================================
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Keluar dari Aplikasi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
