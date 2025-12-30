import 'dart:io';
import 'package:path/path.dart' as path;

/// Manages Dart pub operations and SDK detection
class PubManager {
  
  /// Get the current Dart SDK version
  static Future<String> getDartSdkVersion() async {
    final result = await Process.run('dart', ['--version']);
    if (result.exitCode != 0) {
      throw StateError('Failed to get Dart SDK version: ${result.stderr}');
    }
    
    // Parse version from output like "Dart SDK version: 3.5.0 (stable)"
    final output = (result.stdout as String).isNotEmpty 
        ? result.stdout as String 
        : result.stderr as String;
    final versionMatch = RegExp(r'Dart SDK version: (\S+)').firstMatch(output);
    if (versionMatch == null) {
      throw StateError('Could not parse Dart SDK version from: $output');
    }
    
    return versionMatch.group(1)!;
  }
  
  /// Run 'dart pub get' in the specified directory
  static Future<PubResult> pubGet(String workingDirectory, {bool offline = false}) async {
    final args = ['pub', 'get'];
    if (offline) args.add('--offline');
    
    final result = await Process.run(
      'dart', 
      args,
      workingDirectory: workingDirectory,
    );
    
    return PubResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
      success: result.exitCode == 0,
    );
  }
  
  /// Run 'dart pub upgrade' in the specified directory  
  static Future<PubResult> pubUpgrade(String workingDirectory) async {
    final result = await Process.run(
      'dart',
      ['pub', 'upgrade'],
      workingDirectory: workingDirectory,
    );
    
    return PubResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,  
      stderr: result.stderr as String,
      success: result.exitCode == 0,
    );
  }
  
  /// Check if dart command is available
  static Future<bool> isDartAvailable() async {
    try {
      final result = await Process.run('dart', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate that a pubspec.yaml file is syntactically correct
  static bool validatePubspec(String pubspecContent) {
    try {
      // Write to temp file and try to parse with dart pub
      final tempDir = Directory.systemTemp.createTempSync('drun_validate');
      final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspecFile.writeAsStringSync(pubspecContent);
      
      // Create minimal lib structure that pub expects
      Directory(path.join(tempDir.path, 'lib')).createSync();
      
      final result = Process.runSync(
        'dart',
        ['pub', 'deps'],
        workingDirectory: tempDir.path,
      );
      
      tempDir.deleteSync(recursive: true);
      
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Get detailed info about available packages (for debugging)
  static Future<String> pubDeps(String workingDirectory) async {
    final result = await Process.run(
      'dart',
      ['pub', 'deps'],
      workingDirectory: workingDirectory,
    );
    
    if (result.exitCode != 0) {
      throw StateError('Failed to get pub deps: ${result.stderr}');
    }
    
    return result.stdout as String;
  }
  
  /// Check if pubspec.lock exists and is not stale
  static bool isPubspecLockValid(String workingDirectory) {
    final pubspecFile = File(path.join(workingDirectory, 'pubspec.yaml'));
    final lockFile = File(path.join(workingDirectory, 'pubspec.lock'));
    
    if (!pubspecFile.existsSync() || !lockFile.existsSync()) {
      return false;
    }
    
    // Check if lock file is newer than pubspec.yaml
    final pubspecModified = pubspecFile.lastModifiedSync();
    final lockModified = lockFile.lastModifiedSync();
    
    return lockModified.isAfter(pubspecModified);
  }
  
  /// Setup a new Dart package in the specified directory
  static Future<PubResult> setupPackage(String workingDirectory, String pubspecContent) async {
    final directory = Directory(workingDirectory);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    
    // Write pubspec.yaml
    final pubspecFile = File(path.join(workingDirectory, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync(pubspecContent);
    
    // Create basic directory structure
    Directory(path.join(workingDirectory, 'lib')).createSync();
    Directory(path.join(workingDirectory, 'bin')).createSync();
    
    // Run pub get
    return await pubGet(workingDirectory);
  }
  
  /// Extract package name from pubspec content
  static String? extractPackageName(String pubspecContent) {
    final lines = pubspecContent.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('name:')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          return parts[1].trim().replaceAll(RegExp(r'["\'']'), '');
        }
      }
    }
    return null;
  }
}

/// Result of a pub operation
class PubResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool success;
  
  PubResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.success,
  });
  
  String get output => stdout.isNotEmpty ? stdout : stderr;
  
  @override
  String toString() {
    return 'PubResult(exitCode: $exitCode, success: $success)';
  }
}