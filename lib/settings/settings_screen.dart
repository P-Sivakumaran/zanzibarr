import 'language_settings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../integrations/integrations_screen.dart';
import '../l10n/app_localizations.dart';
import '../src/rust/api/search.dart';
import '../src/rust/api/streaming.dart';
import '../tv_focus.dart';
import '../ui/app_background.dart';
import 'indexer_settings.dart';
import '../ui/error_feedback.dart';
import 'provider_settings.dart';
import 'ui_preferences.dart';

/// FRB `newznabCheckCaps` imzası; testlerde sahte enjekte edilebilir.
typedef NewznabCapsFn =
    Future<IndexerCapsDto> Function(IndexerConfigDto config);

/// Sağlayıcı (NNTP) kimlik bilgileri için ayar ekranı.
///
/// Değerler OS secure storage'a yazılır; ekran açılışında oradan okunur.
enum SettingsSection { provider, indexer }

typedef ProviderCheckFn = Future<void> Function(ProviderSettings settings);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.store,
    this.uiPreferences,
    this.indexerStore,
    this.capsFn,
    this.providerCheckFn,
    this.initialSection,
    this.finishOnSave = false,
    this.onCheckForUpdates,
  });

  /// Testlerde sahte depo enjekte edebilmek için; null ise gerçek depo kullanılır.
  final ProviderSettingsStore? store;

  /// Dil/görünüm seçicileri için; null ise "Uygulama" bölümü gösterilmez.
  final UiPreferencesController? uiPreferences;

  /// Indexer (Newznab) ayarları için; null ise gerçek depo kullanılır.
  final IndexerSettingsStore? indexerStore;

  /// "Bağlantıyı sına" düğmesinin çağırdığı caps sorgusu; null ise FRB
  /// `newznabCheckCaps` kullanılır.
  final NewznabCapsFn? capsFn;
  final ProviderCheckFn? providerCheckFn;
  final SettingsSection? initialSection;
  final bool finishOnSave;
  final Future<void> Function()? onCheckForUpdates;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final ProviderSettingsStore _store =
      widget.store ?? ProviderSettingsStore();
  late final IndexerSettingsStore _indexerStore =
      widget.indexerStore ?? IndexerSettingsStore();
  late final NewznabCapsFn _capsFn =
      widget.capsFn ?? (config) => newznabCheckCaps(config: config);

  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _maxConnectionsController = TextEditingController();
  final _backFocusNode = FocusNode();
  late final _languageFocusNode = FocusNode(
    onKeyEvent: (node, event) {
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Keep the first control's exit stable as app-bar actions change width.
        _backFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  // TV kumandasında yukarı/aşağı oklar alandan çıkabilsin diye D-pad
  // gezintili odak düğümleri (issue #4). Parola/API anahtarı alanlarının
  // göz simgeleri `skipTraversal` ile yön gezintisinden çıkarılmıştır —
  // aksi halde aşağı ok bir üst alandan inerken alanı atlayıp simgeye
  // düşüyordu (simge dikeyde alanın metin bölgesinden daha yüksekte).
  // Simgelere yalnızca alanın metin sonundan sağ okla geçilir.
  late final _hostFocusNode = dpadTraversalFocusNode(_hostController);
  late final _portFocusNode = dpadTraversalFocusNode(_portController);
  late final _maxConnectionsFocusNode = dpadTraversalFocusNode(
    _maxConnectionsController,
  );
  late final _usernameFocusNode = dpadTraversalFocusNode(_usernameController);
  late final FocusNode _passwordFocusNode = dpadTraversalFocusNode(
    _passwordController,
    focusOnRightEdge: () => _passwordEyeFocusNode,
  );
  late final FocusNode _passwordEyeFocusNode = dpadFieldActionFocusNode(
    controller: _passwordController,
    fieldNode: _passwordFocusNode,
  );

  List<String>? _providerBaseline;
  bool _allowPop = false;
  bool _confirmingLeave = false;
  bool _testingProvider = false;
  bool _checkingUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      await widget.onCheckForUpdates?.call();
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  List<IndexerProfile> _profiles = [];
  bool _profilesLoading = true;
  bool _profilesLoadFailed = false;
  final _loadTimers = <Timer>{};

  Future<T> _loadWithTimeout<T>(Future<T> future) async {
    final expired = Completer<T>();
    final timer = Timer(
      const Duration(seconds: 10),
      () => expired.completeError(TimeoutException('Settings load timed out')),
    );
    _loadTimers.add(timer);
    try {
      return await Future.any([future, expired.future]);
    } finally {
      timer.cancel();
      _loadTimers.remove(timer);
    }
  }

  String? _providerTestMessage;
  bool _providerTestPassed = false;

  List<TextEditingController> get _providerControllers => [
    _hostController,
    _portController,
    _usernameController,
    _passwordController,
    _maxConnectionsController,
  ];
  List<String> _values(List<TextEditingController> controllers) => [
    for (final controller in controllers) controller.text,
  ];
  bool _different(
    List<String>? baseline,
    List<TextEditingController> controllers,
  ) => baseline != null && !listEquals(baseline, _values(controllers));
  bool get _providerDirty =>
      widget.initialSection != SettingsSection.indexer &&
      _different(_providerBaseline, _providerControllers);
  // Indexer profilleri liste/diyalog akışıyla anında kaydedilir; ertelenmiş
  // "kirli" durumu yok, bu yüzden genel kirlilik yalnızca NNTP formuna bakar.
  bool get _dirty => _providerDirty;

  List<String>? _lastValues;

  void _changed() {
    final values = _values(_providerControllers);
    if (listEquals(values, _lastValues)) return;
    _lastValues = values;
    if (mounted) {
      setState(() {
        _providerTestMessage = null;
      });
    }
  }

  Future<void> _leave() async {
    if (_confirmingLeave || _saving) return;
    var savedOnLeave = false;
    if (_dirty) {
      _confirmingLeave = true;
      final l10n = AppLocalizations.of(context);
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.unsavedTitle),
          content: Text(l10n.unsavedHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: Text(l10n.keepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: Text(l10n.discardChanges),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(l10n.saveChanges),
            ),
          ],
        ),
      );
      _confirmingLeave = false;
      if (!mounted || action == null || action == 'keep') return;
      if (action == 'save') {
        if (_providerDirty) await _save(finish: false);
        if (!mounted || _dirty) return;
        savedOnLeave = true;
      }
    }
    if (!mounted) return;
    final completedSetup = widget.finishOnSave && savedOnLeave;
    setState(() => _allowPop = true);
    // Wait for PopScope to register the updated permission before popping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(completedSetup ? true : null);
    });
  }

  Future<void> _finishSetup() async {
    if (!widget.finishOnSave || _confirmingLeave || !mounted || _dirty) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  ProviderSettings _providerValues() => ProviderSettings(
    host: _hostController.text.trim(),
    port: int.parse(_portController.text.trim()),
    username: _usernameController.text.trim(),
    password: _passwordController.text,
    maxConnections: int.parse(_maxConnectionsController.text.trim()),
  );

  bool _validate(FormState form) {
    final invalid = form.validateGranularly();
    if (invalid.isEmpty) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && invalid.first.mounted) {
        Scrollable.ensureVisible(
          invalid.first.context,
          duration: const Duration(milliseconds: 200),
          alignment: 0.2,
        );
      }
    });
    return false;
  }

  Future<void> _testProvider() async {
    if (_testingProvider || !_validate(_formKey.currentState!)) return;
    final settings = _providerValues();
    final testedValues = _values(_providerControllers);
    setState(() {
      _testingProvider = true;
      _obscurePassword = true;
      _providerTestMessage = null;
    });
    try {
      final check = widget.providerCheckFn;
      if (check != null) {
        await check(settings);
      } else {
        await checkProvider(
          config: ProviderConfigDto(
            host: settings.host,
            port: settings.port,
            username: settings.username,
            password: settings.password,
            maxConnections: 1,
          ),
        );
      }
      if (!mounted ||
          !listEquals(testedValues, _values(_providerControllers))) {
        return;
      }
      setState(() {
        _providerTestPassed = true;
        _providerTestMessage = AppLocalizations.of(context).providerTestSuccess;
      });
    } catch (error) {
      if (!mounted ||
          !listEquals(testedValues, _values(_providerControllers))) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      final text = error.toString();
      setState(() {
        _providerTestPassed = false;
        _providerTestMessage = text.contains('authentication failed')
            ? l10n.errAuthFailed
            : text.contains('connection limit')
            ? l10n.errProviderConnectionLimit
            : l10n.providerTestFailed;
      });
    } finally {
      if (mounted) setState(() => _testingProvider = false);
    }
  }

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final controller in _providerControllers) {
      controller.addListener(_changed);
    }
    if (widget.initialSection != SettingsSection.indexer) {
      _load();
    } else {
      _loading = false;
    }
    if (widget.initialSection != SettingsSection.provider) {
      _loadProfiles();
    } else {
      _profilesLoading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      if (!_obscurePassword) {
        setState(() {
          _obscurePassword = true;
        });
      }
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final settings = await _loadWithTimeout(_store.load());
      if (!mounted) return;
      setState(() {
        _hostController.text = settings.host;
        _portController.text = settings.port.toString();
        _usernameController.text = settings.username;
        _passwordController.text = settings.password;
        _maxConnectionsController.text = settings.maxConnections.toString();
        _providerBaseline = _values(_providerControllers);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  /// Indexer okuması NNTP'den bağımsızdır: depo okunamazsa (veya hiç
  /// tamamlanamazsa) NNTP formu kilitlenmesin, profil listesi boş kalsın.
  Future<void> _loadProfiles() async {
    if (mounted) {
      setState(() {
        _profilesLoading = true;
        _profilesLoadFailed = false;
      });
    }
    try {
      final profiles = await _loadWithTimeout(_indexerStore.load());
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _profilesLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _profilesLoading = false;
          _profilesLoadFailed = true;
        });
      }
    }
  }

  bool _profilesSaving = false;
  Future<void> _persistProfiles(List<IndexerProfile> profiles) async {
    setState(() => _profilesSaving = true);
    try {
      await _indexerStore.save(profiles);
      if (!mounted) return;
      setState(() => _profiles = profiles);
    } finally {
      if (mounted) setState(() => _profilesSaving = false);
    }
  }

  Future<void> _openIndexerDialog({IndexerProfile? editing}) async {
    if (_profilesSaving) return;
    final result = await showDialog<_IndexerDialogResult>(
      context: context,
      builder: (context) => _IndexerProfileDialog(
        profile: editing,
        capsFn: _capsFn,
        onSave: (profile) async {
          await _persistProfiles([
            for (final p in _profiles)
              if (p.id == profile.id) profile else p,
            if (editing == null) profile,
          ]);
        },
      ),
    );
    if (result == null) return;
    if (!result.delete) {
      _finishSetup();
      return;
    }
    final updated = [..._profiles]..removeWhere((p) => p.id == editing?.id);
    try {
      await _persistProfiles(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsWriteHint),
          ),
        );
      }
    }
  }

  Future<void> _toggleProfile(IndexerProfile profile, bool enabled) async {
    if (_profilesSaving) return;
    final updated = [
      for (final p in _profiles)
        if (p.id == profile.id) p.copyWith(enabled: enabled) else p,
    ];
    try {
      await _persistProfiles(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsWriteHint),
          ),
        );
      }
    }
  }

  Future<void> _moveProfile(int index, int delta) async {
    if (_profilesSaving) return;
    final updated = [..._profiles];
    final profile = updated.removeAt(index);
    updated.insert(index + delta, profile);
    try {
      await _persistProfiles(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsWriteHint),
          ),
        );
      }
    }
  }

  Future<void> _save({bool finish = true}) async {
    if (_saving) return;
    if (!_validate(_formKey.currentState!)) return;
    final savedValues = _values(_providerControllers);
    setState(() {
      _saving = true;
      _obscurePassword = true;
    });
    var saved = false;
    try {
      await _store.save(
        ProviderSettings(
          host: _hostController.text.trim(),
          port: int.parse(_portController.text.trim()),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          maxConnections: int.parse(_maxConnectionsController.text.trim()),
        ),
      );
      _providerBaseline = savedValues;
      saved = true;
    } catch (e) {
      // Keychain yazımı başarısızsa (ör. entitlement eksik) uygulamayı
      // düşürmeden kullanıcıya bildir.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsWriteHint)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
    );
    if (finish) await _finishSetup();
  }

  String? _validateIntegerRange(
    String? value,
    String fieldName,
    int minimum,
    int maximum,
  ) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < minimum || parsed > maximum) {
      return AppLocalizations.of(
        context,
      ).validationIntegerRange(fieldName, minimum, maximum);
    }
    return null;
  }

  String? _required(String? value, String fieldName) =>
      value == null || value.trim().isEmpty
      ? AppLocalizations.of(context).validationRequired(fieldName)
      : null;

  String? _validateHost(String? value) {
    final l10n = AppLocalizations.of(context);
    final host = value?.trim() ?? '';
    if (host.isEmpty) return l10n.validationRequired(l10n.serverAddressLabel);
    if (host.length > 253 ||
        host.contains(RegExp(r'\s')) ||
        host.contains('://') ||
        host.contains(RegExp(r'[/@?#:]'))) {
      return l10n.validationHostNoProtocol;
    }
    final hostname = RegExp(
      r'^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)'
      r'(?:\.(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*\.?$',
    );
    if (!hostname.hasMatch(host)) return l10n.validationHostInvalid;
    return null;
  }

  Widget _portField() => TextFormField(
    controller: _portController,
    focusNode: _portFocusNode,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).portLabel,
      hintText: '563',
    ),
    textInputAction: TextInputAction.next,
    keyboardType: TextInputType.number,
    validator: (value) => _validateIntegerRange(
      value,
      AppLocalizations.of(context).portLabel,
      1,
      65535,
    ),
  );

  Widget _connectionField() => TextFormField(
    controller: _maxConnectionsController,
    focusNode: _maxConnectionsFocusNode,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).connectionLimitLabel,
      hintText: AppLocalizations.of(context).connectionLimitHint,
    ),
    textInputAction: TextInputAction.next,
    keyboardType: TextInputType.number,
    validator: (value) => _validateIntegerRange(
      value,
      AppLocalizations.of(context).connectionLimitLabel,
      1,
      60,
    ),
  );

  @override
  void dispose() {
    for (final timer in _loadTimers) {
      timer.cancel();
    }
    for (final controller in _providerControllers) {
      controller.removeListener(_changed);
    }
    WidgetsBinding.instance.removeObserver(this);
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController
      ..clear()
      ..dispose();
    _maxConnectionsController.dispose();
    _backFocusNode.dispose();
    _languageFocusNode.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    _maxConnectionsFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _passwordEyeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            focusNode: _backFocusNode,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
            tooltip: l10n.backTooltip,
            onPressed: _leave,
          ),
          actions: [
            TextButton.icon(
              key: const Key('settings-integrations'),
              icon: const Icon(Icons.extension_outlined),
              label: const Text('MCP & AI'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IntegrationsScreen(),
                ),
              ),
            ),
          ],
          title: Text(
            widget.initialSection == SettingsSection.provider
                ? l10n.providerSetupTitle
                : l10n.settingsTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        body: AppBackground(
          child: SafeArea(
            child: _loading && widget.initialSection != SettingsSection.indexer
                ? const Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _loadError != null &&
                      widget.initialSection != SettingsSection.indexer
                ? _SettingsLoadError(error: _loadError!, onRetry: _load)
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                          children: [
                            if (widget.initialSection == null &&
                                widget.onCheckForUpdates != null) ...[
                              OutlinedButton.icon(
                                onPressed: _checkingUpdates
                                    ? null
                                    : _checkForUpdates,
                                icon: const Icon(Icons.system_update_alt),
                                label: Text(
                                  _checkingUpdates
                                      ? 'Checking for updates…'
                                      : 'Check for updates',
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (widget.initialSection == null)
                              if (widget.uiPreferences case final prefs?) ...[
                                Text(
                                  l10n.appSectionTitle,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.35,
                                      ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  l10n.appearanceSavedHint,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.72),
                                        height: 1.4,
                                      ),
                                ),
                                const SizedBox(height: 24),
                                _SettingsCard(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  LanguageSettingsScreen(
                                                    uiPreferences: prefs,
                                                  ),
                                            ),
                                          ),
                                      icon: const Icon(Icons.translate),
                                      label: const Text(
                                        'Language & region / media languages',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<Locale>(
                                      focusNode: _languageFocusNode,
                                      isExpanded: true,
                                      initialValue: prefs.locale,
                                      // TV kumandasında D-pad gezintisi bu ilk
                                      // kontrolden başlar (metin alanı olmadığı için
                                      // girişte ekran klavyesi açılmaz).
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        labelText: l10n.languageLabel,
                                        prefixIcon: const Icon(
                                          Icons.language_rounded,
                                          size: 19,
                                        ),
                                      ),
                                      items: [
                                        for (final (locale, name)
                                            in supportedAppLocales)
                                          DropdownMenuItem(
                                            value: locale,
                                            child: Text(name),
                                          ),
                                      ],
                                      onChanged: (locale) {
                                        if (locale != null) {
                                          prefs.setLocale(locale);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        l10n.themeLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.72),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child:
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(14) >
                                              20
                                          ? DropdownButtonFormField<ThemeMode>(
                                              isExpanded: true,
                                              initialValue: prefs.themeMode,
                                              decoration: InputDecoration(
                                                labelText: l10n.themeLabel,
                                              ),
                                              items: [
                                                DropdownMenuItem(
                                                  value: ThemeMode.dark,
                                                  child: Text(l10n.themeDark),
                                                ),
                                                DropdownMenuItem(
                                                  value: ThemeMode.light,
                                                  child: Text(l10n.themeLight),
                                                ),
                                              ],
                                              onChanged: (mode) {
                                                if (mode != null) {
                                                  prefs.setThemeMode(mode);
                                                }
                                              },
                                            )
                                          : SegmentedButton<ThemeMode>(
                                              showSelectedIcon: false,
                                              segments: [
                                                ButtonSegment(
                                                  value: ThemeMode.dark,
                                                  icon: const Icon(
                                                    Icons.dark_mode_rounded,
                                                    size: 17,
                                                  ),
                                                  label: Text(l10n.themeDark),
                                                ),
                                                ButtonSegment(
                                                  value: ThemeMode.light,
                                                  icon: const Icon(
                                                    Icons.light_mode_rounded,
                                                    size: 17,
                                                  ),
                                                  label: Text(l10n.themeLight),
                                                ),
                                              ],
                                              selected: {prefs.themeMode},
                                              onSelectionChanged: (selection) =>
                                                  prefs.setThemeMode(
                                                    selection.first,
                                                  ),
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                              ],
                            if (widget.initialSection !=
                                SettingsSection.indexer) ...[
                              if (widget.initialSection ==
                                  SettingsSection.provider) ...[
                                Text(
                                  l10n.providerSetupHint,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 20),
                              ],
                              Text(
                                l10n.nntpSectionTitle,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.35,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                l10n.nntpSectionSubtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.72),
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              _SettingsCard(
                                children: [
                                  TextFormField(
                                    controller: _hostController,
                                    focusNode: _hostFocusNode,
                                    // Uygulama bölümü yoksa (arama ekranından eski
                                    // yol) ilk kontrol bu alan; TV'de D-pad gezintisi
                                    // buradan başlar.
                                    autofocus:
                                        widget.initialSection ==
                                            SettingsSection.provider ||
                                        widget.uiPreferences == null,
                                    decoration: InputDecoration(
                                      labelText: l10n.serverAddressLabel,
                                      hintText: 'news.example.com',
                                      prefixIcon: const Icon(
                                        Icons.dns_rounded,
                                        size: 19,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.url,
                                    autocorrect: false,
                                    validator: _validateHost,
                                  ),
                                  const SizedBox(height: 12),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth < 440) {
                                        return Column(
                                          children: [
                                            _portField(),
                                            const SizedBox(height: 12),
                                            _connectionField(),
                                          ],
                                        );
                                      }
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: _portField()),
                                          const SizedBox(width: 12),
                                          Expanded(child: _connectionField()),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SettingsCard(
                                children: [
                                  TextFormField(
                                    controller: _usernameController,
                                    focusNode: _usernameFocusNode,
                                    decoration: InputDecoration(
                                      labelText: l10n.usernameLabel,
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 19,
                                      ),
                                    ),
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    validator: (value) =>
                                        _required(value, l10n.usernameLabel),
                                  ),
                                  const SizedBox(height: 12),
                                  // Göz düğmesi alanın İÇİNDE değil yanında durur ve
                                  // skipTraversal ile yön gezintisi adaylığından
                                  // çıkarılmıştır: aşağı ok bu satıra inerken her
                                  // zaman alanı seçer; simgeye yalnızca alanın metin
                                  // sonundan sağ okla geçilir (issue #4).
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocusNode,
                                          obscureText: _obscurePassword,
                                          enableSuggestions: false,
                                          autocorrect: false,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          onFieldSubmitted: (_) => _save(),
                                          validator: (value) => _required(
                                            value,
                                            l10n.passwordLabel,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: l10n.passwordLabel,
                                            prefixIcon: const Icon(
                                              Icons.lock_outline_rounded,
                                              size: 19,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        focusNode: _passwordEyeFocusNode,
                                        tooltip: _obscurePassword
                                            ? l10n.passwordShowTooltip
                                            : l10n.passwordHideTooltip,
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const _ConnectionHint(),
                              const SizedBox(height: 12),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: OutlinedButton.icon(
                                  onPressed: _testingProvider
                                      ? null
                                      : _testProvider,
                                  icon: _testingProvider
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.cable_rounded),
                                  label: Text(l10n.providerTestButton),
                                ),
                              ),
                              if (_providerTestMessage != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _providerTestMessage!,
                                      style: TextStyle(
                                        color: _providerTestPassed
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : Theme.of(
                                                context,
                                              ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _saving
                                        ? l10n.savingLabel
                                        : l10n.saveSecurelyLabel,
                                  ),
                                ),
                              ),
                            ],
                            if (widget.initialSection !=
                                SettingsSection.provider) ...[
                              const SizedBox(height: 30),
                              Text(
                                l10n.indexerSectionTitle,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.35,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                l10n.indexerSectionSubtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.72),
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              if (_profilesLoading)
                                const Center(child: CircularProgressIndicator())
                              else if (_profilesLoadFailed)
                                Column(
                                  children: [
                                    Text(l10n.settingsLoadHint),
                                    TextButton(
                                      onPressed: _loadProfiles,
                                      child: Text(l10n.retry),
                                    ),
                                  ],
                                )
                              else
                                _SettingsCard(
                                  children: [
                                    if (_profiles.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          l10n.indexerMissingHint,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.72),
                                              ),
                                        ),
                                      )
                                    else
                                      for (final (index, profile)
                                          in _profiles.indexed) ...[
                                        _IndexerProfileRow(
                                          profile: profile,
                                          onTap: () => _openIndexerDialog(
                                            editing: profile,
                                          ),
                                          onToggle: (enabled) =>
                                              _toggleProfile(profile, enabled),
                                        ),
                                        if (_profiles.length > 1)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: l10n.indexerMoveUp,
                                                onPressed: index > 0
                                                    ? () => _moveProfile(
                                                        index,
                                                        -1,
                                                      )
                                                    : null,
                                                icon: const Icon(
                                                  Icons.arrow_upward_rounded,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: l10n.indexerMoveDown,
                                                onPressed:
                                                    index + 1 < _profiles.length
                                                    ? () =>
                                                          _moveProfile(index, 1)
                                                    : null,
                                                icon: const Icon(
                                                  Icons.arrow_downward_rounded,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 8),
                                      ],
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        autofocus:
                                            widget.initialSection ==
                                            SettingsSection.indexer,
                                        onPressed: () => _openIndexerDialog(),
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                        ),
                                        label: Text(l10n.indexerAddButton),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardForeground = isDark ? Colors.white : Colors.black;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardForeground.withValues(alpha: isDark ? 0.055 : 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardForeground.withValues(alpha: 0.09)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: foreground.withValues(alpha: 0.54),
                size: 32,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.secureStorageUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                l10n.settingsLoadHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionHint extends StatelessWidget {
  const _ConnectionHint();

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: hintColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context).connectionLimitWarning,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: hintColor, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Tek bir indexer profilinin özet satırı: ad/URL, açık/kapalı anahtarı,
/// dokununca düzenleme diyaloğunu açar.
class _IndexerProfileRow extends StatelessWidget {
  const _IndexerProfileRow({
    required this.profile,
    required this.onTap,
    required this.onToggle,
  });

  final IndexerProfile profile;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: foreground.withValues(alpha: 0.035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: foreground.withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(
                          alpha: profile.enabled ? 0.9 : 0.5,
                        ),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile.nickname.isNotEmpty)
                      Text(
                        profile.baseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(
                            alpha: profile.enabled ? 0.65 : 0.4,
                          ),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: l10n.indexerEnabledLabel,
                child: Switch(value: profile.enabled, onChanged: onToggle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [_IndexerProfileDialog] sonucu: kaydedilecek profil (ekleme/düzenleme)
/// veya silme isteği. İkisi birden null ise kullanıcı iptal etmiştir ve
/// diyalog hiç bu türü döndürmez (showDialog null döner).
class _IndexerDialogResult {
  const _IndexerDialogResult.save(this.profile) : delete = false;
  const _IndexerDialogResult.delete() : profile = null, delete = true;

  final IndexerProfile? profile;
  final bool delete;
}

/// Indexer ekleme/düzenleme diyaloğu. Kendi kaydetme/test akışına sahiptir;
/// dış ekranın NNTP formundaki "kirli durum" izlemesine katılmaz — Kaydet'e
/// basınca sonuç döner, asıl depoya yazma işini çağıran taraf yapar.
class _IndexerProfileDialog extends StatefulWidget {
  const _IndexerProfileDialog({
    required this.profile,
    required this.capsFn,
    required this.onSave,
  });

  /// Null ise yeni profil ekleniyor demektir.
  final IndexerProfile? profile;
  final NewznabCapsFn capsFn;
  final Future<void> Function(IndexerProfile) onSave;

  @override
  State<_IndexerProfileDialog> createState() => _IndexerProfileDialogState();
}

class _IndexerProfileDialogState extends State<_IndexerProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nicknameController = TextEditingController(
    text: widget.profile?.nickname ?? '',
  );
  late final _urlController = TextEditingController(
    text: widget.profile?.baseUrl ?? '',
  );
  late final _apiKeyController = TextEditingController(
    text: widget.profile?.apiKey ?? '',
  );
  bool _obscureApiKey = true;
  bool _testing = false;
  bool _saving = false;
  String? _testMessage;
  bool _testPassed = false;
  late final _nicknameFocus = dpadTraversalFocusNode(_nicknameController);
  late final _urlFocus = dpadTraversalFocusNode(_urlController);
  late final FocusNode _keyFocus = dpadTraversalFocusNode(
    _apiKeyController,
    focusOnRightEdge: () => _eyeFocus,
  );
  late final FocusNode _eyeFocus = dpadFieldActionFocusNode(
    controller: _apiKeyController,
    fieldNode: _keyFocus,
  );
  bool _allowClose = false;

  bool get _dirty =>
      _nicknameController.text != (widget.profile?.nickname ?? '') ||
      _urlController.text != (widget.profile?.baseUrl ?? '') ||
      _apiKeyController.text != (widget.profile?.apiKey ?? '');

  Future<void> _cancel() async {
    if (_saving || _testing) return;
    if (_dirty) {
      final l10n = AppLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.unsavedTitle),
          content: Text(l10n.unsavedHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.keepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.discardChanges),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  bool get _isEditing => widget.profile != null;

  @override
  void dispose() {
    _nicknameFocus.dispose();
    _urlFocus.dispose();
    _keyFocus.dispose();
    _eyeFocus.dispose();
    _nicknameController.dispose();
    _urlController.dispose();
    _apiKeyController
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _applyPreset(KnownIndexer preset) {
    setState(() {
      if (_nicknameController.text.trim().isEmpty) {
        _nicknameController.text = preset.name;
      }
      _urlController.text = preset.baseUrl;
      _testMessage = null;
    });
  }

  String? _validateUrl(String? value) {
    final l10n = AppLocalizations.of(context);
    final url = value?.trim() ?? '';
    if (url.isEmpty) return l10n.validationRequired(l10n.indexerUrlLabel);
    if (url.contains(RegExp(r'\s'))) return l10n.indexerUrlInvalid;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return l10n.indexerUrlInvalid;
    }
    return null;
  }

  String? _validateApiKey(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return l10n.validationRequired(l10n.indexerApiKeyLabel);
    }
    return null;
  }

  Future<void> _test() async {
    if (_testing || !(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final baseUrl = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final caps = await widget.capsFn(
        IndexerConfigDto(baseUrl: baseUrl, apiKey: apiKey, nickname: baseUrl),
      );
      if (!mounted) return;
      setState(() {
        _testPassed = true;
        _testMessage = l10n.indexerTestSuccess(caps.serverTitle ?? baseUrl);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testPassed = false;
        _testMessage = l10n.indexerTestFailed(
          safeErrorDetails(error, secrets: [apiKey]),
        );
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _testing) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final profile = IndexerProfile(
      id:
          widget.profile?.id ??
          'indexer-${DateTime.now().microsecondsSinceEpoch}',
      nickname: _nicknameController.text.trim(),
      baseUrl: _urlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      enabled: widget.profile?.enabled ?? true,
    );
    try {
      await widget.onSave(profile);
      if (!mounted) return;
      setState(() => _allowClose = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(_IndexerDialogResult.save(profile));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _testPassed = false;
        _testMessage = AppLocalizations.of(context).settingsWriteHint;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final name = widget.profile!.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.indexerDeleteConfirmTitle),
        content: Text(l10n.indexerDeleteConfirmHint(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.indexerDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _allowClose = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(const _IndexerDialogResult.delete());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        title: Text(_isEditing ? l10n.indexerEditTitle : l10n.indexerAddTitle),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditing) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in knownIndexers)
                          ActionChip(
                            label: Text(preset.name),
                            onPressed: () => _applyPreset(preset),
                          ),
                        ActionChip(
                          label: Text(l10n.indexerCustomOption),
                          onPressed: () => setState(() {
                            _nicknameController.clear();
                            _urlController.clear();
                            _testMessage = null;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nicknameController,
                    focusNode: _nicknameFocus,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.indexerNicknameLabel,
                      hintText: l10n.indexerNicknameHint,
                      prefixIcon: const Icon(
                        Icons.label_outline_rounded,
                        size: 19,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _urlController,
                    focusNode: _urlFocus,
                    decoration: InputDecoration(
                      labelText: l10n.indexerUrlLabel,
                      hintText: 'https://indexer.example',
                      prefixIcon: const Icon(
                        Icons.travel_explore_rounded,
                        size: 19,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: _validateUrl,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _apiKeyController,
                          focusNode: _keyFocus,
                          obscureText: _obscureApiKey,
                          enableSuggestions: false,
                          autocorrect: false,
                          onFieldSubmitted: (_) => _save(),
                          validator: _validateApiKey,
                          decoration: InputDecoration(
                            labelText: l10n.indexerApiKeyLabel,
                            prefixIcon: const Icon(Icons.key_rounded, size: 19),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        focusNode: _eyeFocus,
                        tooltip: _obscureApiKey
                            ? l10n.passwordShowTooltip
                            : l10n.passwordHideTooltip,
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _test,
                      icon: _testing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            )
                          : const Icon(Icons.cable_rounded, size: 18),
                      label: Text(l10n.indexerTestButton),
                    ),
                  ),
                  if (_testMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _testMessage!,
                          style: TextStyle(
                            color: _testPassed
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _confirmDelete,
              child: Text(
                l10n.indexerDeleteButton,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: _cancel,
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.indexerSaveLabel),
          ),
        ],
      ),
    );
  }
}
