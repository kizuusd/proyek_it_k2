import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_service.dart';
import '../../widgets/user_avatar.dart';
import 'home_dashboard_screen.dart';

class FR03MasterHargaScreen extends StatefulWidget {
  const FR03MasterHargaScreen({Key? key}) : super(key: key);

  @override
  State<FR03MasterHargaScreen> createState() => _FR03MasterHargaScreenState();
}

class _FR03MasterHargaScreenState extends State<FR03MasterHargaScreen> {
  List<ProductItem> _products = InventoryService.defaultProducts();
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'Semua';
  String _selectedSort = 'Default';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final cached = await InventoryService.loadCachedProducts();
    if (mounted) {
      setState(() {
        _products = cached;
      });
    }

    if (InventoryService.isTestEnv) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fetched = await InventoryService.fetchProducts();
      if (mounted) {
        setState(() {
          _products = fetched;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
      );
    }
  }

  String _profileLabelForRole(UserModel? user) {
    if (user?.isSuperAdmin == true) return 'Profil Owner';
    if (user?.isAdmin == true) return 'Profil Admin';
    return 'Profil Sales';
  }

  Color _rolePrimaryColor(UserModel? user) {
    if (user?.isSuperAdmin == true) return const Color(0xFF6B21A8);
    if (user?.isAdmin == true) return const Color(0xFF1D4ED8);
    return const Color(0xFF047857);
  }

  Color _roleLightColor(UserModel? user) {
    if (user?.isSuperAdmin == true) return const Color(0xFFF3E8FF);
    if (user?.isAdmin == true) return const Color(0xFFEFF6FF);
    return const Color(0xFFECFDF5);
  }

