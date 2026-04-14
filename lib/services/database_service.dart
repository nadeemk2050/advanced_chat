import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_models.dart';

class LocalDatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE messages(
      id TEXT PRIMARY KEY,
      senderId TEXT,
      text TEXT,
      type INTEGER,
      timestamp INTEGER,
      status INTEGER,
      mediaUrl TEXT
    )
    ''');
  }

  Future<void> saveMessage(MessageModel message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getLocalMessages() async {
    final db = await database;
    final result = await db.query('messages', orderBy: 'timestamp DESC');
    return result.map((json) => MessageModel.fromMap(json)).toList();
  }
}
