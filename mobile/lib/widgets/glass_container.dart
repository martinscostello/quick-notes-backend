import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget? child;
  final double opacity;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  final Color? color;
  final List<BoxShadow>? shadows;
  final BoxBorder? border; // Good for glass borders

  const GlassContainer({
    super.key,
    this.child,
    this.opacity = 0.2, // Default transparency
    this.blur = 15.0,   // Default blur
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.color,
    this.shadows,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? (isDark ? Colors.black : Colors.white);

    // If shadows are present, we need an outer container to paint them.
    // Shadows don't work well with ClipRRect directly if strict clipping is needed,
    // but usually we want shadow outside the clip.
    
    Widget glassContent = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
             color: baseColor.withValues(alpha: opacity),
             borderRadius: BorderRadius.circular(borderRadius),
             border: border ?? Border.all(
                 color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
                 width: 1.0,
             ),
          ),
          child: child,
        ),
      ),
    );

    if (shadows != null && shadows!.isNotEmpty) {
      glassContent = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows,
          // No color here, or it blocks the glass
        ),
        child: glassContent,
      );
    }

    if (margin != null) {
      glassContent = Padding(padding: margin!, child: glassContent);
    }
    
    if (onTap != null) {
        return GestureDetector(
            onTap: onTap,
            child: glassContent,
        );
    }
    
    return glassContent;
  }
}
