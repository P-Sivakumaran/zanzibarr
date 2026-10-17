import 'dart:convert';

import '../metadata/metadata_service.dart';
import 'integration_settings.dart';
import 'mcp_transport.dart';

/// Process-isolated provider plugins use MCP rather than loading native code.
/// Contract: metadata_search / metadata_details, with OMDb-compatible title fields.
class McpMetadataService extends MetadataService {
  McpMetadataService(this.connection, {McpClient? client})
    : _client = client ?? McpClient(connection);
  final McpConnection connection;
  final McpClient _client;

  Future<Map<String, dynamic>> _call(
    String tool,
    Map<String, dynamic> arguments,
  ) async {
    try {
      final result = await _client.call(tool, arguments);
      if (result['isError'] == true) throw const MetadataException('provider');
      final structured = result['structuredContent'];
      if (structured is Map) return Map<String, dynamic>.from(structured);
      final content = result['content'];
      if (content is List) {
        for (final item in content) {
          if (item is Map && item['type'] == 'text' && item['text'] is String) {
            final data = jsonDecode(item['text'] as String);
            if (data is Map) return Map<String, dynamic>.from(data);
          }
        }
      }
      throw const MetadataException('response');
    } catch (_) {
      throw const MetadataException('provider');
    }
  }

  @override
  Future<MetadataPage> search(
    String apiKey,
    String query, {
    String? kind,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return const MetadataPage([]);
    final id = normalizeImdbId(query);
    if (id != null) return MetadataPage([?await details('', id)]);
    final data = await _call('metadata_search', {
      'query': query.trim(),
      'kind': kind,
      'page': page,
    });
    final rows = data['Search'];
    if (rows is! List || rows.length > 100) {
      throw const MetadataException('response');
    }
    try {
      return MetadataPage([
        for (final row in rows)
          MediaTitle.fromJson(Map<String, dynamic>.from(row as Map)),
      ], hasMore: data['hasMore'] == true && page < 100);
    } catch (_) {
      throw const MetadataException('response');
    }
  }

  @override
  Future<MediaTitle?> details(String apiKey, String id) async {
    final normalized = normalizeImdbId(id);
    if (normalized == null) throw const MetadataException('id');
    final data = await _call('metadata_details', {'imdbId': normalized});
    if (data['found'] == false) return null;
    try {
      final title = MediaTitle.fromJson(data);
      if (title.imdbId != normalized) throw const MetadataException('response');
      return title;
    } catch (_) {
      throw const MetadataException('response');
    }
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
