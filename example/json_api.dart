#!/usr/bin/env dartrun
//! dart-deps: http="^1.1.0", args="^2.6.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// Fetch and display data from a JSON API
/// Usage: dartrun json_api.dart -- --endpoint users
///        dartrun json_api.dart -- --endpoint posts --id 1

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:args/args.dart';

const baseUrl = 'https://jsonplaceholder.typicode.com';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'endpoint',
      abbr: 'e',
      help: 'API endpoint (users, posts, comments, todos)',
      defaultsTo: 'users',
    )
    ..addOption('id', help: 'Fetch specific item by ID')
    ..addOption('limit', abbr: 'l', help: 'Limit results', defaultsTo: '5')
    ..addFlag('pretty', abbr: 'p', help: 'Pretty print JSON', defaultsTo: true)
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('JSON API Client - Fetch data from JSONPlaceholder API\n');
    print('Usage: dartrun json_api.dart -- [options]\n');
    print(parser.usage);
    print('\nExamples:');
    print('  dartrun json_api.dart -- -e users -l 3');
    print('  dartrun json_api.dart -- -e posts --id 1');
    print('  dartrun json_api.dart -- -e todos -l 10');
    return;
  }

  final endpoint = results['endpoint'] as String;
  final id = results['id'] as String?;
  final limit = int.tryParse(results['limit'] as String) ?? 5;
  final pretty = results['pretty'] as bool;

  final url = id != null
      ? '$baseUrl/$endpoint/$id'
      : '$baseUrl/$endpoint?_limit=$limit';

  print('🌐 Fetching: $url\n');

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print('❌ Error: HTTP ${response.statusCode}');
      return;
    }

    final data = jsonDecode(response.body);

    if (pretty) {
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(data));
    } else {
      print(data);
    }

    if (data is List) {
      print('\n📊 Retrieved ${data.length} items');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
