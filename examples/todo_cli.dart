#!/usr/bin/env drun
//! pubspec:
/// name: todo_cli
/// environment:
///   sdk: ">=3.5.0 <4.0.0"
/// dependencies:
///   args: ^2.6.0
///   path: ^1.9.0
///

/// A simple todo list manager with file persistence
/// Usage: drun todo_cli.dart -- add "Buy groceries"
///        drun todo_cli.dart -- list
///        drun todo_cli.dart -- done 1

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

final todoFile = p.join(
  Platform.environment['HOME'] ?? '.',
  '.drun_todos.json',
);

void main(List<String> args) {
  final parser = ArgParser()
    ..addCommand('add')
    ..addCommand('list')
    ..addCommand('done')
    ..addCommand('remove')
    ..addCommand('clear')
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool || results.command == null) {
    _printUsage();
    return;
  }

  final todos = _loadTodos();

  switch (results.command!.name) {
    case 'add':
      _addTodo(todos, results.command!.rest.join(' '));
    case 'list':
      _listTodos(todos);
    case 'done':
      _markDone(todos, results.command!.rest.firstOrNull);
    case 'remove':
      _removeTodo(todos, results.command!.rest.firstOrNull);
    case 'clear':
      _clearTodos(todos);
    default:
      _printUsage();
  }
}

void _printUsage() {
  print('''
📝 Todo CLI - A simple todo list manager

Usage: drun todo_cli.dart -- <command> [arguments]

Commands:
  add <task>     Add a new todo item
  list           Show all todos
  done <id>      Mark a todo as complete
  remove <id>    Remove a todo item
  clear          Remove all completed todos

Examples:
  drun todo_cli.dart -- add "Buy groceries"
  drun todo_cli.dart -- list
  drun todo_cli.dart -- done 1
  drun todo_cli.dart -- clear
''');
}

List<Map<String, dynamic>> _loadTodos() {
  final file = File(todoFile);
  if (!file.existsSync()) return [];
  
  try {
    final content = file.readAsStringSync();
    return List<Map<String, dynamic>>.from(jsonDecode(content));
  } catch (_) {
    return [];
  }
}

void _saveTodos(List<Map<String, dynamic>> todos) {
  final file = File(todoFile);
  file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(todos));
}

void _addTodo(List<Map<String, dynamic>> todos, String task) {
  if (task.trim().isEmpty) {
    print('❌ Please provide a task description');
    return;
  }

  todos.add({
    'id': todos.isEmpty ? 1 : (todos.map((t) => t['id'] as int).reduce((a, b) => a > b ? a : b) + 1),
    'task': task.trim(),
    'done': false,
    'created': DateTime.now().toIso8601String(),
  });
  
  _saveTodos(todos);
  print('✅ Added: "$task"');
}

void _listTodos(List<Map<String, dynamic>> todos) {
  if (todos.isEmpty) {
    print('📭 No todos yet! Add one with: drun todo_cli.dart -- add "Your task"');
    return;
  }

  print('📝 Your Todos:\n');
  
  final pending = todos.where((t) => t['done'] != true).toList();
  final completed = todos.where((t) => t['done'] == true).toList();

  if (pending.isNotEmpty) {
    print('⏳ Pending:');
    for (final todo in pending) {
      print('   [${todo['id']}] ${todo['task']}');
    }
  }

  if (completed.isNotEmpty) {
    print('\n✅ Completed:');
    for (final todo in completed) {
      print('   [${todo['id']}] ${todo['task']}');
    }
  }

  print('\n📊 ${pending.length} pending, ${completed.length} completed');
}

void _markDone(List<Map<String, dynamic>> todos, String? idStr) {
  final id = int.tryParse(idStr ?? '');
  if (id == null) {
    print('❌ Please provide a valid todo ID');
    return;
  }

  final todo = todos.where((t) => t['id'] == id).firstOrNull;
  if (todo == null) {
    print('❌ Todo #$id not found');
    return;
  }

  todo['done'] = true;
  todo['completed'] = DateTime.now().toIso8601String();
  _saveTodos(todos);
  print('✅ Marked as done: "${todo['task']}"');
}

void _removeTodo(List<Map<String, dynamic>> todos, String? idStr) {
  final id = int.tryParse(idStr ?? '');
  if (id == null) {
    print('❌ Please provide a valid todo ID');
    return;
  }

  final index = todos.indexWhere((t) => t['id'] == id);
  if (index == -1) {
    print('❌ Todo #$id not found');
    return;
  }

  final removed = todos.removeAt(index);
  _saveTodos(todos);
  print('🗑️  Removed: "${removed['task']}"');
}

void _clearTodos(List<Map<String, dynamic>> todos) {
  final completed = todos.where((t) => t['done'] == true).length;
  todos.removeWhere((t) => t['done'] == true);
  _saveTodos(todos);
  print('🧹 Cleared $completed completed todos');
}
