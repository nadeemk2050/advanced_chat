import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../models/personal_models.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;

  Future<Database?> get database async {
    if (kIsWeb) return null; // SAFETY: No SQLite on Web
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'chat_history.db');
    return await openDatabase(
      path,
      version: 3, // Upgraded version for task groups
      onCreate: (db, version) async {
        await _createDb(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE personal_tasks(
              id TEXT PRIMARY KEY,
              title TEXT,
              description TEXT,
              dueDate INTEGER,
              isCompleted INTEGER,
              createdAt INTEGER,
              hasAlarm INTEGER DEFAULT 0,
              alarmTime INTEGER,
              groupId TEXT
            )
          ''');
        } else if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE task_groups(
              id TEXT PRIMARY KEY,
              title TEXT,
              createdAt INTEGER
            )
          ''');
          // Add missing columns to personal_tasks if not there
          try { await db.execute('ALTER TABLE personal_tasks ADD COLUMN hasAlarm INTEGER DEFAULT 0'); } catch(_) {}
          try { await db.execute('ALTER TABLE personal_tasks ADD COLUMN alarmTime INTEGER'); } catch(_) {}
          try { await db.execute('ALTER TABLE personal_tasks ADD COLUMN groupId TEXT'); } catch(_) {}
        }
      },
    );
  }

  Future<void> _createDb(Database db) async {
    await db.execute('''
      CREATE TABLE messages(
        messageId TEXT PRIMARY KEY,
        chatRoomId TEXT,
        senderId TEXT,
        text TEXT,
        timestamp TEXT,
        type TEXT,
        mediaUrl TEXT,
        fileName TEXT,
        status INTEGER,
        isGroup INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE personal_tasks(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        dueDate INTEGER,
        isCompleted INTEGER,
        createdAt INTEGER,
        hasAlarm INTEGER DEFAULT 0,
        alarmTime INTEGER,
        groupId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE task_groups(
        id TEXT PRIMARY KEY,
        title TEXT,
        createdAt INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_msg_text ON messages(text)');
    await db.execute('CREATE INDEX idx_msg_room ON messages(chatRoomId)');
  }

  Future<void> saveMessage(MessageModel msg, String chatRoomId, {bool isGroup = false}) async {
    if (kIsWeb) return; 
    final db = await database;
    if (db == null) return;
    
    final data = msg.toMap();
    await db.insert(
      'messages',
      {
        ...data, 
        'chatRoomId': chatRoomId, 
        'timestamp': msg.timestamp.toIso8601String(),
        'type': msg.type.name, // Save enum as string
        'isGroup': isGroup ? 1 : 0
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getHistory(String chatRoomId) async {
    if (kIsWeb) return []; // EMPTY on Web
    final db = await database;
    if (db == null) return [];
    
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chatRoomId = ?',
      whereArgs: [chatRoomId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      final data = Map<String, dynamic>.from(maps[i]);
      data['timestamp'] = DateTime.parse(data['timestamp']);
      return MessageModel.fromMap(data);
    });
  }

  Future<List<Map<String, dynamic>>> searchGlobal(String query) async {
    if (kIsWeb || query.isEmpty) return [];
    final db = await database;
    if (db == null) return [];

    final List<Map<String, dynamic>> results = await db.query(
      'messages',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    
    return results;
  }

  // --- Personal Tasks Methods ---
  
  Future<void> saveTask(PersonalTask task) async {
    if (kIsWeb) {
      final tasks = await getTasks();
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        tasks[index] = task;
      } else {
        tasks.add(task);
      }
      await _saveTasksWeb(tasks);
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.insert('personal_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PersonalTask>> getTasks() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('personal_tasks') ?? [];
      return list.map((e) => PersonalTask.fromMap(jsonDecode(e))).toList();
    }
    final db = await database;
    if (db == null) return [];
    final maps = await db.query('personal_tasks', orderBy: 'dueDate ASC');
    return maps.map((m) => PersonalTask.fromMap(m)).toList();
  }

  Future<void> deleteTask(String id) async {
    if (kIsWeb) {
      final tasks = await getTasks();
      tasks.removeWhere((t) => t.id == id);
      await _saveTasksWeb(tasks);
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.delete('personal_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTaskStatus(String id, bool isCompleted) async {
    if (kIsWeb) {
      final tasks = await getTasks();
      final index = tasks.indexWhere((t) => t.id == id);
      if (index >= 0) {
        tasks[index] = PersonalTask(
          id: tasks[index].id,
          title: tasks[index].title,
          description: tasks[index].description,
          dueDate: tasks[index].dueDate,
          createdAt: tasks[index].createdAt,
          isCompleted: isCompleted,
        );
        await _saveTasksWeb(tasks);
      }
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.update('personal_tasks', {'isCompleted': isCompleted ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Task Groups ---

  Future<void> saveTaskGroup(TaskGroup group) async {
    if (kIsWeb) {
      final groups = await getTaskGroups();
      groups.add(group);
      await _saveGroupsWeb(groups);
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.insert('task_groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TaskGroup>> getTaskGroups() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('task_groups') ?? [];
      return list.map((e) => TaskGroup.fromMap(jsonDecode(e))).toList();
    }
    final db = await database;
    if (db == null) return [];
    final maps = await db.query('task_groups', orderBy: 'createdAt ASC');
    return maps.map((m) => TaskGroup.fromMap(m)).toList();
  }

  Future<void> deleteTaskGroup(String id) async {
    if (kIsWeb) {
      final groups = await getTaskGroups();
      groups.removeWhere((g) => g.id == id);
      await _saveGroupsWeb(groups);
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.delete('task_groups', where: 'id = ?', whereArgs: [id]);
    // Also delete tasks in this group
    await db.delete('personal_tasks', where: 'groupId = ?', whereArgs: [id]);
  }

  Future<void> _saveGroupsWeb(List<TaskGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final list = groups.map((g) => jsonEncode(g.toMap())).toList();
    await prefs.setStringList('task_groups', list);
  }

  Future<void> _saveTasksWeb(List<PersonalTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tasks.map((t) => jsonEncode(t.toMap())).toList();
    await prefs.setStringList('personal_tasks', list);
  }
}
