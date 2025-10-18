// example.dart
//
// A production-grade usage example of the Hivez package.
// For correct setup of Hive CE (adapters, registration, etc.),
// please refer to the README on pub.dev:
// https://pub.dev/packages/hivez
//
// ignore_for_file: avoid_print

import 'package:hivez_flutter/hivez_flutter.dart';

/// Example model
class User {
  final String name;
  final int age;

  User(this.name, this.age);

  @override
  String toString() => 'User(name: $name, age: $age)';
}

Future<void> main() async {
  // Create a typed box for users
  final users = Box<int, User>('users');

  // Add data
  await users.put(1, User('Alice', 24));
  await users.put(2, User('Bob', 30));
  await users.add(User('Charlie', 28)); // auto-increment key

  // Read data
  final alice = await users.get(1);
  print('Alice → $alice');

  final byIndex = await users.getAt(0);
  print('First user in box → $byIndex');

  // Update & move keys
  await users.put(1, User('Alice', 25)); // update Alice
  await users.moveKey(2, 10); // move Bob from key 2 → key 10

  // Delete
  await users.delete(10);

  // Keys & values
  final keys = await users.getAllKeys();
  final values = await users.getAllValues();
  print('Keys: $keys');
  print('Values: $values');

  // Query helpers
  final olderThan25 = await users.getValuesWhere((u) => u.age > 25);
  print('Users older than 25 → $olderThan25');

  final search = await users.firstWhereContains(
    'ali',
    searchableText: (u) => u.name,
  );
  print('Search result → $search');

  // Iteration helpers
  await users.foreachValue((k, v) async {
    print('Iterating → $k: $v');
  });

  // Box info
  print('Total users: ${await users.length}');
  print('Is box empty? ${await users.isEmpty}');

  // Backup / restore
  final backup = await users.generateBackupJson(
    valueToJson: (u) => {'name': u.name, 'age': u.age},
  );
  print('Backup JSON → $backup');

  await users.clear();
  await users.restoreBackupJson(
    backup,
    stringToKey: int.parse,
    jsonToValue: (j) => User(j['name'] as String, j['age'] as int),
  );

  print('Restored values → ${await users.getAllValues()}');

  // Watch for changes
  users.watch(1).listen((event) {
    print('User at key ${event.key} changed → ${event.value}');
  });

  // Trigger a watch event
  await users.put(1, User('Alice', 26));

  // Cleanup
  await users.flushBox();
  await users.closeBox();
}
