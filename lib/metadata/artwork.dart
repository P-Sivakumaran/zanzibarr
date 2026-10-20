import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../player/media_preferences.dart';
import 'metadata_links.dart';
export 'metadata_links.dart';

class ArtworkLoader {
  ArtworkLoader({http.Client? client, Uri? Function(String)? validateUri})
    : _client = client ?? http.Client(),
      _validateUri = validateUri ?? artworkUri;
  final Uri? Function(String) _validateUri;
  static final shared = ArtworkLoader();
  final http.Client _client;
  final _cache = <String, ({DateTime at, Uint8List bytes})>{};
  final _pending = <String, Future<Uint8List?>>{};
  final _waiters = <Completer<void>>[];
  int _active = 0;
  int _size = 0;
  int _generation = 0;
  void clear() {
    _generation++;
    _cache.clear();
    _size = 0;
  }

  void close() {
    clear();
    _client.close();
  }

  Future<Uint8List?> load(String url) async {
    final uri = _validateUri(url);
    if (uri == null) return null;
    final cached = _cache.remove(url);
    if (cached != null) {
      _size -= cached.bytes.length;
      if (DateTime.now().difference(cached.at) < const Duration(hours: 6)) {
        _cache[url] = cached;
        _size += cached.bytes.length;
        return cached.bytes;
      }
    }
    final existing = _pending[url];
    if (existing != null) return existing;
    // Bound queued requests as well as connections.
    if (_pending.length >= 32) return null;
    final future = _load(uri);
    _pending[url] = future;
    try {
      return await future;
    } finally {
      _pending.remove(url);
    }
  }

  Future<Uint8List?> _load(Uri uri) async {
    final generation = _generation;
    if (_active >= 4) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    } else {
      _active++;
    }
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 15), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      return await (() async {
        final request = http.AbortableRequest(
          'GET',
          uri,
          abortTrigger: abort.future,
        )..followRedirects = false;
        final response = await _client.send(request);
        if (response.statusCode != 200 ||
            !{
              'image/jpeg',
              'image/png',
              'image/webp',
            }.contains(response.headers['content-type']?.split(';').first) ||
            (response.contentLength ?? 0) > 5 * 1024 * 1024) {
          return null;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (builder.length + chunk.length > 5 * 1024 * 1024) return null;
          builder.add(chunk);
        }
        final buffer = await ui.ImmutableBuffer.fromUint8List(
          builder.takeBytes(),
        );
        try {
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          try {
            if (descriptor.width * descriptor.height > 8 * 1024 * 1024) {
              return null;
            }
            final width = descriptor.width.clamp(1, 500);
            final codec = await descriptor.instantiateCodec(
              targetWidth: width,
              targetHeight: (descriptor.height * width / descriptor.width)
                  .round()
                  .clamp(1, 2000),
            );
            try {
              final frame = await codec.getNextFrame();
              try {
                final data = await frame.image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                if (data == null) return null;
                final bytes = data.buffer.asUint8List();
                while (_cache.isNotEmpty &&
                    (_size + bytes.length > 20 * 1024 * 1024 ||
                        _cache.length >= 60)) {
                  _size -= _cache.remove(_cache.keys.first)!.bytes.length;
                }
                if (generation == _generation &&
                    bytes.length <= 20 * 1024 * 1024) {
                  _cache[uri.toString()] = (at: DateTime.now(), bytes: bytes);
                  _size += bytes.length;
                }
                return bytes;
              } finally {
                frame.image.dispose();
              }
            } finally {
              codec.dispose();
            }
          } finally {
            descriptor.dispose();
          }
        } finally {
          buffer.dispose();
        }
      })().timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }
}

class TitleArtwork extends StatefulWidget {
  const TitleArtwork({
    super.key,
    required this.url,
    required this.title,
    this.ratio = 2 / 3,
    this.loader,
  });
  final String url;
  final String title;
  final double ratio;
  final ArtworkLoader? loader;
  @override
  State<TitleArtwork> createState() => _TitleArtworkState();
}

class _TitleArtworkState extends State<TitleArtwork> {
  late Future<Uint8List?> _image = _loadImage();
  Future<Uint8List?> _loadImage() => widget.loader != null
      ? widget.loader!.load(widget.url)
      : ArtworkPreferences.shared.enabled
      ? ArtworkLoader.shared.load(widget.url)
      : Future.value(null);
  @override
  void initState() {
    super.initState();
    ArtworkPreferences.shared.addListener(_policyChanged);
    unawaited(ArtworkPreferences.shared.load());
  }

  void _policyChanged() {
    if (mounted && widget.loader == null) {
      setState(() {
        _image = _loadImage();
      });
    }
  }

  @override
  void dispose() {
    ArtworkPreferences.shared.removeListener(_policyChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(TitleArtwork old) {
    super.didUpdateWidget(old);
    if (widget.url != old.url || widget.loader != old.loader) {
      _image = _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: widget.ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _image,
          builder: (context, snapshot) => snapshot.data != null
              ? Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 500,
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null ? _placeholder(context) : child,
                  errorBuilder: (_, _, _) => _placeholder(context),
                )
              : _placeholder(context),
        ),
      ),
    ),
  );
  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(Icons.local_movies_outlined, size: 36),
        ),
      ),
    ),
  );
}

/// Artwork is opt-in independently of text lookup and playback. Only a boolean
/// preference is stored; clearing also invalidates pending cache insertions.
class ArtworkPreferences extends ChangeNotifier {
  ArtworkPreferences({PlayerPreferenceStorage? storage})
    : _storage = storage ?? FlutterSecurePlayerPreferenceStorage();
  static final shared = ArtworkPreferences();
  final PlayerPreferenceStorage _storage;
  bool enabled = false;
  bool ready = false;
  bool saving = false;
  String? error;
  Future<void>? _loading;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      enabled = await _storage.read('metadata.artwork.enabled') == 'true';
      ready = true;
      error = null;
    } catch (_) {
      error = 'Artwork preference could not be loaded.';
      _loading = null;
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (!ready || saving) return;
    saving = true;
    notifyListeners();
    try {
      await _storage.write('metadata.artwork.enabled', '$value');
      enabled = value;
      error = null;
      if (!value) {
        ArtworkLoader.shared.clear();
        imageCache.clear();
        imageCache.clearLiveImages();
      }
    } catch (_) {
      error = 'Artwork preference could not be saved.';
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}

class ArtworkSettings extends StatefulWidget {
  const ArtworkSettings({super.key});
  @override
  State<ArtworkSettings> createState() => _ArtworkSettingsState();
}

class _ArtworkSettingsState extends State<ArtworkSettings> {
  @override
  void initState() {
    super.initState();
    unawaited(ArtworkPreferences.shared.load());
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ArtworkPreferences.shared;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Load artwork'),
            subtitle: const Text(
              'Optional public image CDN requests. Turning off clears the memory cache.',
            ),
            value: prefs.enabled,
            onChanged: prefs.ready && !prefs.saving ? prefs.setEnabled : null,
          ),
          if (prefs.error != null)
            Wrap(
              children: [
                Text(prefs.error!),
                TextButton(onPressed: prefs.load, child: const Text('Retry')),
              ],
            ),
        ],
      ),
    );
  }
}
