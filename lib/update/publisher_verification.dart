import 'dart:io';

// Reviewed public certificate pins belong in source, never in a downloaded
// release file. Empty until the project provisions its real signing identity.
const trustedWindowsPublisherThumbprints = <String>[];

Future<void> verifyWindowsPublisher(String path) async {
  if (!Platform.isWindows || trustedWindowsPublisherThumbprints.isEmpty) {
    throw StateError(
      'Automatic installation is unavailable until a trusted publisher is configured.',
    );
  }
  if (trustedWindowsPublisherThumbprints.any(
    (pin) => !RegExp(r'^[A-Fa-f0-9]{40}$').hasMatch(pin),
  )) {
    throw StateError('Invalid publisher trust configuration');
  }
  final pins = trustedWindowsPublisherThumbprints
      .map((pin) => "'$pin'")
      .join(',');
  final systemRoot = Platform.environment['SystemRoot'];
  if (systemRoot == null) {
    throw StateError('Publisher verification is unavailable');
  }
  // Artifact path is passed as data, never interpolated into PowerShell code.
  final script =
      "\$ErrorActionPreference='Stop'; "
      "\$signature=Get-AuthenticodeSignature -LiteralPath \$env:ZANZIBARR_UPDATE_ARTIFACT; "
      "if (\$signature.Status -ne 'Valid' -or \$null -eq \$signature.SignerCertificate) { exit 1 }; "
      "if (\$signature.SignerCertificate.Thumbprint -notin @($pins)) { exit 2 }; exit 0";
  final process = await Process.start(
    '$systemRoot/System32/WindowsPowerShell/v1.0/powershell.exe',
    ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
    environment: {'ZANZIBARR_UPDATE_ARTIFACT': File(path).absolute.path},
  );
  // Drain output without including native errors or file paths in UI messages.
  final drains = Future.wait([
    process.stdout.drain<void>(),
    process.stderr.drain<void>(),
  ]);
  try {
    final code = await process.exitCode.timeout(const Duration(seconds: 30));
    if (code != 0) throw StateError('Installer publisher verification failed');
    await drains;
  } catch (_) {
    process.kill();
    throw StateError('Installer publisher verification failed');
  }
}
