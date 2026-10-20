import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'title_trailer.dart';

const trailerAppReferrer = 'https://com.zanzibarr.zanzibarr/';

/// WebView2 needs a navigation referrer, not just an overridden HTTP header.
/// The latter leaves document.referrer empty and YouTube rejects the player.
Future<void> navigateTrailer(
  InAppWebViewController controller,
  TitleTrailer trailer, {
  required TargetPlatform platform,
}) async {
  if (platform == TargetPlatform.windows) {
    final result = await controller.callDevToolsProtocolMethod(
      methodName: 'Page.navigate',
      parameters: {
        'url': trailer.embedUri.toString(),
        'referrer': trailerAppReferrer,
        'referrerPolicy': 'strictOriginWhenCrossOrigin',
      },
    );
    if (result is Map &&
        result['errorText'] is String &&
        (result['errorText'] as String).isNotEmpty) {
      throw StateError('Trailer navigation failed');
    }
  } else {
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri.uri(trailer.embedUri),
        headers: {'Referer': trailerAppReferrer},
      ),
    );
  }
}
