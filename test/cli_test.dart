import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('drun CLI', () {
    late Directory tempDir;
    late Directory cacheDir;
    late String packageRoot;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drun_cli_test_');
      cacheDir = Directory(path.join(tempDir.path, 'cache'));
      packageRoot = Directory.current.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<ProcessResult> runDrun(List<String> args) {
      final dartExe = Platform.resolvedExecutable;
      final drunPath = path.join(packageRoot, 'bin', 'drun.dart');
      return Process.run(
        dartExe,
        ['run', drunPath, ...args],
        workingDirectory: packageRoot,
        environment: {
          ...Platform.environment,
          'PUB_CACHE': path.join(tempDir.path, 'pub-cache'),
        },
      );
    }

    String writeScript(String name, List<String> lines) {
      final scriptPath = path.join(tempDir.path, name);
      File(scriptPath).writeAsStringSync(lines.join('\n'));
      return scriptPath;
    }

    String combinedOutput(ProcessResult result) {
      return '${result.stdout}${result.stderr}';
    }

    test('runs script directly with args', () async {
      final scriptPath = writeScript('hello.dart', [
        '#!/usr/bin/env drun',
        '//! dart-deps:',
        '//! dart-sdk: ">=3.5.0 <4.0.0"',
        '',
        'void main(List<String> args) {',
        "  final output = args.isEmpty ? 'no-args' : args.join(',');",
        r"  print('args=$output');",
        '}',
        '',
      ]);

      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        '--offline',
        scriptPath,
        '--',
        'one',
        'two',
      ]);

      expect(result.exitCode, 0);
      expect(combinedOutput(result), contains('args=one,two'));
    });

    test('runs script via run command', () async {
      final scriptPath = writeScript('hello_run.dart', [
        '#!/usr/bin/env drun',
        '//! dart-deps:',
        '//! dart-sdk: ">=3.5.0 <4.0.0"',
        '',
        'void main(List<String> args) {',
        r"  print('args=${args.join(',')}');",
        '}',
        '',
      ]);

      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        '--offline',
        'run',
        scriptPath,
        '--',
        'alpha',
      ]);

      expect(result.exitCode, 0);
      expect(combinedOutput(result), contains('args=alpha'));
    });

    test('prints generated pubspec', () async {
      final scriptPath = writeScript('print_pubspec.dart', [
        '#!/usr/bin/env drun',
        '//! dart-deps: http="^1.2.2", args="^2.6.0"',
        '//! dart-sdk: ">=3.5.0 <4.0.0"',
        '',
        'void main(List<String> args) {',
        "  print('should-not-run');",
        '}',
        '',
      ]);

      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        '--print-pubspec',
        scriptPath,
      ]);

      expect(result.exitCode, 0);
      final output = combinedOutput(result);
      expect(output, contains('name: drun_script'));
      expect(output, contains('sdk: ">=3.5.0 <4.0.0"'));
      expect(output, contains('http: ^1.2.2'));
      expect(output, contains('args: ^2.6.0'));
    });

    test('hash shows cache details', () async {
      final scriptPath = writeScript('hash_me.dart', [
        '#!/usr/bin/env drun',
        '//! dart-deps:',
        '',
        'void main(List<String> args) {}',
        '',
      ]);

      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        'hash',
        scriptPath,
      ]);

      expect(result.exitCode, 0);
      final output = combinedOutput(result);
      expect(output, contains('Cache key (package):'));
      expect(output, contains('Cache key (AOT):'));
      expect(output, contains('Package dir:'));
    });

    test('clean --all removes cache directory', () async {
      cacheDir.createSync(recursive: true);
      File(path.join(cacheDir.path, 'marker.txt')).writeAsStringSync('x');

      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        'clean',
        '--all',
      ]);

      expect(result.exitCode, 0);
      expect(cacheDir.existsSync(), isFalse);
      expect(combinedOutput(result), contains('Cache cleared'));
    });

    test('fails when script file is missing', () async {
      final missingPath = path.join(tempDir.path, 'missing.dart');
      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        missingPath,
      ]);

      expect(result.exitCode, isNot(0));
      expect(combinedOutput(result), contains('Script file not found'));
    });

    test('fails when frozen and cache is missing', () async {
      final scriptPath = writeScript('frozen.dart', [
        '#!/usr/bin/env drun',
        '//! dart-deps:',
        '',
        'void main(List<String> args) {',
        "  print('never runs');",
        '}',
        '',
      ]);

      final result = await runDrun([
        '--cache-dir',
        cacheDir.path,
        '--frozen',
        scriptPath,
      ]);

      expect(result.exitCode, isNot(0));
      expect(
        combinedOutput(result),
        contains('No cached package found and --frozen specified'),
      );
    });
  });
}
