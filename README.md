# dartrun - Cargo-style Script Runner for Dart

`dartrun` is a Cargo-inspired script runner for Dart that allows you to run single-file Dart scripts with embedded dependency manifests. Just like `cargo-script` or Rust's RFC 3424, `dartrun` materializes temporary packages, caches build artifacts, and provides near-zero startup time for subsequent runs.

## Features

- ✨ **Embedded manifests** - Dependencies defined in script comments
- 🚀 **Fast caching** - Reuses packages and build artifacts 
- ⚡ **AOT compilation** - Optional ahead-of-time compilation for maximum performance
- 🔧 **Multiple formats** - Supports both inline deps and full pubspec blocks
- 📦 **Cargo-like UX** - Familiar commands and workflow
- 🛠️ **Zero config** - Works out of the box

## Installation

```bash
dart pub global activate dartrun
```

Or build from source:

```bash
git clone https://github.com/kingwill101/dartrun.git
cd dartrun
dart pub get
dart compile exe bin/drun.dart -o dartrun
```

## Quick Start

### 1. Simple Hello World

```dart
#!/usr/bin/env drun
//! dart-deps: 
//! dart-sdk: ">=3.5.0 <4.0.0"

void main(List<String> args) {
  final name = args.isNotEmpty ? args.first : 'World';
  print('Hello, $name!');
}
```

Run with:
```bash
dartrun hello.dart -- Dart
# Output: Hello, Dart!
```

### 2. HTTP Client Example

```dart
#!/usr/bin/env dartrun
//! dart-deps: http="^1.1.0"

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args.first : 'https://api.github.com/zen';
  
  print('Fetching: $url');
  final response = await http.get(Uri.parse(url));
  print('Status: ${response.statusCode}');
  print('Response: ${response.body.trim()}');
}
```

### 3. Full Pubspec Block (Advanced)

```dart
#!/usr/bin/env dartrun
//! pubspec:
/// name: advanced_script
/// environment:
///   sdk: ">=3.5.0 <4.0.0"
/// dependencies:
///   yaml: ^3.1.2
///   args: ^2.6.0
/// dependency_overrides:
///   my_local_pkg:
///     path: ../my_local_pkg

import 'package:yaml/yaml.dart';
import 'package:args/args.dart';

void main(List<String> arguments) {
  // Your script here...
}
```

## Command Line Usage

```bash
# Run a script
drun script.dart [-- <args>]

# Explicit run command  
drun run script.dart [-- <args>]

# Compile to AOT for faster subsequent runs
drun --aot script.dart [-- <args>]

# Show cache information
drun hash script.dart

# Show generated pubspec.yaml
drun --print-pubspec script.dart

# Clean cache
drun clean --all
drun clean --older-than 30

# Other options
drun --offline script.dart     # Offline mode
drun --refresh script.dart     # Force refresh dependencies
drun --verbose script.dart     # Show detailed output
```

## Cache Behavior

`drun` uses a deterministic cache keyed by:
- Pubspec content (normalized)  
- Dart SDK version
- Script content hash
- Platform (for AOT artifacts)

Cache layout:
```
~/.drun/
  v1/
    pkgs/<key>/          # Materialized packages
      pubspec.yaml
      pubspec.lock  
      bin/main.dart
    aot/<key>_<os>.aot   # AOT artifacts
```

### Cache Performance

- **First run**: Downloads deps, ~3-4 seconds
- **Subsequent runs**: Near-instant startup (~100ms)
- **AOT runs**: Maximum performance, ~50ms startup

## Script Header Formats

### Inline Dependencies (Quick)

```dart
//! dart-deps: http="^1.1.0", args="^2.6.0"  
//! dart-sdk: ">=3.5.0 <4.0.0"
```

### Full Pubspec Block (Powerful)

```dart
//! pubspec:
/// name: my_script
/// environment:
///   sdk: ">=3.5.0 <4.0.0"
/// dependencies:
///   http: ^1.1.0
///   my_package:
///     git:
///       url: https://github.com/org/package.git
///       ref: main
/// dependency_overrides:
///   local_pkg:
///     path: ../local_pkg
```

## Advanced Examples

### Git Dependency

```dart
#!/usr/bin/env drun
//! pubspec:
/// dependencies:
///   cool_package:
///     git:
///       url: https://github.com/dart-lang/cool_package.git
///       ref: main
```

### Path Dependency  

```dart
#!/usr/bin/env drun
//! pubspec:
/// dependencies:
///   my_lib:
///     path: ../my_lib
```

### Development Dependencies

```dart  
#!/usr/bin/env drun
//! pubspec:
/// dependencies:
///   http: ^1.1.0
/// dev_dependencies:
///   test: ^1.24.0
```

## Development

Run tests:
```bash
dart test
```

Run examples:
```bash
dart run bin/drun.dart examples/hello.dart -- Test
dart run bin/drun.dart examples/http_example.dart
dart run bin/drun.dart examples/yaml_example.dart -- --help
```

Build AOT binary:
```bash
dart compile exe bin/drun.dart -o drun
```

## Why drun?

Like Rust's `cargo-script`, `drun` solves the "single file with dependencies" problem:

- ✅ **No** separate `pubspec.yaml` files to manage
- ✅ **No** manual `dart pub get` commands  
- ✅ **No** slow startup times after first run
- ✅ **No** complicated project setup for simple scripts

Perfect for:
- Quick prototypes and experiments
- Utility scripts with external dependencies  
- Code examples and tutorials
- CI/CD scripts that need packages

## Comparison with Alternatives

| Tool | Inline Deps | Caching | AOT | Cargo-like UX |
|------|-------------|---------|-----|---------------|
| `drun` | ✅ | ✅ | ✅ | ✅ |
| `dart run` | ❌ | ❌ | ❌ | ❌ |
| Manual setup | ❌ | ❌ | Manual | ❌ |

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) for details.