#!/usr/bin/env dartrun
//! dart-deps: markdown="^7.2.2", args="^2.6.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// Convert Markdown to HTML and optionally serve it
/// Usage: dartrun markdown_preview.dart -- README.md
///        dartrun markdown_preview.dart -- README.md -o output.html

import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:args/args.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('output', abbr: 'o', help: 'Output HTML file')
    ..addFlag('inline-html', help: 'Allow inline HTML', defaultsTo: true)
    ..addFlag(
      'github',
      abbr: 'g',
      help: 'Use GitHub flavored markdown',
      defaultsTo: true,
    )
    ..addFlag(
      'wrap',
      abbr: 'w',
      help: 'Wrap in HTML document',
      defaultsTo: true,
    )
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    print('''
📝 Markdown Preview - Convert Markdown to HTML

Usage: dartrun markdown_preview.dart -- <file.md> [options]

Options:
${parser.usage}

Examples:
  dartrun markdown_preview.dart -- README.md
  dartrun markdown_preview.dart -- doc.md -o preview.html
  dartrun markdown_preview.dart -- README.md --no-github
''');
    return;
  }

  final inputPath = results.rest.first;
  final outputPath = results['output'] as String?;
  final useGfm = results['github'] as bool;
  final wrap = results['wrap'] as bool;

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('❌ File not found: $inputPath');
    return;
  }

  print('📄 Converting: $inputPath');

  final markdown = file.readAsStringSync();

  // Choose extension set based on options
  final extensionSet = useGfm
      ? md.ExtensionSet.gitHubWeb
      : md.ExtensionSet.commonMark;

  final html = md.markdownToHtml(markdown, extensionSet: extensionSet);

  final output = wrap ? _wrapHtml(html, inputPath) : html;

  if (outputPath != null) {
    File(outputPath).writeAsStringSync(output);
    print('✅ Written to: $outputPath');
    print('   Open in browser: file://${File(outputPath).absolute.path}');
  } else {
    print('\n--- HTML Output ---\n');
    print(output);
  }
}

String _wrapHtml(String body, String title) =>
    '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      max-width: 800px;
      margin: 40px auto;
      padding: 0 20px;
      line-height: 1.6;
      color: #333;
    }
    pre {
      background: #f4f4f4;
      padding: 16px;
      border-radius: 8px;
      overflow-x: auto;
    }
    code {
      background: #f4f4f4;
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'Fira Code', 'Consolas', monospace;
    }
    pre code {
      padding: 0;
      background: none;
    }
    blockquote {
      border-left: 4px solid #ddd;
      margin: 0;
      padding-left: 16px;
      color: #666;
    }
    table {
      border-collapse: collapse;
      width: 100%;
    }
    th, td {
      border: 1px solid #ddd;
      padding: 8px 12px;
      text-align: left;
    }
    th {
      background: #f4f4f4;
    }
    img {
      max-width: 100%;
    }
    a {
      color: #0066cc;
    }
  </style>
</head>
<body>
$body
</body>
</html>
''';
