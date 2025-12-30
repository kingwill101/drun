#!/usr/bin/env dartrun
//! pubspec:
/// name: shelf_server
/// environment:
///   sdk: ">=3.5.0 <4.0.0"
/// dependencies:
///   shelf: ^1.4.2
///   shelf_router: ^1.1.4
///

/// A simple REST API server using shelf
/// Demonstrates routing, middleware, and JSON responses
///
/// Usage: dartrun shelf_server.dart
/// Then visit: http://localhost:8080

import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// In-memory data store
final List<Map<String, dynamic>> _todos = [
  {'id': 1, 'title': 'Learn Dart', 'completed': true},
  {'id': 2, 'title': 'Build with shelf', 'completed': false},
  {'id': 3, 'title': 'Deploy to production', 'completed': false},
];
int _nextId = 4;

void main() async {
  final router = Router();

  // GET / - Welcome message
  router.get('/', (Request request) {
    return Response.ok(
      jsonEncode({
        'message': 'Welcome to the Shelf Todo API!',
        'endpoints': {
          'GET /todos': 'List all todos',
          'GET /todos/<id>': 'Get a specific todo',
          'POST /todos': 'Create a new todo',
          'PUT /todos/<id>': 'Update a todo',
          'DELETE /todos/<id>': 'Delete a todo',
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  // GET /todos - List all todos
  router.get('/todos', (Request request) {
    return Response.ok(
      jsonEncode({'todos': _todos, 'count': _todos.length}),
      headers: {'content-type': 'application/json'},
    );
  });

  // GET /todos/<id> - Get a specific todo
  router.get('/todos/<id>', (Request request, String id) {
    final todoId = int.tryParse(id);
    if (todoId == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid ID'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final todo = _todos.where((t) => t['id'] == todoId).firstOrNull;
    if (todo == null) {
      return Response.notFound(
        jsonEncode({'error': 'Todo not found'}),
        headers: {'content-type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode(todo),
      headers: {'content-type': 'application/json'},
    );
  });

  // POST /todos - Create a new todo
  router.post('/todos', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (!data.containsKey('title')) {
      return Response(
        400,
        body: jsonEncode({'error': 'Title is required'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final todo = {
      'id': _nextId++,
      'title': data['title'],
      'completed': data['completed'] ?? false,
    };
    _todos.add(todo);

    return Response(
      201,
      body: jsonEncode(todo),
      headers: {'content-type': 'application/json'},
    );
  });

  // PUT /todos/<id> - Update a todo
  router.put('/todos/<id>', (Request request, String id) async {
    final todoId = int.tryParse(id);
    if (todoId == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid ID'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final index = _todos.indexWhere((t) => t['id'] == todoId);
    if (index == -1) {
      return Response.notFound(
        jsonEncode({'error': 'Todo not found'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data.containsKey('title')) {
      _todos[index]['title'] = data['title'];
    }
    if (data.containsKey('completed')) {
      _todos[index]['completed'] = data['completed'];
    }

    return Response.ok(
      jsonEncode(_todos[index]),
      headers: {'content-type': 'application/json'},
    );
  });

  // DELETE /todos/<id> - Delete a todo
  router.delete('/todos/<id>', (Request request, String id) {
    final todoId = int.tryParse(id);
    if (todoId == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid ID'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final index = _todos.indexWhere((t) => t['id'] == todoId);
    if (index == -1) {
      return Response.notFound(
        jsonEncode({'error': 'Todo not found'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final removed = _todos.removeAt(index);
    return Response.ok(
      jsonEncode({'message': 'Deleted', 'todo': removed}),
      headers: {'content-type': 'application/json'},
    );
  });

  // Add middleware for logging and CORS
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);

  print(
    '🚀 Shelf server running at http://${server.address.host}:${server.port}',
  );
  print('');
  print('Try these commands:');
  print('  curl http://localhost:8080/');
  print('  curl http://localhost:8080/todos');
  print('  curl http://localhost:8080/todos/1');
  print(
    '  curl -X POST -H "Content-Type: application/json" -d \'{"title":"New task"}\' http://localhost:8080/todos',
  );
  print(
    '  curl -X PUT -H "Content-Type: application/json" -d \'{"completed":true}\' http://localhost:8080/todos/1',
  );
  print('  curl -X DELETE http://localhost:8080/todos/1');
  print('');
  print('Press Ctrl+C to stop the server');
}

/// CORS middleware for cross-origin requests
Middleware _corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }

      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
};
