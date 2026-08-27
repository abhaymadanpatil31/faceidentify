import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/person_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('faceguardpro.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE persons (
        id $idType,
        name $textType,
        imagePath $textType,
        faceFeatures $textType,
        registeredAt $textType
      )
    ''');
  }

  // Insert a new person
  Future<PersonModel> createPerson(PersonModel person) async {
    final db = await instance.database;
    await db.insert('persons', person.toMap());
    return person;
  }

  // Get person by ID
  Future<PersonModel?> getPersonById(String id) async {
    final db = await instance.database;
    final maps = await db.query('persons', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return PersonModel.fromMap(maps.first);
    }
    return null;
  }

  // Get all persons
  Future<List<PersonModel>> getAllPersons() async {
    final db = await instance.database;
    const orderBy = 'registeredAt DESC';
    final result = await db.query('persons', orderBy: orderBy);

    return result.map((map) => PersonModel.fromMap(map)).toList();
  }

  // Update person
  Future<int> updatePerson(PersonModel person) async {
    final db = await instance.database;
    return db.update(
      'persons',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  // Delete person
  Future<int> deletePerson(String id) async {
    final db = await instance.database;

    // Also delete the image file
    final person = await getPersonById(id);
    if (person != null && person.imagePath.isNotEmpty) {
      try {
        final file = File(person.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting image file: $e');
      }
    }

    return await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  // Search persons by name
  Future<List<PersonModel>> searchPersonsByName(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'persons',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );

    return result.map((map) => PersonModel.fromMap(map)).toList();
  }

  // Get count of registered persons
  Future<int> getPersonsCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM persons');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Close database
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Clear all data (useful for testing)
  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('persons');
  }
}
