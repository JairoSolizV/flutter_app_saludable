import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Resumen real de membresía del socio (sin mecánicas de fidelidad inventadas).
class MemberSummaryCard extends StatelessWidget {
  final String clubName;
  final String memberNumber;
  final int points;
  final int? attendanceCount;
  final String? membershipLevel;

  const MemberSummaryCard({
    super.key,
    required this.clubName,
    required this.memberNumber,
    required this.points,
    this.attendanceCount,
    this.membershipLevel,
  });

  static String formatMemberNumber(String number) {
    final trimmed = number.trim();
    if (trimmed.isEmpty) return 'No disponible';
    return trimmed;
  }

  static String formatAttendanceValue(int? count) {
    if (count == null) return 'No disponible';
    if (count == 1) return '1 asistencia';
    return '$count asistencias';
  }

  static String formatPoints(int points) => '$points pts';

  @override
  Widget build(BuildContext context) {
    final level = membershipLevel?.trim();
    final showLevel = level != null && level.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi membresía',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.building2,
                  size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  clubName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C5E1A),
                  ),
                ),
              ),
            ],
          ),
          if (showLevel) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.award, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Nivel: $level',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  icon: LucideIcons.star,
                  value: formatPoints(points),
                  label: 'Puntos acumulados',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatColumn(
                  icon: LucideIcons.calendarCheck,
                  value: formatAttendanceValue(attendanceCount),
                  label: 'Asistencias registradas',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.badge, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              const Text(
                'N.º de socio',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatMemberNumber(memberNumber),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
