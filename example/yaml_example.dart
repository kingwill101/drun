#!/usr/bin/env dartrun
//! pubspec:
/// name: yaml_demo
/// environment:
///   sdk: ">=3.5.0 <4.0.0"
/// dependencies:
///   yaml: ^3.1.2
///   args: ^2.6.0

import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('file', abbr: 'f', help: 'YAML file to parse')
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(arguments);

  if (results['help'] as bool || results['file'] == null) {
    print('Usage: yaml_demo -f <file.yaml>');
    print(parser.usage);
    return;
  }

  final yamlContent = '''
name: example
version: 1.0.0
dependencies:
  - http
  - args
config:
  debug: true
  port: 8080
''';

  try {
    final doc = loadYaml(yamlContent);
    print('Parsed YAML:');
    print('Name: ${doc['name']}');
    print('Version: ${doc['version']}');
    print('Dependencies: ${doc['dependencies']}');
    print('Debug mode: ${doc['config']['debug']}');
    print('Port: ${doc['config']['port']}');
  } catch (e) {
    print('Error parsing YAML: $e');
  }
}
