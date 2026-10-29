import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 28,
    this.backgroundColor = const Color(0xFFEFF6FF),
    this.textColor = const Color(0xFF1D4ED8),
    this.fontSize,
  });

  Widget _buildInitialsFallback(double size) {
    final trimmed = name.trim();
    String initials = 'U';
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = trimmed[0].toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize ?? (radius * 0.68),
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final raw = photoUrl?.trim() ?? '';

    if (raw.isEmpty || raw.startsWith('preset:')) {
      return _buildInitialsFallback(size);
    }

    // 1. Base64 Image (Hasil Upload Galeri / Kamera)
    if (raw.startsWith('data:image')) {
      try {
        final commaIdx = raw.indexOf(',');
        final b64 = commaIdx != -1 ? raw.substring(commaIdx + 1) : raw;
        final bytes = base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _buildInitialsFallback(size),
          ),
        );
      } catch (_) {
        return _buildInitialsFallback(size);
      }
    }

    // 2. Asset Image Lokal
    if (raw.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          raw,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialsFallback(size),
        ),
      );
    }

    // 3. URL Gambar Eksternal (HTTP / HTTPS - Foto Profil Akun / Google)
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final resolvedUrl = kIsWeb && !raw.contains('/api/users/avatar-proxy')
          ? '${AuthService.activeBaseUrl}/users/avatar-proxy?url=${Uri.encodeComponent(raw)}'
          : raw;

      return ClipOval(
        child: Image.network(
          resolvedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialsFallback(size),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildInitialsFallback(size),
                SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // 4. File Path Lokal (Mobile / Desktop)
    if (!kIsWeb) {
      try {
        final file = File(raw);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitialsFallback(size),
            ),
          );
        }
      } catch (_) {}
    }

    return _buildInitialsFallback(size);
  }
}
