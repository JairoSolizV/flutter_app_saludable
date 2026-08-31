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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -36,
              right: -28,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryLighter.withOpacity(0.45),
                ),
              ),
            ),
            Positioned(
              top: 28,
              right: -18,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryLight.withOpacity(0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.badge,
                          size: 22,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mi membresía',
                          style: textTheme.titleLarge?.copyWith(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ) ??
                              const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        clubName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ) ??
                            const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ),
                  ),
                  if (showLevel) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.award,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Nivel: $level',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ) ??
                                const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 300 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.25;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MetricBlock(
                              icon: LucideIcons.star,
                              value: formatPoints(points),
                              label: 'Puntos acumulados',
                              compact: compact,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 12,
                              vertical: 4,
                            ),
                            child: Container(
                              width: 1,
                              height: compact ? 40 : 44,
                              color: AppTheme.divider,
                            ),
                          ),
                          Expanded(
                            child: _MetricBlock(
                              icon: LucideIcons.calendarCheck,
                              value: formatAttendanceValue(attendanceCount),
                              label: 'Asistencias registradas',
                              compact: compact,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.user,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'N.º de socio',
                                style: textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatMemberNumber(memberNumber),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: 0.4,
                                    ) ??
                                    const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: 0.4,
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
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool compact;

  const _MetricBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: compact ? 18 : 22,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ) ??
                    TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ) ??
              const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}
