#!/usr/bin/env drun
//! dart-deps: csv="^6.0.0", args="^2.6.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// CSV file processing tool - view, filter, and convert CSV files
/// Usage: drun csv_tool.dart -- data.csv
///        drun csv_tool.dart -- data.csv --filter "age>30"
///        drun csv_tool.dart -- data.csv --columns name,email

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:args/args.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('columns', abbr: 'c', help: 'Columns to display (comma-separated)')
    ..addOption('filter', abbr: 'f', help: 'Filter expression (e.g., "age>30")')
    ..addOption('limit', abbr: 'l', help: 'Limit number of rows')
    ..addOption('output', abbr: 'o', help: 'Output to JSON file')
    ..addFlag('no-header', help: 'CSV has no header row', defaultsTo: false)
    ..addFlag('stats', abbr: 's', help: 'Show column statistics')
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    print('''
📊 CSV Tool - Process and analyze CSV files

Usage: drun csv_tool.dart -- <file.csv> [options]

Options:
${parser.usage}

Examples:
  drun csv_tool.dart -- data.csv
  drun csv_tool.dart -- users.csv -c name,email -l 10
  drun csv_tool.dart -- data.csv --stats
  drun csv_tool.dart -- data.csv -o output.json

Sample CSV content for testing:
  name,age,email,city
  Alice,28,alice@example.com,NYC
  Bob,35,bob@example.com,LA
  Charlie,42,charlie@example.com,Chicago
''');
    return;
  }

  final inputPath = results.rest.first;
  final file = File(inputPath);
  
  if (!file.existsSync()) {
    // Create sample CSV for demo
    if (inputPath == 'sample.csv') {
      _createSampleCsv();
      print('📝 Created sample.csv - run again to process it');
      return;
    }
    print('❌ File not found: $inputPath');
    print('💡 Tip: Run with "sample.csv" to create a sample file');
    return;
  }

  final content = file.readAsStringSync();
  final converter = CsvToListConverter();
  final rows = converter.convert(content);

  if (rows.isEmpty) {
    print('❌ Empty CSV file');
    return;
  }

  final hasHeader = !(results['no-header'] as bool);
  final headers = hasHeader ? rows.first.map((e) => e.toString()).toList() : null;
  var dataRows = hasHeader ? rows.skip(1).toList() : rows;

  print('📄 File: $inputPath');
  print('   Rows: ${dataRows.length}, Columns: ${rows.first.length}\n');

  // Show statistics
  if (results['stats'] as bool && headers != null) {
    _showStats(headers, dataRows);
    return;
  }

  // Filter columns
  final columnsOpt = results['columns'] as String?;
  List<int>? columnIndices;
  if (columnsOpt != null && headers != null) {
    final selectedCols = columnsOpt.split(',').map((c) => c.trim()).toList();
    columnIndices = selectedCols
        .map((c) => headers.indexOf(c))
        .where((i) => i >= 0)
        .toList();
    
    if (columnIndices.isEmpty) {
      print('❌ No matching columns found');
      print('   Available: ${headers.join(', ')}');
      return;
    }
  }

  // Apply limit
  final limitOpt = results['limit'] as String?;
  if (limitOpt != null) {
    final limit = int.tryParse(limitOpt) ?? dataRows.length;
    dataRows = dataRows.take(limit).toList();
  }

  // Display table
  _displayTable(headers, dataRows, columnIndices);

  // Output to JSON
  final outputPath = results['output'] as String?;
  if (outputPath != null && headers != null) {
    _outputJson(headers, dataRows, outputPath, columnIndices);
  }
}

