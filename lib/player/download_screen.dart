import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../settings/provider_settings.dart';
import '../settings/settings_screen.dart';
import '../src/rust/api/download.dart' as native;
import '../src/rust/api/streaming.dart' show ProviderConfigDto;
import 'player_screen.dart';

abstract class DownloadBackend {
  Future<BigInt> begin(
    ProviderSettings settings,
    String nzbPath,
    String destination,
  );
  Future<native.DownloadProgressDto?> progress(BigInt id);
  Future<void> cancel(BigInt id);
}

class NativeDownloadBackend implements DownloadBackend {
  @override
  Future<BigInt> begin(ProviderSettings s, String path, String destination) =>
      native.beginDownload(
        config: ProviderConfigDto(
          host: s.host,
          port: s.port,
          username: s.username,
          password: s.password,
          maxConnections: s.maxConnections,
        ),
        nzbPath: path,
        destination: destination,
      );
  @override
  Future<native.DownloadProgressDto?> progress(BigInt id) =>
      native.downloadProgress(sessionId: id);
  @override
  Future<void> cancel(BigInt id) => native.cancelDownload(sessionId: id);
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({
    super.key,
    this.nzbPath,
    this.store,
    this.backend,
    this.pickNzb,
    this.pickFolder,
  });
  final String? nzbPath;
  final ProviderSettingsStore? store;
  final DownloadBackend? backend;
  final Future<String?> Function()? pickNzb, pickFolder;
  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  late final _backend = widget.backend ?? NativeDownloadBackend();
  late String? _nzb = widget.nzbPath;
  String? _folder, _error;
  native.DownloadProgressDto? _progress;
  BigInt? _id;
  Timer? _timer;
  bool _busy = false,
      _active = false,
      _polling = false,
      _leaving = false,
      _allowPop = false;
  Future<void> _chooseNzb() async {
    try {
      final path = widget.pickNzb != null
          ? await widget.pickNzb!()
          : (await openFile(
              acceptedTypeGroups: [
                const XTypeGroup(label: 'NZB', extensions: ['nzb']),
              ],
            ))?.path;
      if (mounted && path != null) setState(() => _nzb = path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The NZB picker could not be opened.');
      }
    }
  }

  Future<void> _chooseFolder() async {
    try {
      final path = await (widget.pickFolder?.call() ?? getDirectoryPath());
      if (mounted && path != null) setState(() => _folder = path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The folder picker could not be opened.');
      }
    }
  }

  Future<void> _start() async {
    if (_busy || _active || _nzb == null || _folder == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      final settings = await (widget.store ?? ProviderSettingsStore()).load();
      if (!settings.isComplete) throw StateError('provider');
      final id = await _backend.begin(settings, _nzb!, _folder!);
      _id = id;
      if (!mounted) {
        await _backend.cancel(id);
        return;
      }
      setState(() => _active = true);
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _poll(),
      );
      await _poll();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Download could not start. Check your provider settings, NZB and destination.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    if (_polling || _id == null || !mounted) return;
    _polling = true;
    try {
      final p = await _backend.progress(_id!);
      if (!mounted) return;
      if (p == null) throw StateError('session');
      setState(() {
        _progress = p;
        _active = !['complete', 'cancelled', 'failed'].contains(p.phase);
      });
      if (!_active) _timer?.cancel();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Download progress is unavailable. Cancel before starting another download.',
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _cancel() async {
    if (_id == null) return;
    try {
      await _backend.cancel(_id!);
      await _poll();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Cancellation could not be confirmed. Keep this screen open and try again.',
        );
      }
    }
  }

