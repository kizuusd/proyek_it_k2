import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';

// ─────────────────────────────────────────────
// Model: Data Profil Pengguna
// ─────────────────────────────────────────────
class _ProfilData {
  String nama;
  String email;
  String noTelepon;
  String alamat;
  int umur;
  String jenisKelamin;
  String jabatan;
  String nip;
  String kotaDomisili;
  String tanggalBergabung;

  _ProfilData({
    required this.nama,
    required this.email,
    required this.noTelepon,
    required this.alamat,
    required this.umur,
    required this.jenisKelamin,
    required this.jabatan,
    required this.nip,
    required this.kotaDomisili,
    required this.tanggalBergabung,
  });

  _ProfilData copyWith({
    String? nama,
    String? email,
    String? noTelepon,
    String? alamat,
    int? umur,
    String? jenisKelamin,
    String? jabatan,
    String? nip,
    String? kotaDomisili,
    String? tanggalBergabung,
  }) {
    return _ProfilData(
      nama: nama ?? this.nama,
      email: email ?? this.email,
      noTelepon: noTelepon ?? this.noTelepon,
      alamat: alamat ?? this.alamat,
      umur: umur ?? this.umur,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      jabatan: jabatan ?? this.jabatan,
      nip: nip ?? this.nip,
      kotaDomisili: kotaDomisili ?? this.kotaDomisili,
      tanggalBergabung: tanggalBergabung ?? this.tanggalBergabung,
    );
  }
}

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class FR11ProfilScreen extends StatefulWidget {
  const FR11ProfilScreen({Key? key}) : super(key: key);

  @override
  State<FR11ProfilScreen> createState() => _FR11ProfilScreenState();
}

