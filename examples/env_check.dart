#!/usr/bin/env drun
//! dart-deps: args="^2.6.0", path="^1.9.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// Development environment checker - verify tools and configurations
/// Usage: drun env_check.dart
///        drun env_check.dart -- --verbose

import 'dart:io';
import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('verbose', abbr: 'v', help: 'Show detailed output')
    ..addFlag('json', help: 'Output as JSON')
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('''
🔧 Environment Checker - Verify your development setup

Usage: drun env_check.dart -- [options]

Options:
${parser.usage}

Checks:
  - Dart SDK version and path
  - Flutter SDK (if installed)
  - Git version
  - Common development tools
  - Environment variables
  - Shell configuration
''');
    return;
  }

  final verbose = results['verbose'] as bool;
  final checks = <String, Map<String, dynamic>>{};

  print('🔧 Development Environment Check\n');
  print('=' * 50);

  // System info
  print('\n📱 System:');
  print(
      '   OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  print('   Arch: ${_getArch()}');
  print('   Locale: ${Platform.localeName}');

  // Dart
  print('\n🎯 Dart:');
  final dartVersion = await _checkCommand('dart', ['--version']);
  checks['dart'] = dartVersion;
  _printCheck('Dart SDK', dartVersion, verbose);

  // Flutter
  print('\n💙 Flutter:');
  final flutterVersion = await _checkCommand('flutter', ['--version']);
  checks['flutter'] = flutterVersion;
  _printCheck('Flutter SDK', flutterVersion, verbose);

  // Git
  print('\n📚 Git:');
  final gitVersion = await _checkCommand('git', ['--version']);
  checks['git'] = gitVersion;
  _printCheck('Git', gitVersion, verbose);

  if (gitVersion['installed'] == true) {
    final gitUser =
        await _runCommand('git', ['config', '--global', 'user.name']);
    final gitEmail =
        await _runCommand('git', ['config', '--global', 'user.email']);
    print(
        '   User: ${gitUser.trim().isNotEmpty ? gitUser.trim() : '(not set)'}');
    print(
        '   Email: ${gitEmail.trim().isNotEmpty ? gitEmail.trim() : '(not set)'}');
  }

  // Other tools
  print('\n🛠️  Development Tools:');

  final tools = [
    ('node', ['--version'], 'Node.js'),
    ('npm', ['--version'], 'npm'),
    ('python3', ['--version'], 'Python'),
    ('docker', ['--version'], 'Docker'),
    ('code', ['--version'], 'VS Code'),
    ('nvim', ['--version'], 'Neovim'),
  ];

  for (final (cmd, args, name) in tools) {
    final check = await _checkCommand(cmd, args);
    checks[cmd] = check;
    _printCheck(name, check, verbose);
  }

  // Environment variables
  print('\n🌍 Environment:');
  final envVars = [
    'PATH',
    'HOME',
    'SHELL',
    'EDITOR',
    'DART_SDK',
    'FLUTTER_ROOT'
  ];
  for (final varName in envVars) {
    final value = Platform.environment[varName];
    if (value != null) {
      final display =
          value.length > 50 ? '${value.substring(0, 47)}...' : value;
      print('   $varName: $display');
    } else if (verbose) {
      print('   $varName: (not set)');
    }
  }

  // Shell
  print('\n🐚 Shell:');
  final shell = Platform.environment['SHELL'] ?? 'unknown';
  print('   Current: $shell');

  // Check for common shell configs
  final homeDir = Platform.environment['HOME'] ?? '.';
  final configs = ['.bashrc', '.zshrc', '.config/fish/config.fish'];
  for (final config in configs) {
    final file = File('$homeDir/$config');
    if (file.existsSync()) {
      print('   Config: ~/$config ✅');
    }
  }

  // Summary
  print('\n' + '=' * 50);
  final installed = checks.values.where((c) => c['installed'] == true).length;
  final total = checks.length;
  print('📊 Summary: $installed/$total tools available');

  final missing = checks.entries
      .where((e) => e.value['installed'] != true)
      .map((e) => e.key)
      .toList();

  if (missing.isNotEmpty) {
    print('❌ Missing: ${missing.join(', ')}');
  } else {
    print('✅ All checked tools are installed!');
  }
}

Future<Map<String, dynamic>> _checkCommand(
    String command, List<String> args) async {
  try {
    final result = await Process.run(command, args);
    if (result.exitCode == 0) {
      final output =
          (result.stdout.toString() + result.stderr.toString()).trim();
      final version = _extractVersion(output);
      return {
        'installed': true,
        'version': version,
        'output': output,
      };
    }
    return {'installed': false, 'error': 'Non-zero exit code'};
  } catch (e) {
    return {'installed': false, 'error': e.toString()};
  }
}

Future<String> _runCommand(String command, List<String> args) async {
  try {
    final result = await Process.run(command, args);
    return result.stdout.toString();
  } catch (_) {
    return '';
  }
}

String _extractVersion(String output) {
  // Try to extract version number from output
  final patterns = [
    RegExp(r'(\d+\.\d+\.\d+[-\w.]*)'),
    RegExp(r'version (\S+)'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(output);
    if (match != null) return match.group(1)!;
  }

  return output.split('\n').first.trim();
}

void _printCheck(String name, Map<String, dynamic> check, bool verbose) {
  final installed = check['installed'] == true;
  final icon = installed ? '✅' : '❌';
  final version = check['version'] ?? 'not installed';

  print('   $icon ${name.padRight(12)} $version');

  if (verbose && check['output'] != null) {
    final lines = check['output'].toString().split('\n');
    if (lines.length > 1) {
      for (final line in lines.skip(1).take(3)) {
        print('      $line');
      }
    }
  }
}

String _getArch() {
  // Detect architecture from uname or sysctl on supported platforms
  try {
    if (Platform.isLinux || Platform.isMacOS) {
      final result = Process.runSync('uname', ['-m']);
      return result.stdout.toString().trim();
    }
  } catch (_) {}
  return 'unknown';
}
