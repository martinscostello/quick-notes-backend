import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('quicknotes_v4.db'); // v4 to be safe 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Platform-specific initialization is handled in main.dart or here if needed
    // But since we are rebuilding, let's keep it simple and robust.
    
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // NOTES
    await db.execute('''
      CREATE TABLE notes (
        pageIndex INTEGER PRIMARY KEY,
        content TEXT NOT NULL,
        version INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL,
        updatedAt TEXT NOT NULL,
        isDirty INTEGER NOT NULL
      )
    ''');

    // TASKS
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        isDirty INTEGER NOT NULL
      )
    ''');
    
    // SEED PAGE 1
    await db.insert('notes', Note(pageIndex: 0, content: "").toMap());
  }

  // MARK: - Notes API

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final result = await db.query('notes', orderBy: 'pageIndex ASC');
    return result.map((json) => Note.fromMap(json)).toList();
  }

  Future<void> addPage() async {
    final db = await database;
    // Get max index
    final res = await db.rawQuery('SELECT MAX(pageIndex) as maxIdx FROM notes');
    int maxIdx = (res.first['maxIdx'] as int?) ?? -1;
    
    await db.insert('notes', Note(pageIndex: maxIdx + 1, content: "").toMap());
  }

  Future<void> saveNoteContent(int index, String content) async {
    final db = await database;
    await db.update(
      'notes',
      {'content': content, 'isDirty': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'pageIndex = ?',
      whereArgs: [index],
    );
  }

  Future<void> deletePage(int index) async {
    final db = await database;
    // 1. Delete
    await db.delete('notes', where: 'pageIndex = ?', whereArgs: [index]);
    
    // 2. Shift Left
    await db.rawUpdate(
      'UPDATE notes SET pageIndex = pageIndex - 1, isDirty = 1 WHERE pageIndex > ?',
      [index]
    );
  }

  // MARK: - Tasks API

  Future<List<TaskItem>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks');
    return result.map((json) => TaskItem.fromMap(json)).toList();
  }

  Future<void> addTask(String id, String title) async {
    final db = await database;
    await db.insert('tasks', TaskItem(id: id, title: title).toMap());
  }

  Future<void> toggleTask(String id, bool isCompleted) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isCompleted': isCompleted ? 1 : 0, 'isDirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
  // MARK: - Sync Helpers (Notes)

  Future<List<Note>> getDirtyNotes() async {
    final db = await database;
    final result = await db.query('notes', where: 'isDirty = 1');
    return result.map((json) => Note.fromMap(json)).toList();
  }

  Future<void> clearDirtyNotes(List<int> pageIndexes) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var idx in pageIndexes) {
        await txn.update('notes', {'isDirty': 0}, where: 'pageIndex = ?', whereArgs: [idx]);
      }
    });
  }

  Future<void> upsertNoteFromSync(Note note) async {
    final db = await database;
    // We trust server version.
    await db.insert('notes', note.toMap()..['isDirty'] = 0, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // MARK: - Sync Helpers (Tasks)

  Future<List<TaskItem>> getDirtyTasks() async {
    final db = await database;
    final result = await db.query('tasks', where: 'isDirty = 1');
    return result.map((json) => TaskItem.fromMap(json)).toList();
  }

  Future<void> clearDirtyTasks(List<String> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var id in ids) {
        await txn.update('tasks', {'isDirty': 0}, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<void> upsertTaskFromSync(TaskItem task) async {
    final db = await database;
    await db.insert('tasks', task.toMap()..['isDirty'] = 0, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