class _FR11ProfilScreenState extends State<FR11ProfilScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnim;
  late AnimationController _cardsAnim;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late List<Animation<double>> _cardFades;

  bool _isEditMode = false;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _teleponCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _umurCtrl;
  late TextEditingController _nipCtrl;
  late TextEditingController _kotaCtrl;

  String _jenisKelamin = 'Laki-laki';

  late _ProfilData _profil;

  @override
  void initState() {
    super.initState();

    _profil = _ProfilData(
      nama: 'Dimas Brahamsyah',
      email: 'dimas@majubersama.com',
      noTelepon: '+62 812 3456 7890',
      alamat: 'Jl. Merdeka No. 12, RT 03/RW 05, Kel. Sukamaju',
      umur: 28,
      jenisKelamin: 'Laki-laki',
      jabatan: 'Sales Lapangan',
      nip: 'NIP-2024-0123',
      kotaDomisili: 'Bandung',
      tanggalBergabung: '15 Maret 2024',
    );
    _jenisKelamin = _profil.jenisKelamin;

    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut));

    _cardsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardFades = List.generate(
      6,
      (i) => CurvedAnimation(
        parent: _cardsAnim,
        curve: Interval(i * 0.12, (i * 0.12) + 0.4, curve: Curves.easeOut),
      ),
    );

    _headerAnim.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsAnim.forward();
    });

    _initControllers();
  }

  void _initControllers() {
    _namaCtrl = TextEditingController(text: _profil.nama);
    _emailCtrl = TextEditingController(text: _profil.email);
    _teleponCtrl = TextEditingController(text: _profil.noTelepon);
    _alamatCtrl = TextEditingController(text: _profil.alamat);
    _umurCtrl = TextEditingController(text: _profil.umur.toString());
    _nipCtrl = TextEditingController(text: _profil.nip);
    _kotaCtrl = TextEditingController(text: _profil.kotaDomisili);
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _cardsAnim.dispose();
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _teleponCtrl.dispose();
    _alamatCtrl.dispose();
    _umurCtrl.dispose();
    _nipCtrl.dispose();
    _kotaCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _jenisKelamin = _profil.jenisKelamin;
      _namaCtrl.text = _profil.nama;
      _emailCtrl.text = _profil.email;
      _teleponCtrl.text = _profil.noTelepon;
      _alamatCtrl.text = _profil.alamat;
      _umurCtrl.text = _profil.umur.toString();
      _nipCtrl.text = _profil.nip;
      _kotaCtrl.text = _profil.kotaDomisili;
    });
  }

  void _cancelEdit() {
    setState(() => _isEditMode = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _profil = _profil.copyWith(
        nama: _namaCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        noTelepon: _teleponCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        umur: int.tryParse(_umurCtrl.text.trim()) ?? _profil.umur,
        jenisKelamin: _jenisKelamin,
        nip: _nipCtrl.text.trim(),
        kotaDomisili: _kotaCtrl.text.trim(),
      );
      _isEditMode = false;
      _isSaving = false;
    });
    _showSnack('Profil berhasil diperbarui!');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kDangerColor : kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: kDangerColor),
          SizedBox(width: 10),
          Text('Konfirmasi Logout', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(color: kSubtitleColor),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showSnack('Berhasil logout.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kDangerColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(children: [
            _buildHeaderBanner(),
            const SizedBox(height: 24),
            _buildInfoSection(),
            const SizedBox(height: 16),
            _buildPersonalSection(),
            const SizedBox(height: 16),
            _buildKantorSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        _isEditMode ? 'Edit Profil' : 'Profil Saya',
        style: const TextStyle(
            color: kTextColor, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: kTextColor),
      actions: [
        if (!_isEditMode)
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: kAccentColor),
            tooltip: 'Edit Profil',
            onPressed: _enterEditMode,
          ),
        if (_isEditMode)
          TextButton(
            onPressed: _cancelEdit,
            child: const Text('Batal',
                style: TextStyle(
                    color: kDangerColor, fontWeight: FontWeight.w600)),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE5E7EB), height: 1),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: kPrimaryGradientColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF1565C0),
                    child: Text(
                      _getInitials(_profil.nama),
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                if (_isEditMode)
                  GestureDetector(
                    onTap: () =>
                        _showSnack('Fitur ubah foto akan segera hadir!'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kAccentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _profil.nama,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _profil.jabatan,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _profil.nip,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniStat(
                    Icons.cake_rounded, '${_profil.umur} Tahun'),
                const SizedBox(width: 24),
                _buildMiniStat(
                    Icons.location_city_rounded, _profil.kotaDomisili),
                const SizedBox(width: 24),
                _buildMiniStat(Icons.calendar_today_rounded,
                    _profil.tanggalBergabung),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildInfoSection() {
    return _buildCard(
      index: 0,
      title: 'Informasi Kontak',
      icon: Icons.contact_page_rounded,
      children: [
        _buildField(
          label: 'Nama Lengkap',
          icon: Icons.person_rounded,
          controller: _namaCtrl,
          isEdit: _isEditMode,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Nama tidak boleh kosong'
              : null,
          hint: 'Masukkan nama lengkap',
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Email',
          icon: Icons.email_rounded,
          controller: _emailCtrl,
          isEdit: _isEditMode,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
            if (!emailValidatorRegExp.hasMatch(v.trim())) {
              return 'Format email tidak valid';
            }
            return null;
          },
          hint: 'contoh@email.com',
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Nomor Telepon',
          icon: Icons.phone_rounded,
          controller: _teleponCtrl,
          isEdit: _isEditMode,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Nomor telepon tidak boleh kosong';
            }
            if (v.trim().length < 9) return 'Nomor telepon terlalu pendek';
            return null;
          },
          hint: '+62 8xx xxxx xxxx',
        ),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return _buildCard(
      index: 1,
      title: 'Data Pribadi',
      icon: Icons.badge_rounded,
      children: [
        _buildField(
          label: 'Umur',
          icon: Icons.cake_rounded,
          controller: _umurCtrl,
          isEdit: _isEditMode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffixText: 'tahun',
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Umur tidak boleh kosong';
            final umur = int.tryParse(v);
            if (umur == null || umur < 17 || umur > 80) {
              return 'Masukkan umur yang valid (17-80)';
            }
            return null;
          },
          hint: 'Contoh: 28',
        ),
        const SizedBox(height: 14),
        _buildJenisKelaminRow(),
        const SizedBox(height: 14),
        _buildField(
          label: 'Alamat Lengkap',
          icon: Icons.home_rounded,
          controller: _alamatCtrl,
          isEdit: _isEditMode,
          maxLines: 3,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Alamat tidak boleh kosong'
              : null,
          hint: 'Jl. Nama Jalan No. X, RT/RW, Kelurahan...',
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Kota / Domisili',
          icon: Icons.location_city_rounded,
          controller: _kotaCtrl,
          isEdit: _isEditMode,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Kota tidak boleh kosong'
              : null,
          hint: 'Masukkan kota domisili',
        ),
      ],
    );
  }

  Widget _buildKantorSection() {
    return _buildCard(
      index: 2,
      title: 'Data Kantor',
      icon: Icons.business_center_rounded,
      children: [
        _buildInfoTile(
          label: 'Jabatan',
          value: _profil.jabatan,
          icon: Icons.work_rounded,
          isReadOnly: true,
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'NIP / Kode Karyawan',
          icon: Icons.fingerprint_rounded,
          controller: _nipCtrl,
          isEdit: _isEditMode,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'NIP tidak boleh kosong'
              : null,
          hint: 'Contoh: NIP-2024-0123',
        ),
        const SizedBox(height: 14),
        _buildInfoTile(
          label: 'Tanggal Bergabung',
          value: _profil.tanggalBergabung,
          icon: Icons.calendar_today_rounded,
          isReadOnly: true,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FadeTransition(
        opacity: _cardFades.last,
        child: Column(children: [
          if (_isEditMode) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccessColor,
                  disabledBackgroundColor:
                      kSuccessColor.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Simpan Perubahan',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _cancelEdit,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kDangerColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Batal Edit',
                    style: TextStyle(
                        color: kDangerColor, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _enterEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                label: const Text('Edit Profil',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _showLogoutDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kDangerColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout_rounded, color: kDangerColor),
                label: const Text('Logout',
                    style: TextStyle(
                        color: kDangerColor, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildCard({
    required int index,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return FadeTransition(
      opacity:
          index < _cardFades.length ? _cardFades[index] : _cardFades.last,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: kPrimaryLightColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(children: [
                Icon(icon, size: 18, color: kPrimaryColor),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isEdit,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    String hint = '',
    String? suffixText,
  }) {
    if (!isEdit) {
      return _buildInfoTile(
        label: label,
        value: controller.text.isEmpty ? '-' : controller.text,
        icon: icon,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 15, color: kAccentColor),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kSubtitleColor)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: kTextColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFF),
            suffixText: suffixText,
            suffixStyle:
                const TextStyle(color: kSubtitleColor, fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAccentColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerColor, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
    bool isReadOnly = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kPrimaryLightColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: kPrimaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: kSubtitleColor,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          color: kTextColor,
                          fontWeight: FontWeight.w600)),
                ),
                if (isReadOnly)
                  const Icon(Icons.lock_outline_rounded,
                      size: 13, color: kSubtitleColor),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJenisKelaminRow() {
    if (!_isEditMode) {
      return _buildInfoTile(
        label: 'Jenis Kelamin',
        value: _profil.jenisKelamin,
        icon: Icons.wc_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.wc_rounded, size: 15, color: kAccentColor),
          SizedBox(width: 6),
          Text('Jenis Kelamin',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kSubtitleColor)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _buildGenderChip('Laki-laki', Icons.male_rounded),
          const SizedBox(width: 10),
          _buildGenderChip('Perempuan', Icons.female_rounded),
        ]),
      ],
    );
  }

  Widget _buildGenderChip(String value, IconData icon) {
    final bool selected = _jenisKelamin == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _jenisKelamin = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kAccentColor : const Color(0xFFF8FAFF),
            border: Border.all(
              color: selected ? kAccentColor : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : kSubtitleColor),
              const SizedBox(width: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : kSubtitleColor)),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