  LinearGradient _roleGradient(UserModel? user) {
    if (user?.isSuperAdmin == true) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
      );
    }
    if (user?.isAdmin == true) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF047857), Color(0xFF065F46)],
    );
  }

  void _showSalesProfilePopup(UserModel? user, bool isManager) {
    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'Pengguna Aktif';
    final userEmail = (user?.email.isNotEmpty == true) ? user!.email : '-';
    final userPhone = (user?.phone?.isNotEmpty == true) ? user!.phone! : '-';
    final roleTitle = user?.roleDisplayTitle ?? 'Sales Lapangan';
    final profileLabel = _profileLabelForRole(user);
    final roleColor = _rolePrimaryColor(user);
    final roleBgColor = _roleLightColor(user);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        title: Row(
          children: [
            Icon(Icons.badge_outlined, color: roleColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                profileLabel,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: roleColor, width: 2),
              ),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: userName,
                radius: 38,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              userName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextColor),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: roleBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                roleTitle,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileInfoTile(Icons.email_outlined, 'Email', userEmail),
            const SizedBox(height: 8),
            _buildProfileInfoTile(Icons.phone_outlined, 'No. Telepon', userPhone),
            const SizedBox(height: 8),
            _buildProfileInfoTile(
              Icons.verified_user_outlined,
              'Hak Akses',
              isManager ? 'Kelola & Ubah Harga Jual Resmi' : 'Lihat Daftar Harga Resmi (Read-Only)',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _tampilkanDialogUbahHarga(ProductItem item, bool isManager) {
    if (!isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya Admin dan Owner yang berwenang mengubah harga jual barang.'),
          backgroundColor: kDangerColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final roleColor = _rolePrimaryColor(currentUser);
    final formKey = GlobalKey<FormState>();
    final hargaController = TextEditingController(text: item.harga.toString());
    final catatanController = TextEditingController();
    DateTime startedAt = DateTime.now();
    DateTime? endedAt;

    showDialog(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void applyPercentage(double percent) {
              final base = item.harga;
              final calculated = (base * (1.0 + (percent / 100.0))).round();
              // Bulatkan ke kelipatan 500 terdekat
              final rounded = (calculated / 500).round() * 500;
              setDialogState(() {
                hargaController.text = (rounded < 500 ? 500 : rounded).toString();
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.price_change_rounded, color: roleColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ubah Harga Barang',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextColor),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSaving ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 10),

                        // Kartu Rangkuman Produk
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              ProductThumbnailWidget(
                                fotoUrl: item.fotoUrl,
                                namaBarang: item.namaBarang,
                                kategori: item.kategori,
                                size: 50,
                                borderRadius: 10,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.kodeBarang,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.namaBarang,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: kTextColor,
                                      ),
                                    ),
                                    Text(
                                      '${item.kategori} · Stok Gudang: ${item.stokGudang} ${item.satuan}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Harga Saat Ini
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Harga Jual Saat Ini:',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${item.formattedHarga} / ${item.satuan}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Input Harga Baru
                        const Text(
                          'Harga Jual Baru (Rp)*',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kTextColor),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: hargaController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            prefixStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                            hintText: 'Contoh: 18000',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: roleColor, width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Harga barang wajib diisi.';
                            }
                            final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                            if (parsed == null || parsed <= 0) {
                              return 'Harga harus berupa angka lebih dari 0.';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Tombol Penyesuaian Cepat (Quick Percentage Chips)
                        const Text(
                          'Penyesuaian Cepat (Markup / Diskon):',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildQuickMarkupChip('+5%', () => applyPercentage(5), roleColor),
                            _buildQuickMarkupChip('+10%', () => applyPercentage(10), roleColor),
                            _buildQuickMarkupChip('+15%', () => applyPercentage(15), roleColor),
                            _buildQuickMarkupChip('+20%', () => applyPercentage(20), roleColor),
                            _buildQuickMarkupChip('-5%', () => applyPercentage(-5), Colors.orange.shade700),
                            _buildQuickMarkupChip('-10%', () => applyPercentage(-10), Colors.red.shade700),
                            _buildQuickMarkupChip('Reset', () {
                              setDialogState(() {
                                hargaController.text = item.harga.toString();
                              });
                            }, const Color(0xFF64748B)),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Catatan Perubahan (Opsional)
                        const Text(
                          'Catatan / Alasan Perubahan (Opsional):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: catatanController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Misal: Penyesuaian harga produsen / promo sales',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Periode Berlaku Harga
                        const Text(
                          'Periode Berlaku Harga:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                                label: Text(
                                  'Mulai: ${startedAt.day}/${startedAt.month}/${startedAt.year}',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: startedAt,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      startedAt = picked;
                                      if (endedAt != null && !endedAt!.isAfter(startedAt)) {
                                        endedAt = null;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.event_available_outlined, size: 15),
                                label: Text(
                                  endedAt == null
                                      ? 'Akhir: Aktif Terus'
                                      : 'Akhir: ${endedAt!.day}/${endedAt!.month}/${endedAt!.year}',
                                  style: const TextStyle(fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: endedAt ?? startedAt.add(const Duration(days: 30)),
                                    firstDate: startedAt.add(const Duration(days: 1)),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => endedAt = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              actions: [
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: roleColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final cleanText = hargaController.text.replaceAll(RegExp(r'[^0-9]'), '');
                          final newPrice = int.tryParse(cleanText) ?? item.harga;

                          setDialogState(() => _isSaving = true);
                          setState(() => _isSaving = true);

                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          await InventoryService.updateProductPrice(
                            item.id,
                            newPrice,
                            updatedBy: currentUser?.id,
                            updatedByName: currentUser?.name ?? 'Admin',
                            keterangan: catatanController.text.trim(),
                            startedAt: startedAt,
                            endedAt: endedAt,
                          );

                          if (!mounted) return;
                          setState(() {
                            item.harga = newPrice;
                            _isSaving = false;
                          });

                          if (nav.canPop()) {
                            nav.pop();
                          }

                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Harga [${item.kodeBarang}] "${item.namaBarang}" berhasil diperbarui menjadi ${item.formattedHarga}!',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF15803D),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Simpan Harga',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickMarkupChip(String label, VoidCallback onTap, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildSalesProfileBanner(UserModel? user, bool isManager) {
    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'Pengguna Aktif';
    final userEmail = (user?.email.isNotEmpty == true) ? user!.email : 'CV Maju Bersama';
    final roleTitle = user?.roleDisplayTitle ?? 'Sales Lapangan';
    final profileLabel = _profileLabelForRole(user);
    final roleColor = _rolePrimaryColor(user);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showSalesProfilePopup(user, isManager),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: _roleGradient(user),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: roleColor.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: userName,
                radius: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white30, width: 0.8),
                        ),
                        child: Text(
                          roleTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white38),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    profileLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(UserModel? user, bool isManager) {
    final visibleProducts = isManager ? _products : _products.where((p) => p.isActive).toList();
    final totalProduk = visibleProducts.length;
    final totalStok = visibleProducts.fold<int>(0, (sum, p) => sum + p.stokGudang);
    final avgPrice = visibleProducts.isEmpty
        ? 0
        : (visibleProducts.map((p) => p.harga).reduce((a, b) => a + b) / visibleProducts.length).round();

    final highestProduct = visibleProducts.isEmpty
        ? null
        : visibleProducts.reduce((a, b) => a.harga > b.harga ? a : b);
    final lowestProduct = visibleProducts.isEmpty
        ? null
        : visibleProducts.reduce((a, b) => a.harga < b.harga ? a : b);

    String formatRp(int value) {
      return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final cards = [
          _buildStatCard(
            title: 'Total Produk',
            count: '$totalProduk Item',
            subtitle: 'Total Stok: $totalStok Unit',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF1D4ED8),
            bgColor: const Color(0xFFEFF6FF),
          ),
          _buildStatCard(
            title: 'Rata-Rata Harga',
            count: formatRp(avgPrice),
            subtitle: 'Dari $totalProduk produk aktif',
            icon: Icons.show_chart_rounded,
            color: const Color(0xFF0D9488),
            bgColor: const Color(0xFFF0FDFA),
          ),
          _buildStatCard(
            title: 'Harga Tertinggi',
            count: formatRp(highestProduct?.harga ?? 0),
            subtitle: highestProduct?.namaBarang ?? '-',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
          ),
          _buildStatCard(
            title: 'Harga Terendah',
            count: formatRp(lowestProduct?.harga ?? 0),
            subtitle: lowestProduct?.namaBarang ?? '-',
            icon: Icons.trending_down_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ];

        if (isNarrow) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: cards,
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<ProductItem> get _filteredProducts {
    final user = context.read<AuthProvider>().currentUser;
    final isManager = (user?.isSuperAdmin == true || user?.isAdmin == true);
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = _products.where((p) {
      if (!isManager && !p.isActive) return false;
      if (_selectedCategory != 'Semua' && p.kategori.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesName = p.namaBarang.toLowerCase().contains(query);
        final matchesCode = p.kodeBarang.toLowerCase().contains(query);
        final matchesKategori = p.kategori.toLowerCase().contains(query);
        return matchesName || matchesCode || matchesKategori;
      }
      return true;
    }).toList();

    switch (_selectedSort) {
      case 'Harga Terendah':
        list.sort((a, b) => a.harga.compareTo(b.harga));
        break;
      case 'Harga Tertinggi':
        list.sort((a, b) => b.harga.compareTo(a.harga));
        break;
      case 'Nama (A-Z)':
        list.sort((a, b) => a.namaBarang.toLowerCase().compareTo(b.namaBarang.toLowerCase()));
        break;
      case 'Stok Terbanyak':
        list.sort((a, b) => b.stokGudang.compareTo(a.stokGudang));
        break;
      default:
        list.sort((a, b) => a.id.compareTo(b.id));
        break;
    }

    return list;
  }

  List<String> get _categoryOptions {
    final categories = <String>{'Semua'};
    for (final p in _products) {
      if (p.kategori.trim().isNotEmpty) {
        categories.add(p.kategori.trim());
      }
    }
    return categories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isManager = (user?.isSuperAdmin == true || user?.isAdmin == true);
    final roleColor = _rolePrimaryColor(user);
    final roleLight = _roleLightColor(user);
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextColor),
          tooltip: 'Kembali ke Dashboard',
          onPressed: _backToDashboard,
        ),
        title: Text(
          isManager ? 'Master & Penetapan Harga Barang' : 'Daftar Harga Barang Resmi',
          style: const TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang Data Harga',
            onPressed: _isLoading ? null : _loadProducts,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                  )
                : const Icon(Icons.refresh_rounded, color: kTextColor),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showSalesProfilePopup(user, isManager),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: user?.name ?? 'Sales',
                radius: 17,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSalesProfileBanner(user, isManager),
              const SizedBox(height: 14),
              _buildSummaryCards(user, isManager),
              const SizedBox(height: 14),
              _buildMainTableCard(filtered, user, isManager, roleColor, roleLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTableCard(
    List<ProductItem> filtered,
    UserModel? user,
    bool isManager,
    Color roleColor,
    Color roleLight,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul Kartu
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: roleLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.monetization_on_rounded, color: roleColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isManager ? 'Daftar & Pengaturan Harga Jual' : 'Katalog Harga Jual Resmi',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      isManager
                          ? 'Kelola dan perbarui harga jual resmi produk untuk seluruh sales lapangan'
                          : 'Daftar harga jual resmi barang untuk transaksi penjualan toko & kanvas',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris Pencarian & Dropdown Sortir
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    hintText: 'Cari barang, kode, atau kategori...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: roleColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    icon: const Icon(Icons.sort_rounded, size: 18, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextColor),
                    items: ['Default', 'Harga Terendah', 'Harga Tertinggi', 'Nama (A-Z)', 'Stok Terbanyak']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSort = val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Kategori Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categoryOptions.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? roleColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? roleColor : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Konten Tabel / Kartu
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'Tidak ada data harga barang yang cocok.',
                      style: TextStyle(color: kSecondaryColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 640;
                if (isMobile) {
                  return _buildMobileCardList(filtered, isManager, roleColor);
                }
                return _buildDesktopTable(filtered, isManager, roleColor);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _tampilkanRiwayatHarga(ProductItem item) async {
    final history = await InventoryService.fetchPriceHistory(item.id);
    if (!mounted) return;

    String fmtDate(DateTime dt) {
      final d = dt.toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: kPrimaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Riwayat Harga: ${item.namaBarang}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Belum ada catatan perubahan harga untuk produk ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: kSecondaryColor),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final h = history[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: h.isCurrentlyActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: h.isCurrentlyActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${h.formattedHarga} / ${item.satuan}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: h.isCurrentlyActive ? const Color(0xFF15803D) : kTextColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: h.isCurrentlyActive ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    h.isCurrentlyActive ? 'Berlaku' : 'Riwayat',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: h.isCurrentlyActive ? const Color(0xFF15803D) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              h.keterangan.isNotEmpty ? h.keterangan : 'Pembaruan harga',
                              style: const TextStyle(fontSize: 12, color: kTextColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Berlaku: ${fmtDate(h.startedAt)} - ${h.endedAt != null ? fmtDate(h.endedAt!) : "Sekarang"} • Oleh: ${h.createdByName}',
                              style: const TextStyle(fontSize: 10.5, color: kSecondaryColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<ProductItem> list, bool isManager, Color roleColor) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('No', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
              Expanded(
                flex: 4,
                child: Text('Nama & Detail Barang', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('Kode Barang', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('Kategori', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('Stok Gudang', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
              Expanded(
                flex: 3,
                child: Text('Harga Jual Resmi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
              SizedBox(
                width: 156,
                child: Text('Aksi', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Table Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final item = list[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        ProductThumbnailWidget(
                          fotoUrl: item.fotoUrl,
                          namaBarang: item.namaBarang,
                          kategori: item.kategori,
                          size: 38,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaBarang,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Satuan: ${item.satuan}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          item.kodeBarang,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.kategori,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${item.stokGudang} ${item.satuan}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: item.stokGudang > 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sell_outlined, size: 13, color: Color(0xFF15803D)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: item.formattedHarga,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                                children: [
                                  TextSpan(
                                    text: ' / ${item.satuan}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 156,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Riwayat Harga',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.history_rounded, size: 19, color: Color(0xFF475569)),
                            onPressed: () => _tampilkanRiwayatHarga(item),
                          ),
                          const SizedBox(width: 4),
                          if (isManager)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: roleColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Ubah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _tampilkanDialogUbahHarga(item, isManager),
                            )
                          else
                            Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Harga Resmi',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileCardList(List<ProductItem> list, bool isManager, Color roleColor) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductThumbnailWidget(
                    fotoUrl: item.fotoUrl,
                    namaBarang: item.namaBarang,
                    kategori: item.kategori,
                    size: 48,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                item.kodeBarang,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.kategori,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.namaBarang,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: kTextColor),
                        ),
                        Text(
                          'Stok Gudang: ${item.stokGudang} ${item.satuan}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Harga Jual Resmi:', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      Row(
                        children: [
                          Text(
                            item.formattedHarga,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          Text(
                            ' / ${item.satuan}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Riwayat Harga',
                        icon: const Icon(Icons.history_rounded, size: 20, color: Color(0xFF475569)),
                        onPressed: () => _tampilkanRiwayatHarga(item),
                      ),
                      if (isManager)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: roleColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Ubah Harga', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _tampilkanDialogUbahHarga(item, isManager),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Harga Resmi',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
