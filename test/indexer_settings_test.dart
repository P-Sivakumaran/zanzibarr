import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanzibarr/settings/indexer_settings.dart';
import 'package:zanzibarr/settings/provider_settings.dart';
import 'package:zanzibarr/settings/settings_screen.dart';
import 'package:zanzibarr/src/rust/api/search.dart';

import 'l10n_test_helper.dart';

/// Secure storage method channel'ını bellek içi haritayla taklit eder;
/// böylece [IndexerSettingsStore] gerçek kod yoluyla sınanır.
const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
final _memoryStorage = <String, String>{};

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return _memoryStorage[key];
          case 'write':
            _memoryStorage[key!] = args['value'] as String;
            return null;
          case 'delete':
            _memoryStorage.remove(key);
            return null;
          case 'deleteAll':
            _memoryStorage.clear();
            return null;
        }
        return null;
      });
}

/// Ayar ekranı testlerinde gerçek secure storage yerine bellek içi sahte depo.
class _FakeIndexerStore extends IndexerSettingsStore {
  List<IndexerProfile> saved = const [];
  bool failSave = false;

  @override
  Future<List<IndexerProfile>> load() async => saved;

  @override
  Future<void> save(List<IndexerProfile> profiles) async {
    if (failSave) throw StateError('write failed');
    saved = profiles;
  }
}

/// NNTP bölümü de ekran açılışında depo okur; kanala düşmemesi için sahte.
class _FakeProviderStore extends ProviderSettingsStore {
  @override
  Future<ProviderSettings> load() async => const ProviderSettings();
}

