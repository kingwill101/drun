#!/usr/bin/env dartrun
//! dart-deps:
//! dart-sdk: ">=3.5.0 <4.0.0"

void main(List<String> args) {
  final name = args.isNotEmpty ? args.first : 'World';
  print('Hello, $name!');
  print('Arguments received: ${args.length}');

  if (args.length > 1) {
    print('All args: ${args.join(', ')}');
  }
}
