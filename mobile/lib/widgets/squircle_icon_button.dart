import 'package:flutter/material.dart';
import 'glass_container.dart';

class SquircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool isActive;
  final double size;

  const SquircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.isActive = false,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Icon Color: White in Dark Mode, Black (default) in Light Mode unless overridden
    final effectiveIconColor = iconColor ?? (isDark ? Colors.white : Colors.black87);
    
    // Shadows: Add lift in Light Mode
    final List<BoxShadow>? shadows = isDark ? null : [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.15), // Increased from 0.05
            offset: const Offset(0, 4),
            blurRadius: 10,
            spreadRadius: 1,
        )
    ];

    return GlassContainer(
       width: 44,
       height: 44,
       borderRadius: 14, // Squircle-ish
       padding: EdgeInsets.zero,
       opacity: isActive ? 0.6 : (isDark ? 0.2 : 0.3), 
       blur: 10,
       onTap: onPressed,
       shadows: shadows, // Apply shadows
       child: Center(
           child: Icon(icon, color: effectiveIconColor, size: size),
       ),
    );
  }
}
