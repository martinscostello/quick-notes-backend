import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggedIn = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final logged = await AuthService.instance.isLoggedIn();
    // In a real app we'd decode the JWT to get the email or store it properly.
    // For now we just show "User".
    setState(() {
      _isLoggedIn = logged;
      _email = logged ? "User" : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return GradientScaffold(
      body: CustomScrollView(
        slivers: [
          // Nav Bar
          SliverAppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ACCOUNT SECTION
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text("ACCOUNT", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                  ),
                  GlassContainer(
                     width: double.infinity,
                     child: _isLoggedIn ? _buildLoggedInView(textColor, secondaryTextColor) : _buildGuestView(textColor, secondaryTextColor),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // APPEARANCE SECTION
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text("APPEARANCE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                  ),
                  GlassContainer(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Theme", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
                        CupertinoSlidingSegmentedControl<ThemeMode>(
                          groupValue: AppTheme.instance.themeMode,
                          thumbColor: isDark ? Colors.grey.shade800 : Colors.white,
                          backgroundColor: isDark ? Colors.black26 : Colors.black12,
                          children: {
                            ThemeMode.system: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), 
                                child: Text("Auto", style: TextStyle(color: _getSegmentColor(ThemeMode.system, isDark)))),
                            ThemeMode.light: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), 
                                child: Text("Light", style: TextStyle(color: _getSegmentColor(ThemeMode.light, isDark)))),
                            ThemeMode.dark: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), 
                                child: Text("Dark", style: TextStyle(color: _getSegmentColor(ThemeMode.dark, isDark)))),
                          },
                          onValueChanged: (val) {
                             if (val != null) {
                                AppTheme.instance.setThemeMode(val);
                                setState(() {}); // Rebuild
                             }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // ABOUT SECTION
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text("ABOUT", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                  ),
                  GlassContainer(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Quick Notes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text("Version 1.0.0", style: TextStyle(color: secondaryTextColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getSegmentColor(ThemeMode mode, bool isDark) {
      if (AppTheme.instance.themeMode == mode) {
          return isDark ? Colors.white : Colors.black;
      }
      return isDark ? Colors.white70 : Colors.black87;
  }

  Widget _buildGuestView(Color textColor, Color secondaryColor) {
    return Column(
      children: [
        Icon(Icons.cloud_off, size: 40, color: secondaryColor),
        const SizedBox(height: 12),
        Text("Sign in to sync your notes", style: TextStyle(color: secondaryColor)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Text("Sign In / Sign Up"),
            onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                if (res == true) _checkStatus();
            },
          ),
        )
      ],
    );
  }

  Widget _buildLoggedInView(Color textColor, Color secondaryColor) {
    return Row(
      children: [
        const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 16),
        Expanded(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(_email ?? "User", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
               const Text("Synced", style: TextStyle(fontSize: 12, color: Colors.green)),
             ],
           ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: () async {
             await AuthService.instance.logout();
             _checkStatus();
          },
        )
      ],
    );
  }
}
