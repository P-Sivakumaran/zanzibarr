import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanzibarr/update/windows_update.dart';

void main() {
  const base =
      'https://github.com/P-Sivakumaran/zanzibarr/releases/download/v9.9';
  const installerUrl = '$base/${WindowsUpdateInstaller.installerName}';
  const checksumsUrl = '$base/SHA256SUMS';
  final payload = utf8.encode('test installer bytes; never executed');
  late Directory temporary;
  late List<String> launched;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'zanzibarr-updater-test-',
    );
    launched = [];
  });
  tearDown(() async => temporary.delete(recursive: true));

  WindowsUpdateInstaller create({
    String? sums,
    int status = 200,
    Future<void> Function(String)? publisher,
  }) => WindowsUpdateInstaller(
    client: MockClient((request) async {
      if (request.url.path.endsWith('/SHA256SUMS')) {
        return http.Response(
          sums ??
              '${sha256.convert(payload)}  ${WindowsUpdateInstaller.installerName}\n',
          200,
        );
      }
      return http.Response.bytes(payload, status);
    }),
    temporaryDirectory: () async => temporary,
    verifyPublisher: publisher ?? (_) async {},
    launch: (path) async => launched.add(path),
  );

  test('a correct checksum cannot bypass publisher rejection', () async {
    await expectLater(
      create(
        publisher: (_) async {
          throw StateError('Untrusted publisher');
        },
      ).install(installerUrl: installerUrl, checksumsUrl: checksumsUrl),
      throwsStateError,
    );
    expect(launched, isEmpty);
    expect(await temporary.list().toList(), isEmpty);
  });

  test('launches only the fully downloaded, verified installer', () async {
    final progress = <double>[];
    await create().install(
      installerUrl: installerUrl,
      checksumsUrl: checksumsUrl,
      onProgress: progress.add,
    );
    expect(launched, hasLength(1));
    expect(await File(launched.single).readAsBytes(), payload);
    expect(progress.last, 1);
  });

  test(
    'checksum mismatch never launches and removes downloaded files',
    () async {
      await expectLater(
        create(
          sums: '${'0' * 64}  ${WindowsUpdateInstaller.installerName}\n',
        ).install(installerUrl: installerUrl, checksumsUrl: checksumsUrl),
        throwsStateError,
      );
      expect(launched, isEmpty);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test('ambiguous or missing installer checksum never launches', () async {
    final line =
        '${sha256.convert(payload)}  ${WindowsUpdateInstaller.installerName}\n';
    for (final sums in ['', '$line$line']) {
      await expectLater(
        create(
          sums: sums,
        ).install(installerUrl: installerUrl, checksumsUrl: checksumsUrl),
        throwsStateError,
      );
    }
    expect(launched, isEmpty);
  });

  test(
    'rejects upstream, insecure, wrong-name and cross-release assets',
    () async {
      for (final url in [
        installerUrl.replaceFirst('https:', 'http:'),
        installerUrl.replaceFirst('P-Sivakumaran', 'envermeister'),
        '$installerUrl?extra=1',
        installerUrl.replaceFirst('.exe', '.zip'),
        installerUrl.replaceFirst('v9.9', 'v8.8'),
      ]) {
        await expectLater(
          create().install(installerUrl: url, checksumsUrl: checksumsUrl),
          throwsStateError,
        );
      }
      expect(launched, isEmpty);
    },
  );

  test('failed downloads are cleaned up without launching', () async {
    await expectLater(
      create(
        status: 503,
      ).install(installerUrl: installerUrl, checksumsUrl: checksumsUrl),
      throwsStateError,
    );
    expect(launched, isEmpty);
    expect(await temporary.list().toList(), isEmpty);
  });
}
