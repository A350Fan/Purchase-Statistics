import 'dart:convert';
import 'dart:io';

/// Legt fest, welcher Git-Dateibestand gescannt wird.
enum ScanMode { tracked, staged, all, history }

// Erkennungsmuster fuer haeufige Geheimnisse. Die Werte selbst werden beim
// Reporting nie ausgegeben, damit der Scanner nicht versehentlich Secrets in
// Logs kopiert.
final List<_SecretRule> _secretRules = [
  _SecretRule(
    'private key block',
    RegExp(r'-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----', caseSensitive: false),
  ),
  _SecretRule('AWS access key', RegExp(r'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b')),
  _SecretRule(
    'GitHub token',
    RegExp(r'\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b'),
  ),
  _SecretRule('GitLab token', RegExp(r'\bglpat-[A-Za-z0-9_-]{20,}\b')),
  _SecretRule('Slack token', RegExp(r'\bxox[baprs]-[A-Za-z0-9-]{20,}\b')),
  _SecretRule('Google API key', RegExp(r'\bAIza[0-9A-Za-z_-]{35}\b')),
  _SecretRule('OpenAI API key', RegExp(r'\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b')),
  _SecretRule(
    'Stripe secret key',
    RegExp(r'\b(?:sk|rk)_(?:live|test)_[0-9A-Za-z]{16,}\b'),
  ),
  _SecretRule('npm token', RegExp(r'\bnpm_[A-Za-z0-9]{36,}\b')),
  _SecretRule(
    'Steam-like API key',
    RegExp(r'\b[A-Fa-f0-9]{32}\b'),
    shouldReport: (match, line) => _hasSecretContext(line),
  ),
  _SecretRule(
    'quoted secret assignment',
    RegExp(
      r'''\b(api[_-]?key|client[_-]?secret|secret|token|password|passwd|pwd|bearer|private[_-]?key)\b\s*[:=]\s*["']([A-Za-z0-9_./+=:-]{20,})["']''',
      caseSensitive: false,
    ),
    shouldReport: (match, line) => !_isPlaceholderValue(match.group(2)),
  ),
  _SecretRule(
    'environment secret assignment',
    RegExp(
      r'^\s*(?:export\s+)?[A-Z0-9_]*(?:API_?KEY|SECRET|TOKEN|PASSWORD|PASSWD|PWD|PRIVATE_?KEY)[A-Z0-9_]*\s*=\s*([A-Za-z0-9_./+=:-]{20,})\s*(?:#.*)?$',
      caseSensitive: false,
    ),
    shouldReport: (match, line) => !_isPlaceholderValue(match.group(1)),
  ),
];

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final mode = _parseMode(args);
  final repoRoot = await _repoRoot();
  // Fuer den History-Scan werden aktuelle Dateien normal gescannt; die
  // Commit-Historie kommt anschliessend separat dazu.
  final files = await _collectFiles(
    mode == ScanMode.history ? ScanMode.tracked : mode,
    repoRoot,
  );
  final findings = <_Finding>[];
  var scannedTextFiles = 0;

  for (final file in files) {
    final normalizedPath = _normalizePath(file);

    if (normalizedPath.isEmpty) {
      continue;
    }

    if (_isForbiddenPath(normalizedPath)) {
      // Bestimmte private Dateien sollen unabhaengig vom Inhalt nicht in Git
      // landen.
      findings.add(
        _Finding(
          path: normalizedPath,
          line: null,
          rule: 'private file pattern',
        ),
      );
      continue;
    }

    final path = _pathFromRepoRoot(repoRoot, normalizedPath);
    final contents = await _readTextFile(path);

    if (contents == null) {
      continue;
    }

    scannedTextFiles += 1;
    findings.addAll(_scanFile(normalizedPath, contents));
  }

  if (mode == ScanMode.history) {
    // History ist teurer, deshalb laeuft sie nur explizit mit --history.
    findings.addAll(await _scanHistory(repoRoot));
  }

  if (findings.isNotEmpty) {
    stderr.writeln('Potential secrets or private files were found.');
    stderr.writeln('Secret values are intentionally not printed.');
    stderr.writeln('');

    for (final finding in findings.take(50)) {
      final location = finding.line == null
          ? finding.path
          : '${finding.path}:${finding.line}';
      stderr.writeln(' - $location (${finding.rule})');
    }

    if (findings.length > 50) {
      stderr.writeln(' - ... ${findings.length - 50} more finding(s)');
    }

    stderr.writeln('');
    stderr.writeln(
      'Remove the private file or replace the secret with a placeholder. '
      'If a real secret was committed, rotate it before publishing.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Security scan passed: scanned $scannedTextFiles text file(s) '
    'from ${files.length} candidate file(s).',
  );
}

