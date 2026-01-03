import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'notes_page.dart';
import 'tasks_page.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';
import '../widgets/squircle_icon_button.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedMode = 0; // 0 = Notes, 1 = Tasks
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  // deeply simple way to pass data down: StreamController
  final StreamController<DictationEvent> _dictationStream = StreamController<DictationEvent>.broadcast();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    SyncService.instance.syncData();
  }

  Future<void> _checkLoginStatus() async {
      // Just check token presence to ensure we are ready for sync later
      // We don't necessarily need to force login on startup, but we can update UI state if we had one.
  }

  Future<void> _handleProfileTap() async {
      bool loggedIn = await AuthService.instance.isLoggedIn();
      
      if (!loggedIn) {
          if (!mounted) return;
          bool? result = await Navigator.push(
             context,
             MaterialPageRoute(builder: (_) => const AuthScreen())
          );
          
          if (result == true) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged in successfully")));
              SyncService.instance.syncData();
          }
      } else {
          if (!mounted) return;
          showDialog(
             context: context, 
             builder: (context) => AlertDialog(
                 title: const Text("Account"),
                 content: const Text("You are logged in. Do you want to logout?"),
                 actions: [
                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                     TextButton(
                         onPressed: () async {
                             await AuthService.instance.logout();
                             if (mounted) Navigator.pop(context);
                             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out")));
                         }, 
                         child: const Text("Logout", style: TextStyle(color: Colors.red))
                     ),
                 ],
             )
          );
      }
  }

  Future<void> _toggleDictation() async {
      if (_isListening) {
          await _speech.stop();
          setState(() => _isListening = false);
      } else {
          // 1. Check Permissions
          Map<Permission, PermissionStatus> statuses = await [
            Permission.microphone,
            Permission.speech,
          ].request();

          if (statuses[Permission.microphone] != PermissionStatus.granted) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Microphone permission denied")));
             return;
          }

          // 2. Initialize
          bool available = await _speech.initialize(
             onStatus: (val) {
                if (val == 'done' || val == 'notListening') {
                    setState(() => _isListening = false);
                }
             },
             onError: (val) {
                print("Dictation Error: ${val.errorMsg}");
                setState(() => _isListening = false);
                if (val.errorMsg != 'error_no_match' && mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dictation Error: ${val.errorMsg}")));
                }
             },
          );

          if (available) {
              setState(() => _isListening = true);
              _speech.listen(
                  onResult: (val) {
                      _dictationStream.add(DictationEvent(val.recognizedWords, val.finalResult));
                  },
                  listenFor: const Duration(hours: 1),
                  pauseFor: const Duration(seconds: 60),
                  localeId: "en_US", 
                  cancelOnError: false, 
                  partialResults: true, 
              );
          } else {
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Speech recognition not available on this device")));
              }
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Column(
        children: [
          // FLOATING GLASS HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LEFT: MIC
                SquircleIconButton(
                  icon: _isListening ? Icons.mic : Icons.mic_none_rounded,
                  iconColor: _isListening 
                      ? Colors.red 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                  isActive: _isListening,
                  onPressed: _toggleDictation,
                  size: 26,
                ),
                
                // CENTER: SEGMENTED CONTROL (In Glass)
                GlassContainer(
                   padding: const EdgeInsets.all(4),
                   borderRadius: 12,
                   height: 44,
                   shadows: Theme.of(context).brightness == Brightness.dark ? null : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                   ],
                   child: CupertinoSlidingSegmentedControl<int>(
                     groupValue: _selectedMode,
                     backgroundColor: Colors.transparent, 
                     thumbColor: Colors.white, 
                     padding: EdgeInsets.zero,
                     children: {
                       0: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), 
                          child: _buildSegment("Notes", isSelected: _selectedMode == 0)),
                       1: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), 
                          child:  _buildSegment("Tasks", isSelected: _selectedMode == 1)),
                     },
                     onValueChanged: (int? newValue) {
                       if (newValue != null) {
                         setState(() => _selectedMode = newValue);
                       }
                     },
                   ),
                ),
                
                // RIGHT: SETTINGS
                SquircleIconButton(
                  icon: Icons.settings_outlined, // Gear Icon
                  onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                  size: 26,
                ),
              ],
            ),
          ),
          
          // BODY CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlassContainer(
                 width: double.infinity,
                 borderRadius: 24,
                 opacity: 0.6, // Higher opacity for editor background
                 padding: EdgeInsets.zero, // Let child handle padding
                 child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _selectedMode == 0 
                      ? NotesPageUI(dictationStream: _dictationStream.stream) 
                      : TasksPageUI(),
                 ),
              ),
            ),
          ),
          
          const SizedBox(height: 8), // Bottom Safe Area space
        ],
      ),
    );
  }
  
  Widget _buildSegment(String text, {required bool isSelected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Color Logic:
    Color textColor;
    if (isSelected) {
        textColor = Colors.black; // Thumb is white
    } else {
        textColor = isDark ? Colors.white : Colors.black87;
    }
  
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }
}
