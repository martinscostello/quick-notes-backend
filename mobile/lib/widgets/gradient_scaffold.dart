import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const GradientScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? AppTheme.darkGradient : AppTheme.lightGradientPinkPurple;

    return Scaffold(
      extendBody: true, // Allow body to go behind bars if transparent
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Important
      body: Stack(
        children: [
          // BACKGROUND
          Container(
            decoration: BoxDecoration(
              gradient: gradient,
            ),
          ),
          
          // BODY
          SafeArea(
             bottom: false, // Handle safe area manually if needed, or let child handle
             child: body,
          ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
