import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _providerPolicies = [
  (
    'GitHub privacy',
    'https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement',
  ),
  ('Google / YouTube privacy', 'https://policies.google.com/privacy'),
  ('Gemini API terms and data use', 'https://ai.google.dev/gemini-api/terms'),
  (
    'Anthropic API data retention',
    'https://platform.claude.com/docs/en/manage-claude/api-and-data-retention',
  ),
  (
    'OpenAI privacy and regional policies',
    'https://openai.com/policies/privacy-policy/',
  ),
  ('TMDB API conditions', 'https://developer.themoviedb.org/docs/faq'),
];

Future<void> _openExternal(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The external page could not be opened.')),
    );
  }
}

enum LegalPage {
  terms('Terms of use', 'assets/legal/terms.json'),
  privacy('Privacy notice', 'assets/legal/privacy.json');

  const LegalPage(this.title, this.asset);
  final String title, asset;
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms & privacy')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your application, data and services',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Draft documents • 22 October 2026\n\n'
                    'Publisher identity, private contact details and distribution '
                    'territories are pending. These pages are available for review; '
                    'they are not a finalized service agreement. Opening them '
                    'does not record acceptance or enable optional services.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Viewing state is mainly stored on your device. Configured '
                'providers still receive requests; GitHub receives a startup '
                'update check. Optional AI sends your prompt and recent chat. '
                'Embedded players can retain browser data. Adult playback '
                'can appear in shared history.',
              ),
              const SizedBox(height: 24),
              for (final page in LegalPage.values)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(
                      page == LegalPage.terms
                          ? Icons.description_outlined
                          : Icons.privacy_tip_outlined,
                    ),
                    title: Text(page.title),
                    subtitle: Text(
                      page == LegalPage.terms
                          ? 'Lawful use, provider charges, rights and limitations'
                          : 'Storage, network requests, retention and your controls',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegalDocumentScreen(page: page),
                      ),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.code),
                  title: const Text('Package licences'),
                  subtitle: const Text(
                    'Registered Flutter package notices; native bundle '
                    'licences and application permissions need separate review',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Zanzibarr',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/branding/tmdb.png',
                    width: 24,
                    height: 24,
                    semanticLabel: 'TMDB',
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This product uses the TMDB API but is not endorsed or '
                      'certified by TMDB. Optional TMDB metadata and imagery '
                      'remain subject to its API conditions.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Provider privacy and API terms'),
                subtitle: const Text('External pages open only when selected'),
                children: [
                  for (final policy in _providerPolicies)
                    ListTile(
                      title: Text(policy.$1),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openExternal(context, policy.$2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Private legal/privacy contact details are not yet published. '
                'Do not post credentials, personal information, private URLs '
                'or illegal media in public support channels. For records '
                'held by a provider, contact that provider directly.',
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _openExternal(
                    context,
                    'https://github.com/P-Sivakumaran',
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Maintainer profile (public)'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These documents currently use English fallback. '
                'They load offline; external links open only when selected.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.page});
  final LegalPage page;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  AssetBundle? _bundle;
  Future<Map<String, dynamic>>? _document;
  final _sections = <int, GlobalKey>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(_bundle, bundle)) {
      _bundle = bundle;
      _load();
    }
  }

  void _load() {
    _sections.clear();
    _bundle!.evict(widget.page.asset);
    _document = Future.sync(() => _bundle!.loadString(widget.page.asset)).then((
      text,
    ) {
      final document = jsonDecode(text) as Map<String, dynamic>;
      if (document['title'] != widget.page.title ||
          document['sections'] is! List ||
          (document['sections'] as List).isEmpty) {
        throw const FormatException('Invalid bundled document');
      }
      return document;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.page.title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _document,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This offline document could not be loaded.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final document = snapshot.data!;
        final sections = document['sections'] as List;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${document['status']} • ${document['version']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(document['notice'] as String),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(document['summary'] as String),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Contents'),
                      children: [
                        for (var i = 0; i < sections.length; i++)
                          ListTile(
                            title: Text(sections[i]['title'] as String),
                            onTap: () {
                              final target = _sections[i]?.currentContext;
                              if (target == null) return;
                              Scrollable.ensureVisible(
                                target,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                              );
                            },
                          ),
                      ],
                    ),
                    for (var i = 0; i < sections.length; i++) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          sections[i]['title'] as String,
                          key: _sections.putIfAbsent(i, GlobalKey.new),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final paragraph in sections[i]['paragraphs'] as List)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(paragraph as String),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
