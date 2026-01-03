import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models.dart';
import '../database/local_database.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  // Simple listener for UI updates
  final ValueNotifier<bool> syncingNotifier = ValueNotifier(false);

  Future<void> syncData() async {
    if (_isSyncing) return;
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    if (!isLoggedIn) return;

    _setSyncing(true);

    try {
      await _syncNotes();
      // await _syncTasks(); // TODO: Implement Task Sync similarly
    } catch (e) {
      print("Sync Error: $e");
    } finally {
      _setSyncing(false);
    }
  }

  void _setSyncing(bool value) {
    _isSyncing = value;
    syncingNotifier.value = value;
  }

  // MARK: - Notes Sync

  Future<void> _syncNotes() async {
    // 1. Get Local Changes (PUSH)
    final dirtyNotes = await LocalDatabase.instance.getDirtyNotes();
    
    // 2. Get Last Sync Timestamp
    final prefs = await SharedPreferences.getInstance();
    final lastSyncKey = 'last_sync_notes';
    final lastSync = prefs.getString(lastSyncKey);

    // 3. Prepare Payload
    final payload = {
      'changes': dirtyNotes.map((n) => n.toMap()).toList(),
      'lastSyncTimestamp': lastSync
    };

    // 4. API Call
    final response = await ApiService.instance.post('/notes/sync', payload);

    if (response != null) {
      // 5. Process Server Changes (PULL)
      if (response['changes'] != null) {
         final serverNotes = List<dynamic>.from(response['changes']);
         for (var noteData in serverNotes) {
             final note = Note.fromMap(noteData);
             await LocalDatabase.instance.upsertNoteFromSync(note);
         }
      }

      // 6. Mark Local Pushed as Clean
      if (dirtyNotes.isNotEmpty) {
        final pushedIds = dirtyNotes.map((n) => n.pageIndex).toList();
        await LocalDatabase.instance.clearDirtyNotes(pushedIds);
      }

      // 7. Update Timestamp
      if (response['serverTime'] != null) {
        await prefs.setString(lastSyncKey, response['serverTime']);
      }
    }
  }
}
