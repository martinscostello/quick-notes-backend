import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider.value(
      value: AppTheme.instance,
      child: const QuickNotesApp(),
    ),
  );
}

class QuickNotesApp extends StatelessWidget {
  const QuickNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar style to dark icons (Apple style light mode)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Consumer<AppTheme>(
      builder: (context, theme, _) {
          return MaterialApp(
            title: 'QuickNotes',
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode,
            theme: ThemeData(
              fontFamily: 'SF Pro Display', 
              scaffoldBackgroundColor: Colors.white,
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.light,
              dividerColor: const Color(0xFFE5E5EA), 
            ),
            darkTheme: ThemeData(
              fontFamily: 'SF Pro Display',
              scaffoldBackgroundColor: Colors.black,
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.dark,
              dividerColor: const Color(0xFF38383A),
            ),
            home: const MainScreen(),
          );
      },
    );
  }
}