void _displayTable(List<String>? headers, List<List<dynamic>> rows, List<int>? indices) {
  final displayHeaders = indices != null && headers != null
      ? indices.map((i) => headers[i]).toList()
      : headers;

  final displayRows = indices != null
      ? rows.map((r) => indices.map((i) => r[i]).toList()).toList()
      : rows;

  // Calculate column widths
  final widths = <int>[];
  final colCount = displayRows.isNotEmpty ? displayRows.first.length : 0;
  
  for (var i = 0; i < colCount; i++) {
    var maxWidth = displayHeaders?[i].length ?? 0;
    for (final row in displayRows) {
      final cellWidth = row[i].toString().length;
      if (cellWidth > maxWidth) maxWidth = cellWidth;
    }
    widths.add(maxWidth.clamp(3, 40));
  }

  // Print header
  if (displayHeaders != null) {
    final headerRow = displayHeaders.asMap().entries
        .map((e) => e.value.padRight(widths[e.key]))
        .join(' │ ');
    print('┌─${widths.map((w) => '─' * w).join('─┬─')}─┐');
    print('│ $headerRow │');
    print('├─${widths.map((w) => '─' * w).join('─┼─')}─┤');
  }

  // Print rows
  for (final row in displayRows.take(20)) {
    final dataRow = row.asMap().entries
        .map((e) => e.value.toString().padRight(widths[e.key]).substring(0, widths[e.key]))
        .join(' │ ');
    print('│ $dataRow │');
  }
  print('└─${widths.map((w) => '─' * w).join('─┴─')}─┘');

  if (displayRows.length > 20) {
    print('... and ${displayRows.length - 20} more rows');
  }
}

void _showStats(List<String> headers, List<List<dynamic>> rows) {
  print('📊 Column Statistics:\n');
  
  for (var i = 0; i < headers.length; i++) {
    final values = rows.map((r) => r[i]).toList();
    final nonNull = values.where((v) => v != null && v.toString().isNotEmpty);
    final numeric = nonNull.map((v) => num.tryParse(v.toString())).whereType<num>();
    
    print('${headers[i]}:');
    print('   Non-empty: ${nonNull.length}/${values.length}');
    
    if (numeric.isNotEmpty) {
      final nums = numeric.toList();
      final sum = nums.reduce((a, b) => a + b);
      final avg = sum / nums.length;
      final min = nums.reduce((a, b) => a < b ? a : b);
      final max = nums.reduce((a, b) => a > b ? a : b);
      print('   Min: $min, Max: $max, Avg: ${avg.toStringAsFixed(2)}');
    } else {
      final unique = nonNull.toSet();
      print('   Unique values: ${unique.length}');
      if (unique.length <= 5) {
        print('   Values: ${unique.take(5).join(', ')}');
      }
    }
    print('');
  }
}

void _outputJson(List<String> headers, List<List<dynamic>> rows, String path, List<int>? indices) {
  final effectiveHeaders = indices != null 
      ? indices.map((i) => headers[i]).toList() 
      : headers;
  
  final jsonRows = rows.map((row) {
    final effectiveRow = indices != null 
        ? indices.map((i) => row[i]).toList() 
        : row;
    return Map.fromIterables(effectiveHeaders, effectiveRow);
  }).toList();

  final output = StringBuffer('[\n');
  for (var i = 0; i < jsonRows.length; i++) {
    output.write('  ${_mapToJson(jsonRows[i])}');
    if (i < jsonRows.length - 1) output.write(',');
    output.writeln();
  }
  output.write(']');
  
  File(path).writeAsStringSync(output.toString());
  print('\n✅ Written to: $path');
}

String _mapToJson(Map<String, dynamic> map) {
  final entries = map.entries.map((e) {
    final value = e.value;
    final jsonValue = value is num ? value : '"$value"';
    return '"${e.key}": $jsonValue';
  });
  return '{${entries.join(', ')}}';
}

void _createSampleCsv() {
  const sample = '''name,age,email,city,salary
Alice Johnson,28,alice@example.com,New York,75000
Bob Smith,35,bob@example.com,Los Angeles,82000
Charlie Brown,42,charlie@example.com,Chicago,95000
Diana Prince,31,diana@example.com,Seattle,88000
Eve Wilson,26,eve@example.com,Boston,70000
Frank Miller,45,frank@example.com,Denver,110000
Grace Lee,33,grace@example.com,Austin,79000
Henry Davis,29,henry@example.com,Portland,72000''';
  
  File('sample.csv').writeAsStringSync(sample);
}
