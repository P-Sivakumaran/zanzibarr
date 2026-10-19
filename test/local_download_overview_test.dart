import 'dart:io';
import 'package:zanzibarr/player/local_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/main.dart';
import 'package:zanzibarr/metadata/film_blurb.dart';
import 'package:zanzibarr/metadata/metadata_service.dart';
import 'package:zanzibarr/metadata/title_library.dart';
import 'package:zanzibarr/player/download_screen.dart';
import 'package:zanzibarr/settings/provider_settings.dart';
import 'package:zanzibarr/src/rust/api/download.dart';
import 'metadata_library_test.dart'
    show
        MemoryStorage,
        LocalHistory,
        LocalWatchlist,
        NoUpdate,
        ReadyProvider,
        app;

class FakeDownload extends DownloadBackend {
  int starts = 0, cancels = 0;
  bool cancelled = false, fail = false;
  @override
  Future<BigInt> begin(
    ProviderSettings settings,
    String nzbPath,
    String destination,
  ) async {
    starts++;
    expect(nzbPath, '/sample/movie.nzb');
    expect(destination, '/downloads');
    if (fail) throw StateError('TESTPASS123');
    return BigInt.one;
  }

  @override
  Future<void> cancel(BigInt id) async {
    cancels++;
    cancelled = true;
  }

  @override
  Future<DownloadProgressDto?> progress(BigInt id) async => DownloadProgressDto(
    sessionId: id,
    phase: cancelled ? 'cancelled' : 'downloading',
    completedBytes: BigInt.zero,
    discoveredBytes: BigInt.from(2048),
    completedFiles: 0,
    totalFiles: 2,
    directory: '/downloads/release',
    files: const [],
    error: '',
  );
}

void main() {
  test(
    'local playback uses a file URI and no native stream or cast session',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zanzibarr-local-test-',
      );
      try {
        final file = File('${directory.path}/local video.mkv');
        await file.writeAsBytes([1, 2, 3]);
        final info = await prepareLocalPlayback(file.path);
        expect(Uri.parse(info.url), file.absolute.uri);
        expect(info.size, BigInt.from(3));
        expect(info.sessionId, BigInt.zero);
        expect(info.castUrl, '');
        await expectLater(
          prepareLocalPlayback('${directory.path}/missing.mkv'),
          throwsStateError,
        );
      } finally {
        final file = File('${directory.path}/local video.mkv');
        if (await file.exists()) {
          await file.delete();
        }
        await directory.delete();
      }
    },
  );
  test(
    'overview copy uses film facts rather than spoiler-bearing plot excerpts',
    () {
      const media = MediaTitle(
        imdbId: 'tt1234567',
        title: 'Example',
        year: '2020',
        kind: 'movie',
        genre: 'Drama, Mystery',
        director: 'Alex Ellis',
        actors: 'Jamie Reed, Morgan Vale, Riley Hart',
        plot: 'The killer is revealed and the hero dies.',
      );
      final blurb = filmBlurb(media);
      expect(blurb, contains('directed by Alex Ellis'));
      expect(blurb, contains('Jamie Reed and Morgan Vale'));
      expect(blurb, isNot(contains('killer')));
      expect(blurb, isNot(contains('dies')));
      expect(blurb.length, lessThan(300));
    },
  );
  testWidgets(
    'download requires explicit inputs, reports progress and cancels its own job',
    (tester) async {
      final backend = FakeDownload();
      await tester.pumpWidget(
        app(
          DownloadScreen(
            backend: backend,
            store: ReadyProvider(),
            pickNzb: () async => '/sample/movie.nzb',
            pickFolder: () async => '/downloads',
          ),
        ),
      );
      await tester.tap(find.byTooltip('Choose NZB'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose download folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download all NZB files'));
      await tester.pump();
      await tester.pump();
      expect(backend.starts, 1);
      expect(find.text('downloading: 0/2 files'), findsOneWidget);
      await tester.tap(find.text('Cancel download'));
      await tester.pumpAndSettle();
      expect(backend.cancels, 1);
      expect(find.text('cancelled: 0/2 files'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'download failures retain chosen inputs and sanitize provider errors',
    (tester) async {
      final backend = FakeDownload()..fail = true;
      await tester.pumpWidget(
        app(
          DownloadScreen(
            nzbPath: '/sample/movie.nzb',
            backend: backend,
            store: ReadyProvider(),
            pickFolder: () async => '/downloads',
          ),
        ),
      );
      await tester.tap(find.byTooltip('Choose download folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download all NZB files'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Download could not start'), findsOneWidget);
      expect(find.textContaining('TESTPASS123'), findsNothing);
      expect(find.text('/sample/movie.nzb'), findsOneWidget);
      expect(find.text('/downloads'), findsOneWidget);
    },
  );
  testWidgets(
    'header branding remains fixed while Home scrolls and narrow menus stay accessible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          HomeScreen(
            historyStore: LocalHistory(),
            titleLibraryStore: TitleLibraryStore(storage: MemoryStorage()),
            watchlistStore: LocalWatchlist(),
            providerStore: ReadyProvider(),
            updateService: NoUpdate(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final brand = find.bySemanticsLabel('zanzibarr');
      final before = tester.getTopLeft(brand);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(brand), before);
      expect(before.dy, lessThan(80));
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('My library'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
