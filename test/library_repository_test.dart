import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/player/library_repository.dart';
import 'package:zanzibarr/player/media_preferences.dart';

class MemoryStorage implements PlayerPreferenceStorage {
  final values = <String, String>{};
  String? failingKey;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (key == failingKey) throw StateError('storage');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  late MemoryStorage storage;
  late LibraryRepository<int> repository;
  setUp(() {
    storage = MemoryStorage();
    repository = SecureJsonLibraryRepository<int>(
      storage: storage,
      key: 'history',
      decode: (row) => row is Map && row['id'] is int ? row['id'] as int : null,
      encode: (id) => {'id': id},
    );
  });
  test(
    'corrupt latest data recovers previous and preserves damaged bytes',
    () async {
      await repository.write([1]);
      await repository.write([2]);
      storage.values['history'] = 'broken';
      expect(await repository.read(), [1]);
      expect(storage.values['history.damaged'], 'broken');
      expect(await repository.read(), [1]);
    },
  );
  test('failed update preserves last complete snapshot', () async {
    await repository.write([1]);
    storage.failingKey = 'history';
    await expectLater(repository.write([2]), throwsStateError);
    expect(await repository.read(), [1]);
  });
  test(
    'corruption without backup cannot silently become an empty library',
    () async {
      storage.values['history'] = 'broken';
      await expectLater(
        repository.read(),
        throwsA(isA<LibraryStorageException>()),
      );
      await expectLater(
        repository.write([2]),
        throwsA(isA<LibraryStorageException>()),
      );
      expect(storage.values['history'], 'broken');
    },
  );
  test('newer schemas are never downgraded using an older backup', () async {
    await repository.write([1]);
    await repository.write([2]);
    storage.values['history'] = '{"version":99,"entries":[]}';
    await expectLater(
      repository.read(),
      throwsA(isA<UnsupportedLibrarySchema>()),
    );
    expect(storage.values['history'], contains('99'));
  });
  test('explicit deletion purges retained private snapshots', () async {
    await repository.write([1]);
    await repository.write([2]);
    storage.values['history.damaged'] = 'private old record';
    await repository.write([], forgetPrevious: true);
    expect(await repository.read(), isEmpty);
    expect(storage.values.containsKey('history.last-good'), false);
    expect(storage.values.containsKey('history.damaged'), false);
  });
  test('explicit clear cannot revive the previous library', () async {
    await repository.write([1]);
    await repository.write([2]);
    await repository.clear();
    expect(await repository.read(), isEmpty);
    expect(storage.values.containsKey('history.last-good'), false);
  });
}
