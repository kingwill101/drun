#!/usr/bin/env dartrun
//! dart-deps: path="^1.9.0", args="^2.6.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// Analyze files in a directory - count lines, files, extensions
/// Usage: dartrun file_stats.dart -- /path/to/directory
///        dartrun file_stats.dart -- . --ext dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('ext', abbr: 'e', help: 'Filter by extension (e.g., dart, js)')
    ..addFlag('recursive',
        abbr: 'r', help: 'Scan subdirectories', defaultsTo: true)
    ..addFlag('hidden', help: 'Include hidden files', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    print('File Statistics - Analyze files in a directory\n');
    print('Usage: dartrun file_stats.dart -- <directory> [options]\n');
    print(parser.usage);
    print('\nExamples:');
    print('  dartrun file_stats.dart -- .');
    print('  dartrun file_stats.dart -- ./lib --ext dart');
    print('  dartrun file_stats.dart -- . --no-recursive');
    return;
  }

  final targetDir = results.rest.first;
  final filterExt = results['ext'] as String?;
  final recursive = results['recursive'] as bool;
  final includeHidden = results['hidden'] as bool;

  final dir = Directory(targetDir);
  if (!dir.existsSync()) {
    print('❌ Directory not found: $targetDir');
    return;
  }

  print('📁 Analyzing: ${p.absolute(targetDir)}\n');

  var totalFiles = 0;
  var totalLines = 0;
  var totalBytes = 0;
  final extensionStats = <String, int>{};
  final largestFiles = <MapEntry<String, int>>[];

  await for (final entity
      in dir.list(recursive: recursive, followLinks: false)) {
    if (entity is! File) continue;

    final name = p.basename(entity.path);
    if (!includeHidden && name.startsWith('.')) continue;

    final ext = p.extension(entity.path).toLowerCase();
    if (filterExt != null && ext != '.$filterExt') continue;

    try {
      final stat = entity.statSync();
      final lines = entity.readAsLinesSync().length;

      totalFiles++;
      totalLines += lines;
      totalBytes += stat.size;

      extensionStats[ext.isEmpty ? '(no ext)' : ext] =
          (extensionStats[ext.isEmpty ? '(no ext)' : ext] ?? 0) + 1;

      largestFiles.add(MapEntry(entity.path, stat.size));
    } catch (_) {
      // Skip files we can't read
    }
  }

  // Sort largest files
  largestFiles.sort((a, b) => b.value.compareTo(a.value));

  print('📊 Statistics:');
  print('   Files: $totalFiles');
  print('   Lines: $totalLines');
  print('   Size:  ${_formatBytes(totalBytes)}');

  print('\n📂 By Extension:');
  final sortedExts = extensionStats.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in sortedExts.take(10)) {
    print('   ${entry.key.padRight(10)} ${entry.value} files');
  }

  if (largestFiles.isNotEmpty) {
    print('\n📦 Largest Files:');
    for (final entry in largestFiles.take(5)) {
      print(
          '   ${_formatBytes(entry.value).padLeft(10)} ${p.relative(entry.key)}');
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024)
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}
