import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Manages the drun cache directory and file layout
class CacheManager {
  final String cacheDir;
  
  CacheManager({String? cacheDir}) 
    : cacheDir = cacheDir ?? _getDefaultCacheDir();
  
  static String _getDefaultCacheDir() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw StateError('Cannot determine home directory');
    }
    return path.join(home, '.drun');
  }
  
  /// Generate cache key from pubspec content, SDK version, script content, and platform
  String generateCacheKey(String pubspecContent, String dartSdkVersion, 
                         String scriptContent, {bool includeArch = false}) {
    final normalizedPubspec = _normalizePubspecContent(pubspecContent);
    final keyComponents = [
      'pubspec:$normalizedPubspec',
      'sdk:$dartSdkVersion', 
      'script:${sha256.convert(utf8.encode(scriptContent)).toString()}',
    ];
    
    if (includeArch) {
      keyComponents.add('platform:${Platform.operatingSystem}_${Platform.localeName}');
    }
    
    final combined = keyComponents.join('|');
    return sha256.convert(utf8.encode(combined)).toString();
  }
  
  /// Get the package directory for a cache key
  String getPackageDir(String cacheKey) {
    return path.join(cacheDir, 'v1', 'pkgs', cacheKey);
  }
  
  /// Get the AOT artifact path for a cache key
  String getAotPath(String cacheKey) {
    final ext = Platform.isWindows ? '.exe' : 
               Platform.isMacOS ? '.app' : '.aot';
    final arch = Platform.operatingSystem;
    return path.join(cacheDir, 'v1', 'aot', '${cacheKey}_${arch}$ext');
  }
  
  /// Check if package directory exists and has valid pubspec.lock
  bool isPackageCached(String cacheKey) {
    final pkgDir = getPackageDir(cacheKey);
    final pubspecLock = File(path.join(pkgDir, 'pubspec.lock'));
    final mainDart = File(path.join(pkgDir, 'bin', 'main.dart'));
    
    return Directory(pkgDir).existsSync() && 
           pubspecLock.existsSync() && 
           mainDart.existsSync();
  }
  
  /// Check if AOT artifact exists
  bool isAotCached(String cacheKey) {
    return File(getAotPath(cacheKey)).existsSync();
  }
  
  /// Create package directory structure
  void createPackageStructure(String cacheKey) {
    final pkgDir = getPackageDir(cacheKey);
    final binDir = path.join(pkgDir, 'bin');
    
    Directory(binDir).createSync(recursive: true);
  }
  
  /// Write pubspec.yaml to package directory
  void writePubspec(String cacheKey, String pubspecContent) {
    final pkgDir = getPackageDir(cacheKey);
    final pubspecFile = File(path.join(pkgDir, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync(pubspecContent);
  }
  
  /// Copy script to package bin/main.dart
  void copyScript(String cacheKey, String scriptPath) {
    final pkgDir = getPackageDir(cacheKey);
    final mainDart = File(path.join(pkgDir, 'bin', 'main.dart'));
    
    final scriptFile = File(scriptPath);
    final originalContent = scriptFile.readAsStringSync();
    
    // Create a wrapper that filters out the '--' argument passed by dart run
    final wrappedContent = _wrapScriptWithArgFilter(originalContent);
    mainDart.writeAsStringSync(wrappedContent);
  }
  
  String _wrapScriptWithArgFilter(String originalScript) {
    // Find the main function and extract its parameter name
    final lines = originalScript.split('\n');
    final buffer = StringBuffer();
    
    bool foundMainFunction = false;
    String? parameterName;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Look for main function declaration
      if (!foundMainFunction && line.contains('main(') && line.contains('List<String>')) {
        foundMainFunction = true;
        
        // Extract parameter name from the function signature
        final mainMatch = RegExp(r'main\(List<String>\s+(\w+)\)').firstMatch(line);
        parameterName = mainMatch?.group(1) ?? 'arguments';
        
        // Check if the main function is async
        final isAsync = line.contains('async') || line.contains('Future');
        
        // Add the original line  
        buffer.writeln(line);
        // Add the argument filtering logic
        buffer.writeln('  // Filter out dart run\'s -- separator');
        buffer.writeln('  final filteredArgs = $parameterName.where((arg) => arg != \'--\').toList();');
        if (isAsync) {
          buffer.writeln('  return _originalMain(filteredArgs);');
        } else {
          buffer.writeln('  _originalMain(filteredArgs);');
        }
        buffer.writeln('}');
        buffer.writeln('');
        
        // Preserve the async nature of the function
        final returnType = isAsync ? line.contains('Future<void>') ? 'Future<void>' : 'Future' : 'void';
        buffer.writeln('$returnType _originalMain(List<String> $parameterName) ${isAsync ? 'async ' : ''}{');
        continue;
      }
      
      buffer.writeln(line);
    }
    
    return buffer.toString();
  }
  
  /// Clean cache entries older than specified days
  void cleanOld({int olderThanDays = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    
    // Clean package directories
    final pkgsDir = Directory(path.join(cacheDir, 'v1', 'pkgs'));
    if (pkgsDir.existsSync()) {
      for (final entity in pkgsDir.listSync()) {
        if (entity is Directory && entity.statSync().modified.isBefore(cutoff)) {
          entity.deleteSync(recursive: true);
        }
      }
    }
    
    // Clean AOT artifacts
    final aotDir = Directory(path.join(cacheDir, 'v1', 'aot'));
    if (aotDir.existsSync()) {
      for (final entity in aotDir.listSync()) {
        if (entity is File && entity.statSync().modified.isBefore(cutoff)) {
          entity.deleteSync();
        }
      }
    }
  }
  
  /// Clean all cache entries
  void cleanAll() {
    final cacheDirectory = Directory(cacheDir);
    if (cacheDirectory.existsSync()) {
      cacheDirectory.deleteSync(recursive: true);
    }
  }
  
  /// Get cache statistics
  CacheStats getStats() {
    int packageCount = 0;
    int aotCount = 0;
    int totalSize = 0;
    
    final pkgsDir = Directory(path.join(cacheDir, 'v1', 'pkgs'));
    if (pkgsDir.existsSync()) {
      packageCount = pkgsDir.listSync().whereType<Directory>().length;
      totalSize += _calculateDirectorySize(pkgsDir);
    }
    
    final aotDir = Directory(path.join(cacheDir, 'v1', 'aot'));
    if (aotDir.existsSync()) {
      final aotFiles = aotDir.listSync().whereType<File>().toList();
      aotCount = aotFiles.length;
      totalSize += aotFiles.fold<int>(0, (sum, file) => sum + file.lengthSync());
    }
    
    return CacheStats(
      packageCount: packageCount,
      aotCount: aotCount,
      totalSizeBytes: totalSize,
      cacheDir: cacheDir,
    );
  }
  
  int _calculateDirectorySize(Directory dir) {
    int size = 0;
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          size += entity.lengthSync();
        }
      }
    } catch (e) {
      // Handle permission errors gracefully
    }
    return size;
  }
  
  String _normalizePubspecContent(String content) {
    // For now, just trim and remove extra whitespace
    // In a more robust implementation, we'd parse YAML and re-emit with sorted keys
    return content.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

/// Cache statistics information
class CacheStats {
  final int packageCount;
  final int aotCount;
  final int totalSizeBytes;
  final String cacheDir;
  
  CacheStats({
    required this.packageCount,
    required this.aotCount,
    required this.totalSizeBytes,
    required this.cacheDir,
  });
  
  String get totalSizeHuman {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = totalSizeBytes.toDouble();
    int unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
  
  @override
  String toString() {
    return 'Cache: $packageCount packages, $aotCount AOT artifacts, $totalSizeHuman total';
  }
}