ScanMode _parseMode(List<String> args) {
  // Standard ist der schnelle Scan der getrackten Dateien.
  var mode = ScanMode.tracked;

  for (final arg in args) {
    switch (arg) {
      case '--staged':
        mode = ScanMode.staged;
      case '--all':
        mode = ScanMode.all;
      case '--history':
        mode = ScanMode.history;
      default:
        stderr.writeln('Unknown argument: $arg');
        _printUsage();
        exit(64);
    }
  }

  return mode;
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart tool/security_scan.dart [--staged|--all|--history]',
  );
  stdout.writeln('');
  stdout.writeln('Default: scan tracked files.');
  stdout.writeln('--staged: scan staged files for the pre-commit hook.');
  stdout.writeln('--all: scan tracked and untracked non-ignored files.');
  stdout.writeln('--history: scan tracked files and reachable git history.');
}

Future<Directory> _repoRoot() async {
  // Der Scanner nutzt Git als Quelle der Wahrheit fuer das Repository-Root.
  final result = await Process.run(
    'git',
    ['rev-parse', '--show-toplevel'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    stderr.writeln('Unable to resolve git repository root.');
    stderr.writeln((result.stderr as String).trim());
    exit(1);
  }

  return Directory((result.stdout as String).trim());
}

Future<List<String>> _collectFiles(ScanMode mode, Directory repoRoot) async {
  // Die verschiedenen Modi mappen direkt auf Git-Kommandos. Null-separierte
  // Ausgabe vermeidet Probleme mit Leerzeichen in Dateinamen.
  final args = switch (mode) {
    ScanMode.tracked => ['ls-files', '-z'],
    ScanMode.staged => [
      'diff',
      '--cached',
      '--name-only',
      '--diff-filter=ACMR',
      '-z',
    ],
    ScanMode.all => ['ls-files', '-co', '--exclude-standard', '-z'],
    ScanMode.history => ['ls-files', '-z'],
  };

  final result = await Process.run(
    'git',
    args,
    workingDirectory: repoRoot.path,
    stdoutEncoding: null,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    stderr.writeln('Unable to collect files for security scan.');
    stderr.writeln((result.stderr as String).trim());
    exit(1);
  }

  return utf8
      .decode(result.stdout as List<int>, allowMalformed: true)
      .split('\u0000')
      .where((path) => path.trim().isNotEmpty)
      .toList(growable: false);
}

Future<List<_Finding>> _scanHistory(Directory repoRoot) async {
  // History-Scan prueft alle erreichbaren Commits auf Treffer, ohne Secret-Werte
  // auszugeben.
  final findings = <_Finding>[];
  final commitsResult = await Process.run(
    'git',
    ['rev-list', '--all'],
    workingDirectory: repoRoot.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (commitsResult.exitCode != 0) {
    stderr.writeln('Unable to collect git history for security scan.');
    stderr.writeln((commitsResult.stderr as String).trim());
    exit(1);
  }

  final commits = const LineSplitter()
      .convert(commitsResult.stdout as String)
      .where((commit) => commit.trim().isNotEmpty);

  const historyPattern =
      r'(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AIza[0-9A-Za-z_-]{35}|sk-(proj-)?[A-Za-z0-9_-]{20,}|(sk|rk)_(live|test)_[0-9A-Za-z]{16,}|npm_[A-Za-z0-9]{36,}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|((steam|api|key|secret|token).{0,80}[A-Fa-f0-9]{32})|([A-Fa-f0-9]{32}.{0,80}(steam|api|key|secret|token)))';
  final historicalFindings = <String>{};

  for (final commit in commits) {
    final shortCommit = commit.length > 12 ? commit.substring(0, 12) : commit;
    final treeResult = await Process.run(
      'git',
      ['ls-tree', '-r', '--name-only', '-z', commit],
      workingDirectory: repoRoot.path,
      stdoutEncoding: null,
      stderrEncoding: utf8,
    );

    if (treeResult.exitCode != 0) {
      stderr.writeln('Unable to inspect files for commit $shortCommit.');
      stderr.writeln((treeResult.stderr as String).trim());
      exit(1);
    }

    final paths = utf8
        .decode(treeResult.stdout as List<int>, allowMalformed: true)
        .split('\u0000')
        .where((path) => path.trim().isNotEmpty);

    for (final path in paths) {
      final normalizedPath = _normalizePath(path);

      if (_isForbiddenPath(normalizedPath)) {
        final location = '$shortCommit:$normalizedPath';

        if (historicalFindings.add('private-file:$location')) {
          findings.add(
            _Finding(
              path: location,
              line: null,
              rule: 'historical private file pattern',
            ),
          );
        }
      }
    }

    final grepResult = await Process.run(
      'git',
      ['grep', '-I', '-l', '-i', '-E', historyPattern, commit],
      workingDirectory: repoRoot.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (grepResult.exitCode == 1) {
      continue;
    }

    if (grepResult.exitCode != 0) {
      stderr.writeln('Unable to scan commit $shortCommit.');
      stderr.writeln((grepResult.stderr as String).trim());
      exit(1);
    }

    final matchedPaths = const LineSplitter()
        .convert(grepResult.stdout as String)
        .where((path) => path.trim().isNotEmpty);

    for (final matchedPath in matchedPaths) {
      final location = matchedPath.replaceFirst(commit, shortCommit);

      if (historicalFindings.add('secret:$location')) {
        findings.add(
          _Finding(
            path: location,
            line: null,
            rule: 'historical secret pattern',
          ),
        );
      }
    }
  }

  return findings;
}

List<_Finding> _scanFile(String path, String contents) {
  // Jeder Text wird zeilenweise geprueft, damit Findings konkrete
  // Datei-/Zeilennummern enthalten.
  final findings = <_Finding>[];
  final lines = const LineSplitter().convert(contents);

  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];

    for (final rule in _secretRules) {
      final matches = rule.pattern.allMatches(line);

      for (final match in matches) {
        if (rule.shouldReport != null && !rule.shouldReport!(match, line)) {
          continue;
        }

        findings.add(
          _Finding(path: path, line: index + 1, rule: rule.description),
        );
      }
    }
  }

  return findings;
}

Future<String?> _readTextFile(String path) async {
  // Binaerdateien und sehr grosse Dateien werden ausgelassen, weil sie fuer
  // Regex-Scans wenig Nutzen bringen und viele False Positives erzeugen.
  final file = File(path);

  if (!await file.exists()) {
    return null;
  }

  final length = await file.length();

  if (length > 1024 * 1024) {
    return null;
  }

  final bytes = await file.readAsBytes();

  if (_looksBinary(bytes)) {
    return null;
  }

  return utf8.decode(bytes, allowMalformed: true);
}

bool _looksBinary(List<int> bytes) {
  // Ein Nullbyte in der Stichprobe ist ein einfacher Hinweis auf Binaerdaten.
  final sampleLength = bytes.length < 8000 ? bytes.length : 8000;

  for (var index = 0; index < sampleLength; index += 1) {
    if (bytes[index] == 0) {
      return true;
    }
  }

  return false;
}

bool _hasSecretContext(String line) {
  // Hex-Strings werden nur gemeldet, wenn die Zeile nach API-Key/Secret-Kontext
  // aussieht. Das reduziert False Positives bei Hashes.
  final lower = line.toLowerCase();

  if (lower.contains('sha256') ||
      lower.contains('revision') ||
      lower.contains('checksum') ||
      lower.contains('hash')) {
    return false;
  }

  return lower.contains('secret') ||
      lower.contains('token') ||
      lower.contains('password') ||
      lower.contains('bearer') ||
      lower.contains('api_key') ||
      lower.contains('apikey') ||
      lower.contains('api key') ||
      (lower.contains('steam') && lower.contains('key'));
}

bool _isPlaceholderValue(String? value) {
  // Beispiele und Platzhalter sollen nicht als echte Secrets blockieren.
  if (value == null) {
    return true;
  }

  final normalized = value.trim().toLowerCase();

  if (normalized.isEmpty) {
    return true;
  }

  return normalized.contains('example') ||
      normalized.contains('placeholder') ||
      normalized.contains('dummy') ||
      normalized.contains('sample') ||
      normalized.contains('test') ||
      normalized.startsWith('your') ||
      normalized.startsWith('change-me') ||
      normalized.startsWith('changeme') ||
      normalized.startsWith('<') ||
      normalized.startsWith(r'${');
}

bool _isForbiddenPath(String path) {
  // Bekannte lokale Secret-Dateien werden schon anhand des Pfads blockiert.
  final lower = path.toLowerCase();
  final fileName = lower.split('/').last;

  if (_isExampleFile(fileName)) {
    return false;
  }

  if (fileName == '.env' || fileName.startsWith('.env.')) {
    return true;
  }

  const forbiddenNames = {
    '.netrc',
    '.npmrc',
    '.pypirc',
    'firebase_options.dart',
    'google-services.json',
    'googleservice-info.plist',
    'key.properties',
    'local.properties',
    'secrets.json',
    'secrets.yaml',
    'secrets.yml',
  };

  if (forbiddenNames.contains(fileName)) {
    return true;
  }

  const forbiddenExtensions = [
    '.csv',
    '.db',
    '.db-shm',
    '.db-wal',
    '.jks',
    '.key',
    '.keystore',
    '.mobileprovision',
    '.p12',
    '.p8',
    '.pem',
    '.pfx',
    '.sqlite',
    '.sqlite-shm',
    '.sqlite-wal',
    '.sqlite3',
    '.sqlite3-shm',
    '.sqlite3-wal',
    '.xlsx',
  ];

  return forbiddenExtensions.any(lower.endsWith);
}

bool _isExampleFile(String fileName) {
  return fileName.endsWith('.example') ||
      fileName.endsWith('.sample') ||
      fileName.endsWith('.template') ||
      fileName == '.env.example';
}

String _normalizePath(String path) {
  // Git liefert Pfade mit Slash; diese Funktion haelt das auch auf Windows
  // stabil.
  return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
}

String _pathFromRepoRoot(Directory repoRoot, String normalizedPath) {
  // Fuer Dateizugriff wird aus dem Git-Pfad wieder ein Plattformpfad.
  final nativePath = normalizedPath.split('/').join(Platform.pathSeparator);
  return '${repoRoot.path}${Platform.pathSeparator}$nativePath';
}

/// Ein einzelnes Secret-Erkennungsmuster.
class _SecretRule {
  final String description;
  final RegExp pattern;
  final bool Function(RegExpMatch match, String line)? shouldReport;

  const _SecretRule(this.description, this.pattern, {this.shouldReport});
}

/// Ergebnis eines Scanner-Treffers ohne Secret-Wert.
class _Finding {
  final String path;
  final int? line;
  final String rule;

  const _Finding({required this.path, required this.line, required this.rule});
}
