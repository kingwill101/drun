import 'dart:io';
import 'package:path/path.dart' as path;

/// Manages running Dart scripts and AOT compilation
class ScriptRunner {
  final String workingDirectory;

  ScriptRunner(this.workingDirectory);

  /// Run a Dart script using 'dart run'
  Future<RunResult> runScript({
    List<String> args = const [],
    bool verbose = false,
  }) async {
    final mainDart = path.join(workingDirectory, 'bin', 'main.dart');
    if (!File(mainDart).existsSync()) {
      return RunResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Script file not found: $mainDart',
        success: false,
      );
    }

    final dartArgs = ['run', 'bin/main.dart'];
    if (args.isNotEmpty) {
      dartArgs.add('--');
      dartArgs.addAll(args);
    }

    if (verbose) {
      print('Running: dart ${dartArgs.join(' ')}');
      print('Working directory: $workingDirectory');
    }

    final result = await Process.run(
      'dart',
      dartArgs,
      workingDirectory: workingDirectory,
    );

    return RunResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
      success: result.exitCode == 0,
    );
  }

  /// Compile script to AOT snapshot
  Future<CompileResult> compileAot(
    String outputPath, {
    bool verbose = false,
  }) async {
    final mainDart = path.join(workingDirectory, 'bin', 'main.dart');
    if (!File(mainDart).existsSync()) {
      return CompileResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Script file not found: $mainDart',
        success: false,
        outputPath: outputPath,
      );
    }

    // Ensure output directory exists
    final outputDir = Directory(path.dirname(outputPath));
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final compileArgs = [
      'compile',
      Platform.isWindows ? 'exe' : 'aot-snapshot',
      mainDart,
      '-o',
      outputPath,
    ];

    if (verbose) {
      print('Compiling: dart ${compileArgs.join(' ')}');
      print('Working directory: $workingDirectory');
    }

    final result = await Process.run(
      'dart',
      compileArgs,
      workingDirectory: workingDirectory,
    );

    return CompileResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
      success: result.exitCode == 0,
      outputPath: outputPath,
    );
  }

  /// Run AOT compiled artifact
  Future<RunResult> runAot(
    String aotPath, {
    List<String> args = const [],
    bool verbose = false,
  }) async {
    if (!File(aotPath).existsSync()) {
      return RunResult(
        exitCode: 1,
        stdout: '',
        stderr: 'AOT artifact not found: $aotPath',
        success: false,
      );
    }

    List<String> runCommand;
    List<String> runArgs;

    if (Platform.isWindows || aotPath.endsWith('.exe')) {
      // Native executable
      runCommand = [aotPath];
      runArgs = args;
    } else {
      // AOT snapshot - needs dartaotruntime to run
      runCommand = ['dartaotruntime'];
      runArgs = [aotPath, ...args];
    }

    if (verbose) {
      print('Running AOT: ${runCommand.join(' ')} ${runArgs.join(' ')}');
    }

    Process process;
    if (runCommand.length == 1) {
      process = await Process.start(runCommand.first, runArgs);
    } else {
      process = await Process.start(runCommand.first, [
        ...runCommand.skip(1),
        ...runArgs,
      ]);
    }

    final stdout = StringBuffer();
    final stderr = StringBuffer();

    process.stdout.transform(systemEncoding.decoder).forEach((data) {
      stdout.write(data);
      if (verbose) print(data);
    });

    process.stderr.transform(systemEncoding.decoder).forEach((data) {
      stderr.write(data);
      if (verbose) print(data);
    });

    final exitCode = await process.exitCode;

    return RunResult(
      exitCode: exitCode,
      stdout: stdout.toString(),
      stderr: stderr.toString(),
      success: exitCode == 0,
    );
  }

  /// Check if the working directory has a valid Dart package structure
  bool isValidPackage() {
    final pubspec = File(path.join(workingDirectory, 'pubspec.yaml'));
    final mainDart = File(path.join(workingDirectory, 'bin', 'main.dart'));

    return pubspec.existsSync() && mainDart.existsSync();
  }

  /// Get executable name from pubspec or use default
  String getExecutableName() {
    final pubspec = File(path.join(workingDirectory, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return 'main';

    try {
      final content = pubspec.readAsStringSync();
      final lines = content.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('name:')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            return parts[1].trim().replaceAll(RegExp(r'''["' ]'''), '');
          }
        }
      }
    } catch (e) {
      // Fall back to default if parsing fails
    }

    return 'main';
  }
}

/// Result of running a script
class RunResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool success;

  RunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.success,
  });

  String get output => stdout.isNotEmpty ? stdout : stderr;

  @override
  String toString() {
    return 'RunResult(exitCode: $exitCode, success: $success)';
  }
}

/// Result of compiling a script
class CompileResult extends RunResult {
  final String outputPath;

  CompileResult({
    required super.exitCode,
    required super.stdout,
    required super.stderr,
    required super.success,
    required this.outputPath,
  });

  bool get artifactExists => File(outputPath).existsSync();

  @override
  String toString() {
    return 'CompileResult(exitCode: $exitCode, success: $success, outputPath: $outputPath)';
  }
}