  Future<void> _leave() async {
    if (_busy || _leaving) return;
    _leaving = true;
    if (_active) {
      final cancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel download and leave?'),
          content: const Text(
            'Completed files stay on disk. The unfinished file is removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep downloading'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel download'),
            ),
          ],
        ),
      );
      if (cancel != true) {
        _leaving = false;
        return;
      }
      await _cancel();
      for (var i = 0; i < 50 && _active && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _poll();
      }
      if (_active) {
        _leaving = false;
        return;
      }
    }
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _openFolder() async {
    final path = _progress?.directory;
    if (path == null || path.isEmpty) return;
    try {
      if (await launchUrl(
        Uri.directory(path),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(
        () => _error =
            'The download folder could not be opened. Its location is shown above.',
      );
    }
  }

  Future<void> _localVideo([String? path]) async {
    try {
      path ??= (await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Video',
            extensions: [
              'mkv',
              'mp4',
              'avi',
              'mov',
              'm4v',
              'webm',
              'ts',
              'm2ts',
              'wmv',
            ],
          ),
        ],
      ))?.path;
      if (path == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(nzbPath: path!, localFilePath: path),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The local video could not be opened.');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_id != null && _active) {
      unawaited(_backend.cancel(_id!).catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    return PopScope(
      canPop: _allowPop || (!_active && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Download & local playback'),
          leading: IconButton(
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Download first, watch locally',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Downloads every original file in the NZB, including archive volumes and recovery files. This bypasses streaming archive parsing. Keep this screen open until finished. Up to 200 GiB per job; allow enough disk space for the files and any later extraction.',
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('NZB'),
                    subtitle: Text(_nzb ?? 'Choose an NZB'),
                    trailing: IconButton(
                      onPressed: _busy || _active ? null : _chooseNzb,
                      tooltip: 'Choose NZB',
                      icon: const Icon(Icons.file_open_outlined),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save folder'),
                    subtitle: Text(
                      _folder ??
                          'Choose a folder. A separate download subfolder will be created.',
                    ),
                    trailing: IconButton(
                      onPressed: _busy || _active ? null : _chooseFolder,
                      tooltip: 'Choose download folder',
                      icon: const Icon(Icons.folder_open),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _busy || _active || _nzb == null || _folder == null
                            ? null
                            : _start,
                        icon: const Icon(Icons.download),
                        label: const Text('Download all NZB files'),
                      ),
                      if (_active)
                        OutlinedButton(
                          onPressed: _cancel,
                          child: const Text('Cancel download'),
                        ),
                      TextButton(
                        onPressed: _busy || _active
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(
                                    store: widget.store,
                                    initialSection: SettingsSection.provider,
                                  ),
                                ),
                              ),
                        child: const Text('Provider settings'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || _active
                            ? null
                            : () => _localVideo(),
                        icon: const Icon(Icons.video_file_outlined),
                        label: const Text('Open local video'),
                      ),
                    ],
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (p != null) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${p.phase}: ${p.completedFiles}/${p.totalFiles} files',
                      ),
                    ),
                    if (_active)
                      LinearProgressIndicator(
                        value: p.totalFiles > 0
                            ? p.completedFiles / p.totalFiles
                            : null,
                      ),
                    Text(
                      '${(p.completedBytes.toDouble() / (1024 * 1024)).toStringAsFixed(1)} MiB written; ${(p.discoveredBytes.toDouble() / (1024 * 1024)).toStringAsFixed(1)} MiB decoded size discovered so far.',
                    ),
                    SelectableText(p.directory),
                    if (p.error.isNotEmpty) Text(p.error),
                    if (!_active && p.directory.isNotEmpty)
                      TextButton(
                        onPressed: _openFolder,
                        child: const Text('Open download folder'),
                      ),
                    if (p.phase == 'complete')
                      const Text(
                        'Direct video files can play immediately. For RAR/7z archives, extract the completed set with your local archive tool, then choose Open local video. This does not repair missing articles or guarantee support for every archive.',
                      ),
                    for (final path
                        in p.files
                            .where(
                              (p) => RegExp(
                                r'\.(mkv|mp4|avi|mov|m4v|webm|ts|m2ts|wmv)$',
                                caseSensitive: false,
                              ).hasMatch(p),
                            )
                            .take(30))
                      TextButton.icon(
                        onPressed: _active ? null : () => _localVideo(path),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(path.split(RegExp(r'[/\\]')).last),
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(liveRegion: true, child: Text(_error!)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
