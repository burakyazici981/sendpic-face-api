import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'sendpic.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        gender TEXT,
        age INTEGER,
        bio TEXT,
        profile_image_url TEXT,
        is_verified INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Contents table
    await db.execute('''
      CREATE TABLE contents (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        media_url TEXT NOT NULL,
        media_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Content recipients table
    await db.execute('''
      CREATE TABLE content_recipients (
        id TEXT PRIMARY KEY,
        content_id TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        is_liked INTEGER DEFAULT 0,
        friend_requested INTEGER DEFAULT 0,
        received_at TEXT NOT NULL,
        FOREIGN KEY (content_id) REFERENCES contents (id) ON DELETE CASCADE,
        FOREIGN KEY (recipient_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tokens table
    await db.execute('''
      CREATE TABLE tokens (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Friendships table
    await db.execute('''
      CREATE TABLE friendships (
        id TEXT PRIMARY KEY,
        requester_id TEXT NOT NULL,
        addressee_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (requester_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (addressee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        media_url TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (receiver_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Verifications table
    await db.execute('''
      CREATE TABLE verifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        verification_type TEXT NOT NULL,
        document_url TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        verified_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_contents_sender_id ON contents(sender_id)');
    await db.execute('CREATE INDEX idx_content_recipients_recipient_id ON content_recipients(recipient_id)');
    await db.execute('CREATE INDEX idx_tokens_user_id ON tokens(user_id)');
    await db.execute('CREATE INDEX idx_friendships_requester_id ON friendships(requester_id)');
    await db.execute('CREATE INDEX idx_friendships_addressee_id ON friendships(addressee_id)');
    await db.execute('CREATE INDEX idx_messages_sender_id ON messages(sender_id)');
    await db.execute('CREATE INDEX idx_messages_receiver_id ON messages(receiver_id)');
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  // Transaction support
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
