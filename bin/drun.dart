import 'dart:io';
import 'package:artisanal/args.dart';
import 'package:artisanal/artisanal.dart' show Verbosity;
import 'package:dartrun/src/header.dart';
import 'package:dartrun/src/cache.dart';
import 'package:dartrun/src/pub.dart';
import 'package:dartrun/src/run.dart';

Future<void> main(List<String> arguments) async {
  final runner = DrunCommandRunner();
  await runner.run(arguments);
}

/// Custom command runner that supports running scripts directly without 'run' subcommand
class DrunCommandRunner extends CommandRunner<void> {
  DrunCommandRunner() : super('drun', 'Script runner for Dart') {
    // Add drun-specific global options (verbose is already provided by artisanal)
    argParser
      ..addFlag('offline', help: 'Run pub get in offline mode')
      ..addFlag(
        'refresh',
        abbr: 'U',
        help: 'Refresh cache and re-resolve dependencies',
      )
      ..addFlag(
        'aot',
        help: 'Compile to AOT snapshot for faster subsequent runs',
      )
      ..addFlag(
        'frozen',
        help: 'Refuse to run unless pubspec.lock exists in cache',
      )
      ..addFlag(
        'print-pubspec',
        help: 'Print the resolved pubspec.yaml and exit',
      )
      ..addOption('cache-dir', help: 'Override default cache directory');

    // Add commands
    addCommand(RunCommand());
    addCommand(CleanCommand());
    addCommand(HashCommand());
    addCommand(InstallCommand());
    addCommand(UpgradeCommand());
  }

  /// Check if verbose mode is enabled from parsed results
  bool _isVerboseFromResults(ArgResults results) {
    // artisanal uses -v, -vv, -vvv for verbosity levels
    // The verbose option could be a bool or int depending on how many -v flags
    final verboseValue = results['verbose'];
    if (verboseValue is bool) return verboseValue;
    if (verboseValue is int) return verboseValue > 0;
    return false;
  }

  String? _firstNonOptionArg(List<String> args) {
    final optionsWithValues = <String>{};
    final abbrWithValues = <String>{};

    for (final entry in argParser.options.entries) {
      if (!entry.value.isFlag) {
        optionsWithValues.add(entry.key);
        final abbr = entry.value.abbr;
        if (abbr != null && abbr.isNotEmpty) {
          abbrWithValues.add(abbr);
        }
      }
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      if (arg == '--') continue;

      if (arg.startsWith('--')) {
        final equalsIndex = arg.indexOf('=');
        final name = equalsIndex == -1
            ? arg.substring(2)
            : arg.substring(2, equalsIndex);

        if (optionsWithValues.contains(name)) {
          if (equalsIndex == -1 && i + 1 < args.length) {
            i++;
          }
          continue;
        }

        continue;
      }

      if (arg.startsWith('-') && arg.length > 1) {
        final abbr = arg.substring(1, 2);
        if (abbrWithValues.contains(abbr)) {
          if (arg.length == 2 && i + 1 < args.length) {
            i++;
          }
          continue;
        }

        continue;
      }

      return arg;
    }

    return null;
  }

  @override
  Future<void> run(Iterable<String> args) async {
    // Handle -- separator manually for script arguments
    final argList = args.toList();
    final separatorIndex = argList.indexOf('--');
    final argsBeforeSeparator = separatorIndex >= 0
        ? argList.sublist(0, separatorIndex)
        : argList;
    final scriptArgs = separatorIndex >= 0
        ? argList.sublist(separatorIndex + 1)
        : <String>[];

    // Check if first non-option argument is a .dart file (direct script run)
    final firstArg = _firstNonOptionArg(argsBeforeSeparator);

    if (firstArg != null &&
        firstArg.endsWith('.dart') &&
        !commands.containsKey(firstArg)) {
      // Direct script invocation: drun script.dart [-- args]
      await _runScript(argsBeforeSeparator, scriptArgs);
      return;
    }

    // Check if first non-flag is 'run' command
    if (firstArg == 'run') {
      // Explicit run command: drun run script.dart [-- args]
      // Pass script args via a custom mechanism
      await _handleRunCommand(argsBeforeSeparator, scriptArgs);
      return;
    }

    // Default behavior for other commands
    await super.run(args);
  }

