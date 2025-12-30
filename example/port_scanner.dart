#!/usr/bin/env drun
//! dart-deps: args="^2.6.0"
//! dart-sdk: ">=3.5.0 <4.0.0"

/// Simple TCP port scanner
/// Usage: drun port_scanner.dart -- localhost
///        drun port_scanner.dart -- 192.168.1.1 --ports 20-100

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('ports',
        abbr: 'p', help: 'Port range (e.g., 1-1000)', defaultsTo: '1-1024')
    ..addOption('timeout', abbr: 't', help: 'Timeout in ms', defaultsTo: '200')
    ..addOption('concurrent',
        abbr: 'c', help: 'Concurrent connections', defaultsTo: '100')
    ..addFlag('common', help: 'Scan only common ports', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool || results.rest.isEmpty) {
    print('''
🔍 Port Scanner - TCP port scanner

Usage: drun port_scanner.dart -- <host> [options]

Options:
${parser.usage}

Examples:
  drun port_scanner.dart -- localhost
  drun port_scanner.dart -- 192.168.1.1 --ports 80-443
  drun port_scanner.dart -- example.com --common
  drun port_scanner.dart -- localhost -p 1-65535 -c 200
''');
    return;
  }

  final host = results.rest.first;
  final timeout = int.tryParse(results['timeout'] as String) ?? 200;
  final concurrent = int.tryParse(results['concurrent'] as String) ?? 100;
  final useCommon = results['common'] as bool;

  // Parse port range or use common ports
  List<int> ports;
  if (useCommon) {
    ports = commonPorts;
  } else {
    final portRange = results['ports'] as String;
    final match = RegExp(r'(\d+)-(\d+)').firstMatch(portRange);
    if (match != null) {
      final start = int.parse(match.group(1)!);
      final end = int.parse(match.group(2)!);
      ports = List.generate(end - start + 1, (i) => start + i);
    } else {
      ports = [int.tryParse(portRange) ?? 80];
    }
  }

  print('🔍 Scanning $host');
  print('   Ports: ${ports.length} (${ports.first}-${ports.last})');
  print('   Timeout: ${timeout}ms, Concurrent: $concurrent\n');

  final openPorts = <int>[];
  final stopwatch = Stopwatch()..start();

  // Scan ports with concurrency limit
  var scanned = 0;
  for (var i = 0; i < ports.length; i += concurrent) {
    final batch = ports.skip(i).take(concurrent);
    final futures = batch.map((port) => _scanPort(host, port, timeout));
    final results = await Future.wait(futures);

    for (var j = 0; j < results.length; j++) {
      if (results[j]) {
        final port = ports[i + j];
        openPorts.add(port);
        final service = portServices[port] ?? 'unknown';
        print('   ✅ Port $port open ($service)');
      }
    }

    scanned += batch.length;
    stdout.write('\r   Scanned: $scanned/${ports.length}');
  }

  stopwatch.stop();

  print('\n\n📊 Results:');
  print(
      '   Scanned: ${ports.length} ports in ${stopwatch.elapsedMilliseconds}ms');
  print('   Open: ${openPorts.length} ports');

  if (openPorts.isNotEmpty) {
    print('\n🔓 Open Ports:');
    for (final port in openPorts) {
      final service = portServices[port] ?? 'unknown';
      print('   $port/tcp  $service');
    }
  }
}

Future<bool> _scanPort(String host, int port, int timeoutMs) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: Duration(milliseconds: timeoutMs),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

const commonPorts = [
  21,
  22,
  23,
  25,
  53,
  80,
  110,
  111,
  135,
  139,
  143,
  443,
  445,
  993,
  995,
  1723,
  3306,
  3389,
  5432,
  5900,
  8080,
  8443,
  8888,
];

const portServices = {
  21: 'ftp',
  22: 'ssh',
  23: 'telnet',
  25: 'smtp',
  53: 'dns',
  80: 'http',
  110: 'pop3',
  111: 'rpcbind',
  135: 'msrpc',
  139: 'netbios',
  143: 'imap',
  443: 'https',
  445: 'smb',
  993: 'imaps',
  995: 'pop3s',
  1723: 'pptp',
  3306: 'mysql',
  3389: 'rdp',
  5432: 'postgresql',
  5900: 'vnc',
  8080: 'http-proxy',
  8443: 'https-alt',
  8888: 'http-alt',
};
