#!/usr/bin/env dartrun
//! dart-deps: http="^1.1.0", args="^2.6.0"

import 'package:http/http.dart' as http;
import 'package:args/args.dart';

/// Example demonstrating dartrun usage with embedded dependencies.
///
/// This script shows how to use dartrun to run Dart scripts with dependencies
/// without needing a separate pubspec.yaml file.
///
/// Usage:
///   dartrun example.dart
///   dartrun example.dart -- https://api.github.com/users/dart-lang
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'url',
      abbr: 'u',
      defaultsTo: 'https://api.github.com/zen',
      help: 'URL to fetch',
    );

  final results = parser.parse(arguments);
  final url = results['url'] as String;

  print('Fetching: $url');

  try {
    final response = await http.get(Uri.parse(url));
    print('Status: ${response.statusCode}');
    print('Response:\n${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