  Future<void> _runScript(List<String> args, List<String> scriptArgs) async {
    final results = parse(args);

    final verbose = _isVerboseFromResults(results);
    final cacheManager = CacheManager(
      cacheDir: results['cache-dir'] as String?,
    );

    final rest = results.rest;
    if (rest.isEmpty) {
      io.error('No script file specified');
      io.info('Usage: drun <script.dart> [-- <args>]');
      exit(1);
    }

    final scriptPath = rest.first;
    final scriptFile = File(scriptPath);

    if (!scriptFile.existsSync()) {
      io.error('Script file not found: $scriptPath');
      exit(1);
    }

    if (verbose) {
      io.info('Script: $scriptPath');
      if (scriptArgs.isNotEmpty) {
        io.info('Script args: ${scriptArgs.join(' ')}');
      }
      io.info('Cache dir: ${cacheManager.cacheDir}');
    }

    // Parse header
    if (verbose) io.info('Parsing script header...');
    final header = HeaderParser.parseScript(scriptPath);

    if (verbose) {
      if (header.isFullManifest) {
        io.info('Header type: full pubspec manifest');
      } else if (header.dependencies.isNotEmpty) {
        io.info('Header type: inline dependencies');
        io.info('Dependencies: ${header.dependencies.keys.join(', ')}');
      } else {
        io.info('Header type: no dependencies declared');
      }
      if (header.sdkConstraint != null) {
        io.info('SDK constraint: ${header.sdkConstraint}');
      }
    }

    final pubspecContent = header.generatePubspecYaml();

    if (results['print-pubspec'] as bool) {
      print(pubspecContent);
      return;
    }

    // Get SDK version and generate cache key
    if (verbose) io.info('Detecting Dart SDK version...');
    final dartVersion = await PubManager.getDartSdkVersion();
    if (verbose) io.info('Dart SDK: $dartVersion');

    final scriptContent = scriptFile.readAsStringSync();
    final useAot = results['aot'] as bool;

    if (verbose) io.info('Generating cache key...');
    final cacheKey = cacheManager.generateCacheKey(
      pubspecContent,
      dartVersion,
      scriptContent,
      includeArch: useAot,
    );

    if (verbose) {
      io.info('Cache key: ${cacheKey.substring(0, 16)}...');
      io.info('Compilation mode: ${useAot ? 'AOT' : 'JIT'}');
    }

    // Check if we need to refresh or setup package
    final refresh = results['refresh'] as bool;
    final frozen = results['frozen'] as bool;
    final isCached = cacheManager.isPackageCached(cacheKey);

    if (verbose) {
      io.info('Package cached: ${isCached ? 'yes' : 'no'}');
      if (refresh) io.info('Refresh requested: forcing re-resolution');
      if (frozen) io.info('Frozen mode: will fail if not cached');
    }

    if (!isCached || refresh) {
      if (frozen && !isCached) {
        io.error('No cached package found and --frozen specified');
        exit(1);
      }

      if (verbose) {
        io.info('Setting up package cache...');
        io.info('Package dir: ${cacheManager.getPackageDir(cacheKey)}');
      }

      // Setup package
      if (verbose) io.info('Creating package structure...');
      cacheManager.createPackageStructure(cacheKey);

      if (verbose) io.info('Writing pubspec.yaml...');
      cacheManager.writePubspec(cacheKey, pubspecContent);

      if (verbose) io.info('Copying script to bin/main.dart...');
      cacheManager.copyScript(cacheKey, scriptPath);

      // Run pub get/upgrade
      final packageDir = cacheManager.getPackageDir(cacheKey);
      final offline = results['offline'] as bool;

      if (verbose) {
        if (refresh) {
          io.info('Running: dart pub upgrade');
        } else {
          io.info('Running: dart pub get${offline ? ' --offline' : ''}');
        }
      }

      final pubResult = refresh
          ? await PubManager.pubUpgrade(packageDir)
          : await PubManager.pubGet(packageDir, offline: offline);

      if (!pubResult.success) {
        io.error('Error running pub: ${pubResult.stderr}');
        exit(1);
      }

      if (verbose) {
        if (pubResult.stdout.trim().isNotEmpty) {
          // Show pub output in verbose mode
          for (final line in pubResult.stdout.trim().split('\n')) {
            io.info('  $line');
          }
        }
        io.success('Package setup complete');
      }
    } else if (verbose) {
      io.info('Using cached package');
    }

    final packageDir = cacheManager.getPackageDir(cacheKey);
    final runner = ScriptRunner(packageDir);

    // Handle AOT compilation
    if (useAot) {
      final aotPath = cacheManager.getAotPath(cacheKey);
      final isAotCached = cacheManager.isAotCached(cacheKey);

      if (verbose) {
        io.info('AOT artifact cached: ${isAotCached ? 'yes' : 'no'}');
        io.info('AOT path: $aotPath');
      }

      if (!isAotCached || refresh) {
        if (verbose) io.info('Compiling to AOT snapshot...');

        final compileResult = await runner.compileAot(
          aotPath,
          verbose: verbose,
        );
        if (!compileResult.success) {
          io.error('Error compiling AOT: ${compileResult.stderr}');
          exit(1);
        }

        if (verbose) io.success('AOT compilation complete');
      } else if (verbose) {
        io.info('Using cached AOT artifact');
      }

      // Run AOT artifact
      if (verbose) io.info('Executing AOT artifact...');
      final runResult = await runner.runAot(
        aotPath,
        args: scriptArgs,
        verbose: verbose,
      );

      if (runResult.stdout.isNotEmpty) print(runResult.stdout);
      if (runResult.stderr.isNotEmpty) stderr.write(runResult.stderr);

      exit(runResult.exitCode);
    } else {
      // Run with dart run
      if (verbose) io.info('Executing script with dart run...');
      final runResult = await runner.runScript(
        args: scriptArgs,
        verbose: verbose,
      );

      if (runResult.stdout.isNotEmpty) print(runResult.stdout);
      if (runResult.stderr.isNotEmpty) stderr.write(runResult.stderr);

      exit(runResult.exitCode);
    }
  }

