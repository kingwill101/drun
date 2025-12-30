import 'package:test/test.dart';
import 'package:dartrun/src/header.dart';
import 'package:dartrun/src/cache.dart';

void main() {
  group('HeaderParser', () {
    test('parses inline dependencies', () {
      final lines = [
        '#!/usr/bin/env drun',
        '//! dart-deps: http="^1.2.2", args="^2.6.0"',
        '//! dart-sdk: ">=3.5.0 <4.0.0"',
        '',
        'void main() { print("hello"); }',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.isFullManifest, false);
      expect(header.dependencies, {
        'http': '^1.2.2',
        'args': '^2.6.0',
      });
      expect(header.sdkConstraint, '>=3.5.0 <4.0.0');
    });

    test('parses pubspec block', () {
      final lines = [
        '#!/usr/bin/env drun',
        '//! pubspec:',
        '/// name: test_script',
        '/// environment:',
        '///   sdk: ">=3.5.0 <4.0.0"',
        '/// dependencies:',
        '///   yaml: ^3.1.2',
        '',
        'void main() {}',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.isFullManifest, true);
      expect(header.pubspecYaml, contains('name: test_script'));
      expect(header.pubspecYaml, contains('yaml: ^3.1.2'));
    });

    test('pubspec block stops at empty /// line', () {
      final lines = [
        '#!/usr/bin/env drun',
        '//! pubspec:',
        '/// name: test_script',
        '/// environment:',
        '///   sdk: ">=3.5.0 <4.0.0"',
        '/// dependencies:',
        '///   http: ^1.2.2',
        '///', // Empty /// line should end the pubspec block
        '/// This is a doc comment that should NOT be in pubspec',
        '/// Another doc comment',
        '',
        'void main() {}',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.isFullManifest, true);
      expect(header.pubspecYaml, contains('name: test_script'));
      expect(header.pubspecYaml, contains('http: ^1.2.2'));
      expect(header.pubspecYaml, isNot(contains('doc comment')));
      expect(header.pubspecYaml, isNot(contains('should NOT')));
    });

    test('pubspec block stops at blank line', () {
      final lines = [
        '#!/usr/bin/env drun',
        '//! pubspec:',
        '/// name: test_script',
        '/// dependencies:',
        '///   yaml: ^3.1.2',
        '', // Blank line should end the pubspec block
        '/// Doc comment after blank line',
        'void main() {}',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.isFullManifest, true);
      expect(header.pubspecYaml, contains('name: test_script'));
      expect(header.pubspecYaml, isNot(contains('Doc comment')));
    });

    test('pubspec block with complex dependencies', () {
      final lines = [
        '#!/usr/bin/env drun',
        '//! pubspec:',
        '/// name: complex_script',
        '/// environment:',
        '///   sdk: ">=3.5.0 <4.0.0"',
        '/// dependencies:',
        '///   http: ^1.2.2',
        '///   args: ^2.6.0',
        '///   yaml: ^3.1.2',
        '///   path: ^1.9.0',
        '///',
        '',
        '/// Script documentation',
        'void main() {}',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.isFullManifest, true);
      expect(header.pubspecYaml, contains('http: ^1.2.2'));
      expect(header.pubspecYaml, contains('args: ^2.6.0'));
      expect(header.pubspecYaml, contains('yaml: ^3.1.2'));
      expect(header.pubspecYaml, contains('path: ^1.9.0'));
      expect(header.pubspecYaml, isNot(contains('Script documentation')));
    });

    test('handles empty dependencies', () {
      final lines = [
        '#!/usr/bin/env drun',
        'void main() { print("hello"); }',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.isFullManifest, false);
      expect(header.dependencies, isEmpty);
      expect(header.sdkConstraint, isNull);
    });

    test('stops parsing at non-comment line', () {
      final lines = [
        '//! dart-deps: http="^1.2.2"',
        'import "dart:io";', // Non-comment line
        '//! dart-deps: args="^2.6.0"', // Should be ignored
        'void main() {}',
      ];

      final header = HeaderParser.parseLines(lines);

      expect(header.dependencies, {'http': '^1.2.2'});
      expect(header.dependencies.containsKey('args'), false);
    });
  });

  group('CacheManager', () {
    test('generates consistent cache keys', () {
      final manager = CacheManager(cacheDir: '/tmp/test');

      final key1 = manager.generateCacheKey(
          'pubspec content', 'dart 3.5.0', 'script content');
      final key2 = manager.generateCacheKey(
          'pubspec content', 'dart 3.5.0', 'script content');

      expect(key1, equals(key2));
    });

    test('generates different keys for different inputs', () {
      final manager = CacheManager(cacheDir: '/tmp/test');

      final key1 = manager.generateCacheKey('pubspec1', 'dart 3.5.0', 'script');
      final key2 = manager.generateCacheKey('pubspec2', 'dart 3.5.0', 'script');

      expect(key1, isNot(equals(key2)));
    });

    test('includes architecture when requested', () {
      final manager = CacheManager(cacheDir: '/tmp/test');

      final key1 = manager.generateCacheKey('pubspec', 'dart 3.5.0', 'script',
          includeArch: false);
      final key2 = manager.generateCacheKey('pubspec', 'dart 3.5.0', 'script',
          includeArch: true);

      expect(key1, isNot(equals(key2)));
    });
  });

  group('ScriptHeader', () {
    test('generates valid pubspec for inline deps', () {
      final header = ScriptHeader(
        dependencies: {'http': '^1.2.2', 'args': '^2.6.0'},
        sdkConstraint: '>=3.5.0 <4.0.0',
        isFullManifest: false,
      );

      final pubspec = header.generatePubspecYaml();

      expect(pubspec, contains('name: drun_script'));
      expect(pubspec, contains('sdk: ">=3.5.0 <4.0.0"'));
      expect(pubspec, contains('http: ^1.2.2'));
      expect(pubspec, contains('args: ^2.6.0'));
    });

    test('uses full manifest when available', () {
      const customPubspec = '''
name: custom_script
description: Custom script
environment:
  sdk: ">=3.4.0 <4.0.0"
dependencies:
  yaml: ^3.1.2
''';

      final header = ScriptHeader(
        dependencies: {},
        pubspecYaml: customPubspec,
        isFullManifest: true,
      );

      final generated = header.generatePubspecYaml();
      expect(generated, equals(customPubspec));
    });
  });
}
