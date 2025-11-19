import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget reutilizável para cabeçalhos de seção em páginas admin
/// 
/// Substitui múltiplas implementações do método _buildSectionHeader
/// encontradas em admin_missions_management_page e outras páginas
class AdminSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;

  const AdminSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveBackgroundColor = backgroundColor ?? effectiveIconColor.withOpacity(0.2);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: effectiveIconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  effectiveIconColor.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