  Future<void> _handleRunCommand(
    List<String> args,
    List<String> scriptArgs,
  ) async {
    // Remove 'run' from args and use _runScript
    final idx = args.indexOf('run');
    final newArgs = [...args.sublist(0, idx), ...args.sublist(idx + 1)];
    await _runScript(newArgs, scriptArgs);
  }
}

/// Command to run a Dart script with embedded dependencies (hidden, use direct invocation instead)
class RunCommand extends Command<void> {
  @override
  String get name => 'run';

  @override
  String get description => 'Run a Dart script with embedded dependencies';

  @override
  bool get hidden => true; // Hidden since direct invocation is preferred

  @override
  Future<void> run() async {
    // This is handled by DrunCommandRunner._handleRunCommand
    io.info('Use: drun <script.dart> [-- <args>]');
  }
}

/// Command to clean the cache
class CleanCommand extends Command<void> {
  @override
  String get name => 'clean';

  @override
  String get description => 'Clean the cache';

  CleanCommand() {
    argParser
      ..addFlag('all', help: 'Clean all cache entries')
      ..addOption(
        'older-than',
        help: 'Clean entries older than N days',
        defaultsTo: '30',
      );
  }

  bool get _isVerbose {
    final drunRunner = runner as CommandRunner?;
    if (drunRunner == null) return false;
    return drunRunner.verbosity == Verbosity.verbose ||
        drunRunner.verbosity == Verbosity.veryVerbose;
  }

  @override
  Future<void> run() async {
    final results = argResults!;
    final globalResults = this.globalResults!;

    final verbose = _isVerbose;
    final cacheManager = CacheManager(
      cacheDir: globalResults['cache-dir'] as String?,
    );

    if (results['all'] as bool) {
      if (verbose) io.info('Cleaning all cache entries...');
      cacheManager.cleanAll();
      io.success('Cache cleared');
    } else {
      final olderThan = int.tryParse(results['older-than'] as String) ?? 30;
      if (verbose) io.info('Cleaning entries older than $olderThan days...');
      cacheManager.cleanOld(olderThanDays: olderThan);
      io.success('Old cache entries cleaned');
    }
  }
}

/// Command to show cache information for a script
class HashCommand extends Command<void> {
  @override
  String get name => 'hash';

  @override
  String get description => 'Show cache information for a script';

  @override
  Future<void> run() async {
    final results = argResults!;
    final globalResults = this.globalResults!;

    final rest = results.rest;
    if (rest.isEmpty) {
      io.error('No script file specified');
      exit(1);
    }

    final scriptPath = rest.first;
    final scriptFile = File(scriptPath);

    if (!scriptFile.existsSync()) {
      io.error('Script file not found: $scriptPath');
      exit(1);
    }

    final cacheManager = CacheManager(
      cacheDir: globalResults['cache-dir'] as String?,
    );
    final header = HeaderParser.parseScript(scriptPath);
    final pubspecContent = header.generatePubspecYaml();
    final dartVersion = await PubManager.getDartSdkVersion();
    final scriptContent = scriptFile.readAsStringSync();

    final cacheKey = cacheManager.generateCacheKey(
      pubspecContent,
      dartVersion,
      scriptContent,
    );
    final aotCacheKey = cacheManager.generateCacheKey(
      pubspecContent,
      dartVersion,
      scriptContent,
      includeArch: true,
    );
    final packageDir = cacheManager.getPackageDir(cacheKey);
    final aotPath = cacheManager.getAotPath(aotCacheKey);

    io.info('Cache key (package): $cacheKey');
    io.info('Cache key (AOT): $aotCacheKey');
    io.info('Package dir: $packageDir');
    io.info('AOT path: $aotPath');
    io.info('Package cached: ${cacheManager.isPackageCached(cacheKey)}');
    io.info('AOT cached: ${cacheManager.isAotCached(aotCacheKey)}');
  }
}

/// Command to install a script to PATH
class InstallCommand extends Command<void> {
  @override
  String get name => 'install';

  @override
  String get description => 'Install a script to PATH';

  InstallCommand() {
    argParser.addOption('as', help: 'Install script with this name');
  }

  @override
  Future<void> run() async {
    io.warning('Install command not yet implemented');
    exit(1);
  }
}

/// Command to refresh cache for a script
class UpgradeCommand extends Command<void> {
  @override
  String get name => 'upgrade';

  @override
  String get description => 'Refresh cache for a script';

  @override
  Future<void> run() async {
    io.warning('Upgrade command not yet implemented');
    exit(1);
  }
}
