import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Download only this fork's installer, verify its release checksum, then open
/// the interactive installer. Windows Setup handles closing the running app.
class WindowsUpdateInstaller {
  WindowsUpdateInstaller({
    required this.client,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String)? launch,
  }) : temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       launch = launch ?? _launch;

  final http.Client client;
  final Future<Directory> Function() temporaryDirectory;
  final Future<void> Function(String) launch;
  static const installerName = 'zanzibarr-windows-x64-setup.exe';

  static Future<void> _launch(String path) async {
    await Process.start(path, ['/SP-'], mode: ProcessStartMode.detached);
  }

  static Uri _asset(String url, String name) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port != 443 ||
        segments.length != 6 ||
        segments[0] != 'P-Sivakumaran' ||
        segments[1] != 'zanzibarr' ||
        segments[2] != 'releases' ||
        segments[3] != 'download' ||
        segments[4].isEmpty ||
        segments[5] != name) {
      throw StateError('Invalid update asset URL');
    }
    return uri;
  }

  Future<void> install({
    required String installerUrl,
    required String checksumsUrl,
    ValueChanged<double>? onProgress,
  }) async {
    final installer = _asset(installerUrl, installerName);
    final checksums = _asset(checksumsUrl, 'SHA256SUMS');
    if (installer.pathSegments[4] != checksums.pathSegments[4]) {
      throw StateError('Update assets belong to different releases');
    }
    final checksumResponse = await client
        .send(http.Request('GET', checksums))
        .timeout(const Duration(seconds: 30));
    if (checksumResponse.statusCode != 200) {
      await checksumResponse.stream.listen(null).cancel();
      throw StateError('Update checksums are unavailable');
    }
    final bytes = <int>[];
    final checksumDeadline = DateTime.now().add(const Duration(minutes: 1));
    await for (final chunk in checksumResponse.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > 64 * 1024 ||
          DateTime.now().isAfter(checksumDeadline)) {
        throw StateError('Update checksum file is too large');
      }
      bytes.addAll(chunk);
    }
    final matches = RegExp(
      r'^([a-fA-F0-9]{64}) [ *]zanzibarr-windows-x64-setup\.exe\r?$',
      multiLine: true,
    ).allMatches(String.fromCharCodes(bytes)).toList();
    if (matches.length != 1) {
      throw StateError('Installer checksum is missing or ambiguous');
    }
    final expected = matches.single.group(1)!.toLowerCase();
    final directory = await (await temporaryDirectory()).createTemp(
      'zanzibarr-update-',
    );
    var launched = false;
    try {
      final file = File('${directory.path}/$installerName');
      final response = await client
          .send(http.Request('GET', installer))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        throw StateError('Installer download failed');
      }
      const maxBytes = 256 * 1024 * 1024;
      var received = 0;
      final sink = file.openWrite();
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          received += chunk.length;
          if (received > maxBytes || DateTime.now().isAfter(deadline)) {
            throw StateError('Installer download exceeded its limit');
          }
          sink.add(chunk);
          await sink.flush();
          final total = response.contentLength;
          if (total != null && total > 0) {
            onProgress?.call((received / total).clamp(0, 1));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != expected) {
        throw StateError('Installer checksum verification failed');
      }
      await launch(file.absolute.path);
      launched = true;
    } finally {
      // Keep a successfully launched executable until Windows has finished with it.
      if (!launched) await directory.delete(recursive: true);
    }
  }
}