/// ListView tembel kurulduğundan alt bölümler ancak kaydırınca ağaca girer;
/// scrollUntilVisible cacheExtent'te durabildiği için ensureVisible ile
/// öğe tamamen görünür alana çekilir ve sonraki tap'in doğru koordinatı
/// görmesi için settle edilir. (Metin alanları da Scrollable taşıdığı için
/// en dıştaki seçilir.)
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final section in <SettingsSection?>[
    null,
    SettingsSection.provider,
    SettingsSection.indexer,
  ]) {
    testWidgets(
      'MCP and AI are visible in ${section?.name ?? 'full'} settings',
      (tester) async {
        await tester.pumpWidget(
          l10nTestApp(
            SettingsScreen(
              store: _FakeProviderStore(),
              indexerStore: _FakeIndexerStore(),
              initialSection: section,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('settings-integrations'));
        expect(action.hitTestable(), findsOneWidget);
        expect(find.text('MCP & AI').hitTestable(), findsOneWidget);
        expect(tester.widget<TextButton>(action).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('IndexerSettingsStore', () {
    setUp(() {
      _memoryStorage.clear();
      _mockSecureStorage();
    });

    test('Boş depoda boş liste döner', () async {
      final profiles = await IndexerSettingsStore().load();
      expect(profiles, isEmpty);
    });

    test('corrupt storage is reported and preserved', () async {
      _memoryStorage['indexer.profiles.v2'] = 'corrupt';
      await expectLater(IndexerSettingsStore().load(), throwsFormatException);
      expect(_memoryStorage['indexer.profiles.v2'], 'corrupt');
    });

    test('Kaydedilen profiller geri okunur', () async {
      final store = IndexerSettingsStore();
      await store.save(const [
        IndexerProfile(
          id: '1',
          nickname: 'NZBFinder',
          baseUrl: 'https://indexer.example',
          apiKey: 'gizli-anahtar',
        ),
      ]);
      final profiles = await store.load();
      expect(profiles, hasLength(1));
      expect(profiles.single.nickname, 'NZBFinder');
      expect(profiles.single.baseUrl, 'https://indexer.example');
      expect(profiles.single.apiKey, 'gizli-anahtar');
      expect(profiles.single.isComplete, isTrue);
    });

    test('Birden çok profil sırasıyla korunur', () async {
      final store = IndexerSettingsStore();
      const profiles = [
        IndexerProfile(id: 'a', baseUrl: 'https://a.example', apiKey: 'ka'),
        IndexerProfile(id: 'b', baseUrl: 'https://b.example', apiKey: 'kb'),
      ];
      await store.save(profiles);
      final loaded = await store.load();
      expect(loaded.map((p) => p.id), ['a', 'b']);
    });

    test('clear tüm profilleri siler', () async {
      final store = IndexerSettingsStore();
      await store.save(const [
        IndexerProfile(
          id: '1',
          baseUrl: 'https://indexer.example',
          apiKey: 'k',
        ),
      ]);
      await store.clear();
      final profiles = await store.load();
      expect(profiles, isEmpty);
    });

    test('isComplete yalnızca URL ve anahtar doluyken true olur', () {
      expect(const IndexerProfile(id: '1').isComplete, isFalse);
      expect(
        const IndexerProfile(id: '1', baseUrl: 'https://x.example').isComplete,
        isFalse,
      );
      expect(const IndexerProfile(id: '1', apiKey: 'k').isComplete, isFalse);
      expect(
        const IndexerProfile(
          id: '1',
          baseUrl: 'https://x.example',
          apiKey: 'k',
        ).isComplete,
        isTrue,
      );
    });

    test('displayName nickname yoksa base URL\'e düşer', () {
      expect(
        const IndexerProfile(id: '1', baseUrl: 'https://x.example').displayName,
        'https://x.example',
      );
      expect(
        const IndexerProfile(
          id: '1',
          nickname: 'My Indexer',
          baseUrl: 'https://x.example',
        ).displayName,
        'My Indexer',
      );
    });

    test('Eski tek-indexer kaydı tek profile göç eder', () async {
      // Eski biçimin kullandığı ham anahtarları doğrudan belleğe yaz.
      _memoryStorage['indexer.baseUrl'] = 'https://legacy.example';
      _memoryStorage['indexer.apiKey'] = 'eski-anahtar';
      _memoryStorage['indexer.nickname'] = 'Legacy';

      final store = IndexerSettingsStore();
      final profiles = await store.load();

      expect(profiles, hasLength(1));
      expect(profiles.single.baseUrl, 'https://legacy.example');
      expect(profiles.single.apiKey, 'eski-anahtar');
      expect(profiles.single.nickname, 'Legacy');
      // Eski anahtarlar temizlenmiş olmalı.
      expect(_memoryStorage.containsKey('indexer.baseUrl'), isFalse);
      expect(_memoryStorage.containsKey('indexer.apiKey'), isFalse);

      // İkinci okuma yeni biçimden gelir, göç tekrarlanmaz.
      final reloaded = await store.load();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.baseUrl, 'https://legacy.example');
    });
  });

  group('SettingsScreen indexer bölümü', () {
    testWidgets('failed profile save retains draft and cancel protects edits', (
      tester,
    ) async {
      final store = _FakeIndexerStore()..failSave = true;
      await tester.pumpWithL10n(
        SettingsScreen(
          store: _FakeProviderStore(),
          indexerStore: store,
          initialSection: SettingsSection.indexer,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indexer ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'NZBFinder'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API anahtarı'),
        'TESTPASS123',
      );
      await tester.tap(find.text("Indexer'ı kaydet"));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('https://nzbfinder.ws'), findsOneWidget);
      expect(store.saved, isEmpty);
      await tester.tap(
        find.widgetWithText(
          TextButton,
          MaterialLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          ).cancelButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNWidgets(2));
      await tester.tap(find.text('Düzenlemeye devam et'));
      await tester.pumpAndSettle();
      store.failSave = false;
      await tester.tap(find.text("Indexer'ı kaydet"));
      await tester.pumpAndSettle();
      expect(store.saved.single.apiKey, 'TESTPASS123');
      expect(store.saved.single.nickname, 'NZBFinder');
    });

    testWidgets('profile order persists through keyboard accessible controls', (
      tester,
    ) async {
      final store = _FakeIndexerStore()
        ..saved = const [
          IndexerProfile(id: 'a', nickname: 'First'),
          IndexerProfile(id: 'b', nickname: 'Second'),
        ];
      await tester.pumpWithL10n(
        SettingsScreen(
          store: _FakeProviderStore(),
          indexerStore: store,
          initialSection: SettingsSection.indexer,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Indexer'ı yukarı taşı").last);
      await tester.pumpAndSettle();
      expect(store.saved.map((p) => p.id), ['b', 'a']);
    });
    testWidgets('Boşken ekleme düğmesi görünür, diyalogla profil eklenir', (
      tester,
    ) async {
      final store = _FakeIndexerStore();
      await tester.pumpWithL10n(
        SettingsScreen(store: _FakeProviderStore(), indexerStore: store),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.text('Indexer (Newznab)'));
      await tester.pumpAndSettle();
      expect(find.text('Indexer (Newznab)'), findsOneWidget);

      await _reveal(tester, find.text("Indexer ekle"));
      await tester.tap(find.text("Indexer ekle"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, "Indexer URL'si"),
        'https://indexer.example',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API anahtarı'),
        'cok-gizli',
      );
      await tester.tap(find.text("Indexer'ı kaydet"));
      await tester.pumpAndSettle();

      expect(store.saved, hasLength(1));
      expect(store.saved.single.baseUrl, 'https://indexer.example');
      expect(store.saved.single.apiKey, 'cok-gizli');
      expect(store.saved.single.isComplete, isTrue);
    });

    testWidgets('Geçersiz URL kaydı engelliyor', (tester) async {
      final store = _FakeIndexerStore();
      await tester.pumpWithL10n(
        SettingsScreen(store: _FakeProviderStore(), indexerStore: store),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.text("Indexer ekle"));
      await tester.tap(find.text("Indexer ekle"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, "Indexer URL'si"),
        'ftp://indexer.example',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API anahtarı'),
        'anahtar',
      );
      await tester.tap(find.text("Indexer'ı kaydet"));
      await tester.pumpAndSettle();

      expect(
        find.text('http:// veya https:// ile başlayan geçerli bir URL girin'),
        findsOneWidget,
      );
      expect(store.saved, isEmpty);
    });

    testWidgets('URL doluyken API anahtarı zorunlu', (tester) async {
      final store = _FakeIndexerStore();
      await tester.pumpWithL10n(
        SettingsScreen(store: _FakeProviderStore(), indexerStore: store),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.text("Indexer ekle"));
      await tester.tap(find.text("Indexer ekle"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, "Indexer URL'si"),
        'https://indexer.example',
      );
      await tester.tap(find.text("Indexer'ı kaydet"));
      await tester.pumpAndSettle();

      expect(find.text('API anahtarı gerekli'), findsOneWidget);
      expect(store.saved, isEmpty);
    });

    testWidgets('Bağlantıyı sına caps sonucunu gösterir', (tester) async {
      final store = _FakeIndexerStore();
      IndexerConfigDto? capsConfig;
      await tester.pumpWithL10n(
        SettingsScreen(
          store: _FakeProviderStore(),
          indexerStore: store,
          capsFn: (config) async {
            capsConfig = config;
            return const IndexerCapsDto(
              serverTitle: 'Miatrix',
              searchAvailable: true,
              tvSearchAvailable: true,
              movieSearchAvailable: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.text("Indexer ekle"));
      await tester.tap(find.text("Indexer ekle"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, "Indexer URL'si"),
        'https://indexer.example',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API anahtarı'),
        'anahtar',
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Bağlantıyı sına').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Bağlantıyı sına').last,
      );
      await tester.pumpAndSettle();

      expect(capsConfig?.baseUrl, 'https://indexer.example');
      expect(find.text('Bağlandı: Miatrix'), findsOneWidget);
    });

    testWidgets(
      'Mevcut profil listede görünür ve açık/kapalı değiştirilebilir',
      (tester) async {
        final store = _FakeIndexerStore()
          ..saved = const [
            IndexerProfile(
              id: '1',
              nickname: 'NZBFinder',
              baseUrl: 'https://indexer.example',
              apiKey: 'k',
            ),
          ];
        await tester.pumpWithL10n(
          SettingsScreen(store: _FakeProviderStore(), indexerStore: store),
        );
        await tester.pumpAndSettle();

        await _reveal(tester, find.text('NZBFinder'));
        expect(find.text('NZBFinder'), findsOneWidget);

        final toggle = find.byType(Switch);
        await _reveal(tester, toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(store.saved.single.enabled, isFalse);
      },
    );

    testWidgets('Profil düzenleme diyaloğundan silinebilir', (tester) async {
      final store = _FakeIndexerStore()
        ..saved = const [
          IndexerProfile(
            id: '1',
            nickname: 'NZBFinder',
            baseUrl: 'https://indexer.example',
            apiKey: 'k',
          ),
        ];
      await tester.pumpWithL10n(
        SettingsScreen(store: _FakeProviderStore(), indexerStore: store),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.text('NZBFinder'));
      await tester.tap(find.text('NZBFinder'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      // Onay diyaloğu.
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();

      expect(store.saved, isEmpty);
    });
  });
}
