# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-dev.1] - 2025-12-30

### Added
- Initial release of drun - A Cargo-style script runner for Dart
- Support for embedded manifests in Dart scripts
- Inline dependency declarations using `//! dart-deps:` syntax
- Multi-line YAML dependency blocks using `//! dart-yaml` markers
- Automatic dependency resolution and caching
- Script execution with dependency management
- Compilation support for creating standalone executables
- Cache management commands (list, clean, clear)
- Support for running scripts from URLs
- Shebang support for direct script execution
- Comprehensive examples including:
  - CSV processing
  - Environment checking
  - File statistics
  - Git statistics
  - HTTP requests
  - JSON API interaction
  - Markdown preview
  - Port scanning
  - Shelf server
  - Todo CLI
  - YAML parsing

### Features
- Fast script execution with caching
- No need for separate pubspec.yaml files
- Cargo-inspired workflow for Dart
- Compatible with Dart SDK >=3.5.0
