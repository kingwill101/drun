#!/usr/bin/env drun
//! dart-deps: args="^2.6.0", path="^1.9.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// Git repository statistics - analyze commits, contributors, and activity
/// Usage: drun git_stats.dart -- /path/to/repo
///        drun git_stats.dart -- . --days 30

import 'dart:io';
import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('days',
        abbr: 'd', help: 'Analyze last N days', defaultsTo: '90')
    ..addOption('author', abbr: 'a', help: 'Filter by author')
    ..addFlag('files', abbr: 'f', help: 'Show most changed files')
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('''
📊 Git Stats - Repository analytics

Usage: drun git_stats.dart -- [repo-path] [options]

Options:
${parser.usage}

Examples:
  drun git_stats.dart -- .
  drun git_stats.dart -- ~/projects/myrepo --days 30
  drun git_stats.dart -- . --author "John Doe"
  drun git_stats.dart -- . --files
''');
    return;
  }

  final repoPath = results.rest.isNotEmpty ? results.rest.first : '.';
  final days = int.tryParse(results['days'] as String) ?? 90;
  final authorFilter = results['author'] as String?;
  final showFiles = results['files'] as bool;

  // Check if it's a git repo
  final gitDir = Directory('$repoPath/.git');
  if (!gitDir.existsSync()) {
    print('❌ Not a git repository: $repoPath');
    return;
  }

  print('📁 Repository: $repoPath');
  print('📅 Analyzing last $days days\n');

  // Get commit count
  final since = DateTime.now().subtract(Duration(days: days));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';

  // Total commits
  var commitArgs = ['log', '--oneline', '--since=$sinceStr'];
  if (authorFilter != null) commitArgs.addAll(['--author=$authorFilter']);

  final commits = await _runGit(repoPath, commitArgs);
  final commitCount =
      commits.trim().split('\n').where((l) => l.isNotEmpty).length;

  // Contributors
  final contributors = await _runGit(repoPath, [
    'shortlog',
    '-sn',
    '--since=$sinceStr',
    'HEAD',
  ]);

  // Parse contributors
  final contribLines =
      contributors.trim().split('\n').where((l) => l.isNotEmpty);
  final contribList = contribLines
      .map((line) {
        final match = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(line);
        if (match != null) {
          return (int.parse(match.group(1)!), match.group(2)!.trim());
        }
        return null;
      })
      .whereType<(int, String)>()
      .toList();

  // Current branch
  final branch = (await _runGit(repoPath, ['branch', '--show-current'])).trim();

  // Uncommitted changes
  final status = await _runGit(repoPath, ['status', '--porcelain']);
  final uncommitted =
      status.trim().split('\n').where((l) => l.isNotEmpty).length;

  print('📊 Statistics:');
  print('   Current branch: $branch');
  print('   Commits (${days}d): $commitCount');
  print('   Contributors: ${contribList.length}');
  print('   Uncommitted changes: $uncommitted');

  if (contribList.isNotEmpty) {
    print('\n👥 Top Contributors:');
    for (final (count, name) in contribList.take(10)) {
      final bar = '█' * (count * 20 ~/ (contribList.first.$1 + 1));
      print('   ${name.padRight(25)} $count $bar');
    }
  }

  // Commit activity by day of week
  final dayLog = await _runGit(repoPath, [
    'log',
    '--format=%ad',
    '--date=format:%u',
    '--since=$sinceStr',
  ]);

  final dayCounts = <int, int>{};
  for (final day in dayLog.trim().split('\n').where((l) => l.isNotEmpty)) {
    final d = int.tryParse(day);
    if (d != null) dayCounts[d] = (dayCounts[d] ?? 0) + 1;
  }

  if (dayCounts.isNotEmpty) {
    final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxCount = dayCounts.values.reduce((a, b) => a > b ? a : b);

    print('\n📅 Activity by Day:');
    for (var i = 1; i <= 7; i++) {
      final count = dayCounts[i] ?? 0;
      final bar = '█' * (count * 20 ~/ (maxCount + 1));
      print('   ${days[i].padRight(4)} ${count.toString().padLeft(4)} $bar');
    }
  }

  // Most changed files
  if (showFiles) {
    final filesLog = await _runGit(repoPath, [
      'log',
      '--pretty=format:',
      '--name-only',
      '--since=$sinceStr',
    ]);

    final fileCounts = <String, int>{};
    for (final file in filesLog.trim().split('\n').where((l) => l.isNotEmpty)) {
      fileCounts[file] = (fileCounts[file] ?? 0) + 1;
    }

    final sortedFiles = fileCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print('\n📁 Most Changed Files:');
    for (final entry in sortedFiles.take(10)) {
      print('   ${entry.value.toString().padLeft(4)} ${entry.key}');
    }
  }

  // Recent commits
  print('\n📝 Recent Commits:');
  final recentCommits = await _runGit(repoPath, [
    'log',
    '--oneline',
    '-10',
    '--since=$sinceStr',
  ]);
  for (final line
      in recentCommits.trim().split('\n').where((l) => l.isNotEmpty)) {
    print('   $line');
  }
}

Future<String> _runGit(String workingDir, List<String> args) async {
  final result = await Process.run(
    'git',
    args,
    workingDirectory: workingDir,
  );
  return result.stdout.toString();
}
