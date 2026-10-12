import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/media_preferences.dart';
import 'package:zanzibarr/player/playback_history.dart';

class _MemoryPreferenceStorage implements PlayerPreferenceStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _DelayedPreferenceStorage extends _MemoryPreferenceStorage {
  Completer<void>? nextWrite;
  Completer<void>? writeStarted;
  bool failNextWrite = false;

  @override
  Future<void> write(String key, String value) async {
    final gate = nextWrite;
    nextWrite = null;
    writeStarted?.complete();
    writeStarted = null;
    if (gate != null) await gate.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('test storage write failed');
    }
    await super.write(key, value);
  }
}

void main() {
  PlaybackHistoryEntry entry(
    String path, {
    double position = 120,
    double duration = 6000,
    int updatedAt = 1000,
    String? entryKey,
    String? imdbId,
    int? season,
    int? episode,
    bool favorite = false,
  }) => PlaybackHistoryEntry(
    nzbPath: path,
    entryKey: entryKey,
    title: path.split('/').last,
    positionSeconds: position,
    durationSeconds: duration,
    updatedAtMs: updatedAt,
    imdbId: imdbId,
    season: season,
    episode: episode,
    favorite: favorite,
  );

  test('kayıt eklenip okunabiliyor (round-trip)', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    await store.save(entry('/media/film.nzb', position: 321.5));

    final entries = await store.load();
    expect(entries, hasLength(1));
    expect(entries.single.nzbPath, '/media/film.nzb');
    expect(entries.single.positionSeconds, 321.5);
    expect(entries.single.progress, closeTo(321.5 / 6000, 0.0001));
  });

  test('imdbId/sezon/bölüm round-trip ile korunur', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    await store.save(
      entry(
        '/media/show.s01e02.nzb',
        imdbId: 'tt1234567',
        season: 1,
        episode: 2,
      ),
    );

    final entries = await store.load();
    expect(entries.single.imdbId, 'tt1234567');
    expect(entries.single.season, 1);
    expect(entries.single.episode, 2);
  });

  test('yapılandırılmamış kayıtlarda kimlik alanları null kalır', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    await store.save(entry('/media/random-file.nzb'));

    final entries = await store.load();
    expect(entries.single.imdbId, isNull);
    expect(entries.single.season, isNull);
    expect(entries.single.episode, isNull);
  });

  test(
    'aynı yol yeniden kaydedilince güncellenir, liste kabarık kalmaz',
    () async {
      final storage = _MemoryPreferenceStorage();
      final store = PlaybackHistoryStore(storage: storage);

      await store.save(entry('/media/film.nzb', position: 100, updatedAt: 1));
      await store.save(entry('/media/film.nzb', position: 250, updatedAt: 2));
      await store.save(entry('/media/diger.nzb', position: 50, updatedAt: 3));

      final entries = await store.load();
      expect(entries, hasLength(2));
      // En güncel kayıt başta.
      expect(entries.first.nzbPath, '/media/diger.nzb');
      expect(entries.last.positionSeconds, 250);
    },
  );

  test(
    'izleme sona erdiyse kayıt tamamlandı olarak tutulur (Sıradaki için)',
    () async {
      final storage = _MemoryPreferenceStorage();
      final store = PlaybackHistoryStore(storage: storage);

      await store.save(
        entry('/media/film.nzb', position: 5900, duration: 6000),
      );

      final entries = await store.load();
      expect(entries, hasLength(1));
      expect(entries.single.isCompleted, isTrue);
    },
  );

  test('migratePath konumu koruyarak yeni yola taşır', () async {
    final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
    await store.save(
      entry('/cache/old.nzb', position: 456, entryKey: 'rar:e01'),
    );

    await store.migratePath(
      oldPath: '/cache/old.nzb',
      entryKey: 'rar:e01',
      newPath: '/cache/new.nzb',
    );

    final entries = await store.load();
    expect(entries, hasLength(1));
    expect(entries.single.nzbPath, '/cache/new.nzb');
    expect(entries.single.entryKey, 'rar:e01');
    expect(entries.single.positionSeconds, 456);
  });

  test(
    'migratePath liste doluyken de başka bir kaydı düşürmez',
    () async {
      final storage = _MemoryPreferenceStorage();
      final store = PlaybackHistoryStore(storage: storage);

      await store.save(entry('/cache/vanished.nzb', position: 111));
      for (var i = 1; i < 25; i++) {
        await store.save(entry('/media/other-$i.nzb', updatedAt: i));
      }
      expect(await store.load(), hasLength(25));

      await store.migratePath(
        oldPath: '/cache/vanished.nzb',
        newPath: '/cache/recovered.nzb',
      );

      final entries = await store.load();
      expect(
        entries,
        hasLength(25),
        reason: 'in-place migration must not trigger capacity eviction',
      );
      final migrated = entries.singleWhere(
        (e) => e.nzbPath == '/cache/recovered.nzb',
      );
      expect(migrated.positionSeconds, 111);
    },
  );

  test('setFavorite işareti değiştirir, diğer alanlar korunur', () async {
    final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
    await store.save(entry('/media/film.nzb', position: 42));

    await store.setFavorite('/media/film.nzb', favorite: true);
    var entries = await store.load();
    expect(entries.single.favorite, isTrue);
    expect(entries.single.positionSeconds, 42);

    await store.setFavorite('/media/film.nzb', favorite: false);
    entries = await store.load();
    expect(entries.single.favorite, isFalse);
  });

  test(
    'setCompleted(true) konumu süreye eşitler, süre bilinmiyorsa no-op',
    () async {
      final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
      await store.save(entry('/media/film.nzb', position: 10, duration: 6000));

      await store.setCompleted('/media/film.nzb', completed: true);
      final entries = await store.load();
      expect(entries.single.isCompleted, isTrue);
      expect(entries.single.positionSeconds, 6000);
    },
  );

  test('setCompleted(false) baştan başlatır', () async {
    final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
    await store.save(entry('/media/film.nzb', position: 5900, duration: 6000));

    await store.setCompleted('/media/film.nzb', completed: false);
    final entries = await store.load();
    expect(entries.single.isCompleted, isFalse);
    expect(entries.single.positionSeconds, 0);
  });

  test('setCompleted süre sıfırsa tamamlandı yapamaz', () async {
    final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
    await store.save(entry('/media/film.nzb', position: 0, duration: 0));

    await store.setCompleted('/media/film.nzb', completed: true);
    final entries = await store.load();
    expect(entries.single.isCompleted, isFalse);
  });

  test(
    'favori işaretli tamamlanmış kayıtlar bütçe aşımında silinmez',
    () async {
      final storage = _MemoryPreferenceStorage();
      final store = PlaybackHistoryStore(storage: storage);

      await store.save(
        entry(
          '/media/favorite.nzb',
          position: 5900,
          duration: 6000,
          updatedAt: 0,
          favorite: true,
        ),
      );
      for (var i = 1; i <= 25; i++) {
        await store.save(
          entry(
            '/media/completed-$i.nzb',
            position: 5900,
            duration: 6000,
            updatedAt: i,
          ),
        );
      }

      final entries = await store.load();
      expect(entries, hasLength(25));
      expect(
        entries.any((e) => e.nzbPath == '/media/favorite.nzb'),
        isTrue,
        reason: 'favorited entry must survive eviction ahead of others',
      );
    },
  );

  test(
    'bütçe aşılınca önce en eski tamamlanmış kayıt düşer, devam edilebilir kayıt korunur',
    () async {
      final storage = _MemoryPreferenceStorage();
      final store = PlaybackHistoryStore(storage: storage);

      await store.save(entry('/media/resume.nzb', updatedAt: 0));
      for (var i = 1; i <= 25; i++) {
        await store.save(
          entry(
            '/media/completed-$i.nzb',
            position: 5900,
            duration: 6000,
            updatedAt: i,
          ),
        );
      }

      final entries = await store.load();
      expect(entries, hasLength(25));
      expect(
        entries.any((e) => e.nzbPath == '/media/resume.nzb'),
        isTrue,
        reason: 'resumable entry must survive the trim',
      );
      expect(
        entries.any((e) => e.nzbPath == '/media/completed-1.nzb'),
        isFalse,
        reason: 'oldest completed entry should be evicted first',
      );
    },
  );

  test('liste en güncel 25 kayıtla sınırlı', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    for (var i = 0; i < 30; i++) {
      await store.save(entry('/media/film-$i.nzb', updatedAt: i));
    }

    final entries = await store.load();
    expect(entries, hasLength(25));
    expect(entries.first.nzbPath, '/media/film-29.nzb');
    expect(entries.last.nzbPath, '/media/film-5.nzb');
  });

  test('bozuk JSON boş listeye düşer', () async {
    final storage = _MemoryPreferenceStorage()
      ..values[PlaybackHistoryStore.storageKey] = '{bozuk';
    final store = PlaybackHistoryStore(storage: storage);

    expect(await store.load(), isEmpty);
  });

  test('remove yalnız hedef kaydı siler', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    await store.save(entry('/media/a.nzb', updatedAt: 1));
    await store.save(entry('/media/b.nzb', updatedAt: 2));
    await store.remove('/media/a.nzb');

    final entries = await store.load();
    expect(entries, hasLength(1));
    expect(entries.single.nzbPath, '/media/b.nzb');
  });

  test('entryFor yolu bulur, yoksa null döner', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);
    await store.save(entry('/media/film.nzb'));

    expect((await store.entryFor('/media/film.nzb'))?.positionSeconds, 120);
    expect(await store.entryFor('/media/yok.nzb'), isNull);
  });

  test('aynı NZB’nin bölümleri ayrı kayıt tutar, konumlar karışmaz', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    await store.save(
      entry(
        '/media/paket.nzb',
        position: 100,
        entryKey: 'rar:e01',
        updatedAt: 1,
      ),
    );
    await store.save(
      entry(
        '/media/paket.nzb',
        position: 250,
        entryKey: 'rar:e02',
        updatedAt: 2,
      ),
    );

    expect(await store.load(), hasLength(2));
    expect(
      (await store.entryFor(
        '/media/paket.nzb',
        entryKey: 'rar:e01',
      ))?.positionSeconds,
      100,
    );
    expect(
      (await store.entryFor(
        '/media/paket.nzb',
        entryKey: 'rar:e02',
      ))?.positionSeconds,
      250,
    );
    // Anahtarsız arama bölüm kayıtlarını bulmaz.
    expect(await store.entryFor('/media/paket.nzb'), isNull);
  });

  test('bölüm kaydı eski anahtarsız paket kaydını süpürür', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    // Eski sürümden kalan tüm-paket kaydı, bölüm bazlı ilk kayıtta silinir;
    // yoksa ana ekranda hedefi bulunamayan hayalet bir kart kalırdı.
    await store.save(entry('/media/paket.nzb', position: 300, updatedAt: 1));
    await store.save(
      entry(
        '/media/paket.nzb',
        position: 40,
        entryKey: 'rar:e01',
        updatedAt: 2,
      ),
    );

    final entries = await store.load();
    expect(entries, hasLength(1));
    expect(entries.single.entryKey, 'rar:e01');
  });

  test('remove entryKey ile yalnız o bölümü siler', () async {
    final storage = _MemoryPreferenceStorage();
    final store = PlaybackHistoryStore(storage: storage);

    await store.save(
      entry(
        '/media/paket.nzb',
        position: 100,
        entryKey: 'rar:e01',
        updatedAt: 1,
      ),
    );
    await store.save(
      entry(
        '/media/paket.nzb',
        position: 250,
        entryKey: 'rar:e02',
        updatedAt: 2,
      ),
    );
    await store.remove('/media/paket.nzb', entryKey: 'rar:e01');

    final entries = await store.load();
    expect(entries, hasLength(1));
    expect(entries.single.entryKey, 'rar:e02');
  });

  test(
    'overlapping saves from separate stores preserve both episodes',
    () async {
      final storage = _MemoryPreferenceStorage();
      final player = PlaybackHistoryStore(storage: storage);
      final home = PlaybackHistoryStore(storage: storage);
      await Future.wait([
        player.save(entry('/pack.nzb', entryKey: 'rar:e01', updatedAt: 1)),
        home.save(entry('/pack.nzb', entryKey: 'rar:e02', updatedAt: 2)),
      ]);
      expect(await home.load(), hasLength(2));
    },
  );

  test(
    'final player save cannot restore a subsequently removed card',
    () async {
      final storage = _DelayedPreferenceStorage();
      final player = PlaybackHistoryStore(storage: storage);
      final home = PlaybackHistoryStore(storage: storage);
      await player.save(entry('/film.nzb'));
      final gate = Completer<void>();
      final started = Completer<void>();
      storage.nextWrite = gate;
      storage.writeStarted = started;
      final saving = player.save(
        entry('/film.nzb', position: 500, updatedAt: 2000),
      );
      await started.future;
      final removing = home.remove('/film.nzb');
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([saving, removing]);
      expect(await home.load(), isEmpty);
    },
  );

  test('failed writes do not poison subsequent history operations', () async {
    final storage = _DelayedPreferenceStorage()..failNextWrite = true;
    final store = PlaybackHistoryStore(storage: storage);
    await expectLater(store.save(entry('/failed.nzb')), throwsStateError);
    await store.save(entry('/ok.nzb'));
    expect((await store.load()).single.nzbPath, '/ok.nzb');
  });

  test('older snapshots cannot overwrite newer progress', () async {
    final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
    await store.save(entry('/film.nzb', position: 500, updatedAt: 2000));
    await store.save(entry('/film.nzb', position: 300, updatedAt: 1000));
    expect((await store.load()).single.positionSeconds, 500);
  });

  test(
    'legacy resume migrates only to the resolved video with matching title',
    () async {
      final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
      const legacy = PlaybackHistoryEntry(
        nzbPath: '/pack.nzb',
        title: 'episode01.mkv',
        positionSeconds: 1234,
        durationSeconds: 6000,
        updatedAtMs: 1000,
      );
      await store.save(legacy);
      expect(
        await store.entryFor(
          '/pack.nzb',
          entryKey: 'rar:e02',
          mediaTitle: 'episode02.mkv',
        ),
        isNull,
      );
      final migrated = await store.entryFor(
        '/pack.nzb',
        entryKey: 'rar:e01',
        mediaTitle: 'episode01.mkv',
      );
      expect(migrated?.positionSeconds, 1234);
      expect((await store.load()).single.entryKey, 'rar:e01');
      expect(await store.entryFor('/pack.nzb'), isNull);
    },
  );

  test(
    'watching another episode preserves the unmatched legacy resume',
    () async {
      final store = PlaybackHistoryStore(storage: _MemoryPreferenceStorage());
      await store.save(
        const PlaybackHistoryEntry(
          nzbPath: '/pack.nzb',
          title: 'episode01.mkv',
          positionSeconds: 1234,
          durationSeconds: 6000,
          updatedAtMs: 1000,
        ),
      );
      await store.save(
        const PlaybackHistoryEntry(
          nzbPath: '/pack.nzb',
          entryKey: 'rar:e02',
          title: 'episode02.mkv',
          positionSeconds: 120,
          durationSeconds: 6000,
          updatedAtMs: 2000,
        ),
      );
      expect(await store.load(), hasLength(2));
      expect((await store.entryFor('/pack.nzb'))?.positionSeconds, 1234);
    },
  );
}
