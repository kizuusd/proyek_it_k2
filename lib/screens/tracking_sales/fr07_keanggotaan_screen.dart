import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'fr12_register_screen.dart';

class FR07KeanggotaanScreen extends StatefulWidget {
  const FR07KeanggotaanScreen({Key? key}) : super(key: key);

  @override
  State<FR07KeanggotaanScreen> createState() => _FR07KeanggotaanScreenState();
}

class _FR07KeanggotaanScreenState extends State<FR07KeanggotaanScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final list = await authProvider.getAllUsers();
    if (mounted) {
      setState(() {
        _users = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final bool isManager = currentUser != null && currentUser.isManager;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text(
          'Kelola Keanggotaan',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kPrimaryColor),
            tooltip: 'Segarkan Data',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _loadUsers,
              color: kPrimaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isManager ? Colors.blue.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isManager ? Colors.blue.shade200 : Colors.amber.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isManager ? Icons.verified_user_outlined : Icons.info_outline,
                          color: isManager ? Colors.blue.shade700 : Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isManager
                                ? 'Anda memiliki hak manajerial (${currentUser.roleDisplayTitle}). Anda dapat mendaftarkan akun Sales baru melalui tombol di bawah.'
                                : 'Khusus akun Sales tidak dapat mendaftarkan akun baru. Pendaftaran akun Sales hanya dapat dilakukan oleh Admin dan Owner.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isManager ? Colors.blue.shade900 : Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Header List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Anggota Tim (${_users.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextColor,
                        ),
                      ),
                      Text(
                        'CV Maju Bersama',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // List Kartu Anggota
                  ..._users.map((user) => _buildUserCard(user)).toList(),
                ],
              ),
            ),
      // Tombol Daftarkan Sales Baru HANYA untuk Admin & Owner
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryColor,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FR12RegisterScreen()),
                );
                if (result == true) {
                  _loadUsers();
                }
              },
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text(
                'Daftarkan Sales Baru',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildUserCard(UserModel user) {
    Color badgeColor;
    if (user.isSuperAdmin) {
      badgeColor = Colors.purple;
    } else if (user.isAdmin) {
      badgeColor = Colors.blue.shade700;
    } else {
      badgeColor = Colors.teal.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: badgeColor.withValues(alpha: 0.15),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: kTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user.isActive ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: user.isActive ? Colors.green.shade200 : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          user.isActive ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: user.isActive ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.roleDisplayTitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      if (user.googleId != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.g_mobiledata_rounded, size: 14, color: Colors.blue),
                              Text('Gmail', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
