#!/usr/bin/env drun
//! dart-deps: http="^1.1.0"

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args.first : 'https://api.github.com/zen';

  print('Fetching: $url');

  try {
    final response = await http.get(Uri.parse(url));
    print('Status: ${response.statusCode}');
    print('Response: ${response.body.trim()}');
  } catch (e) {
    print('Error: $e');
  }
}
