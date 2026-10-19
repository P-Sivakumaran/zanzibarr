import 'dart:io';
import '../src/rust/api/streaming.dart';

const localFileEntryKey = 'local-file';

/// Reuse player controls/history without creating a native streaming session.
Future<StreamInfo> prepareLocalPlayback(String path) async {
  final file = File(path).absolute;
  if (!await file.exists()) {
    throw StateError('Local video is no longer available');
  }
  return StreamInfo(
    sessionId: BigInt.zero,
    url: file.uri.toString(),
    castUrl: '',
    size: BigInt.from(await file.length()),
    filename: file.path.split(RegExp(r'[/\\]')).last,
    segmentCount: 0,
    compressed: false,
  );
}
