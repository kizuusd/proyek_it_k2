import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

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

  // Preset Avatar untuk ganti foto profil setiap role
  final List<Map<String, String>> _avatarPresets = [
    {
      'name': 'Owner / Direktur',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Administrator',
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Sales Lapangan 1',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Sales Lapangan 2',
      'url': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Sales Lapangan 3',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Eksekutif',
      'url': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&fit=crop&crop=faces',
    },
    {
      'name': 'Foto Bawaan Brand',
      'url': 'assets/images/Profile Image.png',
    },
  ];

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Password akun Sales berhasil diperbarui!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
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
  // LOGIKA UBAH FOTO PROFIL (UNTUK SETIAP ROLE)
  // ============================================================
  void _showChangePhotoModal(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.add_a_photo, color: kPrimaryColor),
                    SizedBox(width: 10),
                    Text(
                      'Ubah Foto Profil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fitur ini dapat digunakan oleh setiap role (Admin, Owner, dan Sales).',
                  style: TextStyle(fontSize: 13, color: kSecondaryColor),
                ),
                const SizedBox(height: 20),

                // Pilihan Preset Avatar
                const Text(
                  'Pilih dari Koleksi Avatar Preset:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatarPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _avatarPresets[index];
                      final isAsset = item['url']!.startsWith('assets/');
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final ok = await authProvider.updateProfilePhoto(item['url']!);
                          if (ok && mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Foto profil berhasil diubah ke ${item['name']}!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: kPrimaryLightColor,
                              backgroundImage: isAsset
                                  ? AssetImage(item['url']!) as ImageProvider
                                  : NetworkImage(item['url']!),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['name']!.split(' ')[0],
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // Input URL Foto Kustom
                const Text(
                  'Atau Masukkan URL Gambar Kustom:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/foto.jpg',
                    prefixIcon: const Icon(Icons.link, color: kPrimaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final url = urlController.text.trim();
                      if (url.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Silakan masukkan URL gambar terlebih dahulu.')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final ok = await authProvider.updateProfilePhoto(url);
                      if (ok && mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Foto profil berhasil diperbarui via URL!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('Terapkan Foto URL', style: TextStyle(color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 10),
                // Opsi Hapus Foto / Gunakan Inisial
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await authProvider.updateProfilePhoto('');
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Foto profil dihapus, kembali ke inisial nama.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus Foto (Gunakan Inisial Huruf)'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // EDIT DATA DIRI (NAMA & NO HP)
  // ============================================================
  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: kPrimaryColor),
            SizedBox(width: 8),
            Text('Edit Data Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final ok = await authProvider.updateProfile(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              if (ok && mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Data profil berhasil diperbarui!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi akun ini?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: kSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Data Fallback jika user null
    final displayName = (user != null && user.name.isNotEmpty)
        ? user.name
        : 'Pengguna CV Maju Bersama';
    final displayEmail = user?.email ?? 'user@majubersama.com';
    final displayPhone = user?.phone ?? '+62 812-3456-7890';
    final photoUrl = user?.photoUrl;
    final isSalesRole = user?.isSales ?? true;
    final isOwnerRole = user?.isSuperAdmin ?? false;
    final isAdminRole = user?.isAdmin ?? false;

    // Styling Khusus Setiap Role
    Color roleColor;
    Color roleBgColor;
    IconData roleIcon;
    String roleLabel;
    String roleDescription;
    List<String> roleResponsibilities;

    if (isOwnerRole) {
      roleColor = const Color(0xFF6A1B9A);
      roleBgColor = const Color(0xFFF3E5F5);
      roleIcon = Icons.military_tech;
      roleLabel = 'Superadmin (Owner)';
      roleDescription = 'Pemilik Perusahaan CV Maju Bersama dengan otoritas penuh atas seluruh operasional bisnis.';
      roleResponsibilities = [
        'Akses monitoring laporan omset & pendapatan sales',
        'Monitoring live tracking posisi seluruh sales di lapangan',
        'Persetujuan kebijakan dan pengesahan pengajuan barang',
        'Pengawasan kinerja Administrator dan Staf Lapangan',
      ];
    } else if (isAdminRole) {
      roleColor = const Color(0xFF1565C0);
      roleBgColor = const Color(0xFFE3F2FD);
      roleIcon = Icons.admin_panel_settings;
      roleLabel = 'Administrator (Sekretaris)';
      roleDescription = 'Pengelola administrasi sistem, penjadwalan rute, verifikasi izin, dan master data barang.';
      roleResponsibilities = [
        'Manajemen Master Data Barang dan Master Harga resmi',
        'Penyusunan jadwal rute kunjungan sales lapangan',
        'Verifikasi absensi, formulir izin sakit/cuti',
        'Pengelolaan data anggota dan hak akses pengguna',
      ];
    } else {
      // Sales
      roleColor = const Color(0xFF00796B);
      roleBgColor = const Color(0xFFE0F2F1);
      roleIcon = Icons.badge;
      roleLabel = 'Sales Lapangan';
      roleDescription = 'Ujung tombak pemasaran produk di lapangan, menangani kunjungan outlet toko dan penjualan.';
      roleResponsibilities = [
        'Kunjungan rute toko sesuai jadwal harian dan mingguan',
        'Presensi / absensi lokasi GPS dan foto saat di toko mitra',
        'Input pengajuan barang baru dan pesanan pelanggan',
        'Pencapaian target penjualan dan monitoring komisi',
      ];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            tooltip: 'Edit Data Profil',
            icon: const Icon(Icons.edit_outlined, color: kPrimaryColor),
            onPressed: user != null ? () => _showEditProfileDialog(context, user) : null,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // ============================================================
            // BAR GANTI ROLE AKUN (DEMO & EVALUASI SETIAP ROLE)
            // ============================================================
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.switch_account, size: 18, color: kPrimaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Pilih Role Pengguna (Tampilkan Setiap Role):',
                        style: TextStyle(
                          fontSize: 13,
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
                      // Role Owner
                      ChoiceChip(
                        avatar: Icon(
                          Icons.military_tech,
                          size: 16,
                          color: isOwnerRole ? Colors.white : const Color(0xFF6A1B9A),
                        ),
                        label: const Text('Owner'),
                        selected: isOwnerRole,
                        selectedColor: const Color(0xFF6A1B9A),
                        labelStyle: TextStyle(
                          color: isOwnerRole ? Colors.white : kTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => authProvider.switchRoleDemo('owner'),
                      ),
                      // Role Admin
                      ChoiceChip(
                        avatar: Icon(
                          Icons.admin_panel_settings,
                          size: 16,
                          color: isAdminRole ? Colors.white : const Color(0xFF1565C0),
                        ),
                        label: const Text('Admin'),
                        selected: isAdminRole,
                        selectedColor: const Color(0xFF1565C0),
                        labelStyle: TextStyle(
                          color: isAdminRole ? Colors.white : kTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => authProvider.switchRoleDemo('admin'),
                      ),
                      // Role Sales
                      ChoiceChip(
                        avatar: Icon(
                          Icons.badge,
                          size: 16,
                          color: isSalesRole ? Colors.white : const Color(0xFF00796B),
                        ),
                        label: const Text('Sales'),
                        selected: isSalesRole,
                        selectedColor: const Color(0xFF00796B),
                        labelStyle: TextStyle(
                          color: isSalesRole ? Colors.white : kTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => authProvider.switchRoleDemo('sales'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ============================================================
            // KARTU UTAMA PROFIL & FOTO PROFIL (UNTUK SETIAP ROLE)
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar dengan Tombol Kamera Ubah Foto
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: roleColor.withOpacity(0.4), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: kPrimaryLightColor,
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                              ? (photoUrl.startsWith('assets/')
                                  ? AssetImage(photoUrl) as ImageProvider
                                  : NetworkImage(photoUrl))
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // Badge Kamera Interaktif
                      GestureDetector(
                        onTap: () => _showChangePhotoModal(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Tombol "Ubah Foto Profil" untuk setiap role
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    onPressed: () => _showChangePhotoModal(context),
                    icon: const Icon(Icons.photo_camera_back_outlined, size: 16),
                    label: const Text(
                      'Ubah Foto Profil',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Nama Pengguna
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Badge Role Dinamis
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: roleBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, size: 16, color: roleColor),
                        const SizedBox(width: 6),
                        Text(
                          roleLabel,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ============================================================
            // KARTU TANGGUNG JAWAB & AKSES ROLE (ADMIN / OWNER / SALES)
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: roleBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(roleIcon, color: roleColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Otoritas & Hak Akses $roleLabel',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: kTextColor,
                              ),
                            ),
                            Text(
                              roleDescription,
                              style: const TextStyle(fontSize: 11, color: kSecondaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  ...roleResponsibilities.map(
                    (resp) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: roleColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resp,
                              style: const TextStyle(fontSize: 12, color: kTextColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ============================================================
            // INFORMASI KONTAK & AKUN PRIBADI
            // ============================================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kPrimaryLightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.email_outlined, color: kPrimaryColor),
                    ),
                    title: const Text('Email Akun', style: TextStyle(fontSize: 12, color: kSecondaryColor)),
                    subtitle: Text(
                      displayEmail,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextColor),
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kPrimaryLightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_outlined, color: kPrimaryColor),
                    ),
                    title: const Text('Nomor Handphone', style: TextStyle(fontSize: 12, color: kSecondaryColor)),
                    subtitle: Text(
                      displayPhone,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextColor),
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_user_outlined, color: Colors.green),
                    ),
                    title: const Text('Status Keaktifan Akun', style: TextStyle(fontSize: 12, color: kSecondaryColor)),
                    subtitle: const Text(
                      'Aktif & Terverifikasi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ============================================================
            // KHUSUS ROLE SALES: FORM TEXT INPUT UBAH PASSWORD
            // ============================================================
            if (isSalesRole) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00796B).withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00796B).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lock_reset, color: Color(0xFF00796B), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Ubah Password Akun Sales',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Fitur khusus role Sales untuk mengamankan kredensial akun lapangan.',
                                  style: TextStyle(fontSize: 11, color: kSecondaryColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input Password Baru
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          hintText: 'Masukkan password baru',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00796B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                              color: kSecondaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          prefixIcon: const Icon(Icons.lock_clock_outlined, color: Color(0xFF00796B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: kSecondaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

                      const SizedBox(height: 16),

                      // Tombol Simpan Password Baru
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isSavingPassword ? null : _handleUpdatePassword,
                          icon: _isSavingPassword
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, color: Colors.white),
                          label: Text(
                            _isSavingPassword ? 'Menyimpan...' : 'Perbarui Password Sales',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ============================================================
            // TOMBOL KELUAR / LOGOUT
            // ============================================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Keluar dari Aplikasi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
