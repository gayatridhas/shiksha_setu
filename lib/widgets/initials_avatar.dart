import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? backgroundColor;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.backgroundColor,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Color _getColor(String name) {
    if (backgroundColor != null) return backgroundColor!;
    final colors = [
      const Color(0xFF1B3A6B),
      const Color(0xFF27AE60),
      const Color(0xFF8E44AD),
      const Color(0xFF2471A3),
      const Color(0xFFD35400),
      const Color(0xFF16A085),
      const Color(0xFF2C3E50),
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getColor(name),
      child: Text(
        _getInitials(name),
        style: GoogleFonts.poppins(
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
