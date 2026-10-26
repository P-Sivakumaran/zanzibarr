# Clean and Restricted editions: implementation design

Decision date: 23 October 2026. Source baseline: `d8f4ac0`, plus preserved legal
drafts and unfinished catalog working changes. This is the architecture and
acceptance contract for the split, not evidence that two products have been
built or that arbitrary media can be certified as child-safe.

## Product decision

Maintain one shared playback application/core and two independently packaged
editions. Do not maintain two divergent forks and do not implement the clean
edition as an adult-menu toggle. Public packaging defaults to Clean; Restricted
requires an explicit separate build. Missing or inconsistent edition metadata
must fail closed in production builds.

| Boundary | Zanzibarr Clean | Zanzibarr Restricted |
| --- | --- | --- |
| Adult providers | Absent from production entrypoint/dependency graph and excluded from its source/package inputs | Explicitly registered restricted modules only |
| Content policy | Conservative, fixed policy: known mature/explicit material blocked; unclassified, conflicting or unavailable evidence withheld | Adult-capable subject to configured provider permissions, access controls and jurisdictional requirements |
| Application identity | Unique app/bundle/installer identity, display name and icon badge | Different identity/name/badge; no installation over Clean |
| Stored data | Separate secure-storage namespace, history, library, thumbnails, temporary files and browser profiles | Separate namespace and files; no automatic import/export to Clean |
| Updates | Clean-only artifacts and edition-matching manifest | Restricted-only artifacts and edition-matching manifest |
| Settings | Cannot enable restricted modules or weaken the fixed clean policy | Explicit restricted access and privacy controls |
| Distribution | Candidate public/store-oriented path after applicable release checks | Independent distribution and legal/provider eligibility review; no concealed store functionality |

Separate Android application IDs and Apple bundle IDs are established packaging
mechanisms. Flutter documents product flavors, while desktop identity/package
configuration also requires platform-specific work; a Dart entrypoint alone is
insufficient. [Flutter Android flavors](https://docs.flutter.dev/deployment/flavors),
[Android build variants](https://developer.android.com/build/build-variants),
[Flutter iOS bundle identifiers](https://docs.flutter.dev/deployment/ios).

## What “clean” can honestly mean

Use a central typed decision with **allowed**, **blocked**, **unclassified** and
**verification failed** outcomes. Only allowed content may be presented or
played. Require trusted, canonical metadata and an explicitly approved
classification policy; AI descriptions, a filename, an indexer label or a user
editable field cannot grant permission. Start conservatively with general/PG
classifications and equivalent TV classifications, and keep ambiguous regional
ratings or missing evidence withheld. Do not assume identical rating strings
have identical meaning across countries.

No category/title/rating filter proves what arbitrary video bytes depict.
Preserve that distinction in product copy. If a stronger child-safety assurance
is required, restrict playback to a curated, reviewed catalogue with trusted
media provenance. Do not advertise unrestricted Usenet or local-file playback as
guaranteed adult-free. Unknown NZBs, direct URLs and local files must not become
an approval bypass. A future parent/admin approval workflow needs a separate
clear contract; it is not an implicit exception.

Provider-side safe-search/category controls are the first layer, not the only
layer. Exclude adult Newznab categories/subcategories, but treat missing or
conflicting categorization as uncertain. A keyword denylist may supplement
classification; it must not be the primary safety mechanism. Check raw source
pagination before filtering so filtered pages do not break cursor correctness.

Apply policy before displaying title text, synopsis, artwork, cast links,
trailers or external URLs. Recheck at playback/download/cast entry and when
reading saved records. Episode navigation and automatic release choice must
retain the same canonical identity and content permission. Metadata failure,
timeout, rematch changes and stale async results must never fall back to an
unfiltered route.

Generative chat and arbitrary plugins are independent exposure paths. Do not
enable unrestricted AI prose, images, external MCP tools or provider-owned
webviews in Clean merely because the adult menu is absent. Each feature needs
a bounded, tested content-admission path; until it has one, leave it unavailable
in the clean production composition. Do not treat an AI-supplied rating or ID as
verified evidence.

## Shared-core boundaries in this repository

1. Extract edition-specific navigation/registration from `lib/main.dart` and
   `lib/settings/settings_home.dart`. They currently directly reference the
   hosted catalog. Shared player/settings widgets must not transitively import
   restricted modules into the Clean production graph.
2. Keep NNTP streaming, decoded offsets, bounded range serving, repair, resume,
   subtitles, localization and keyboard/TV controls shared. Add a central
   admission boundary rather than scattering independent regexes or booleans
   across widgets.
3. `lib/adult/` and unfinished `lib/catalog/` belong to restricted composition.
   Preserve their current working changes; do not silently promote unfinished
   catalog code as a verified restricted release.
4. Enforce search restrictions in the Rust/API layer as well as Flutter
   navigation. Existing `rust/src/api/search.rs` can explicitly request category
   6000, and generic responses need filtering too. Avoid a UI-only guard that
   local MCP or another entrypoint can bypass. Align native and Dart edition
   metadata and reject mismatches at startup/build verification.
5. Connect metadata admission to `lib/metadata/`, search selection, title
   matching, cached libraries, resume/history, playlists and player entrypoints.
   Do not classify only a search results page and leave saved/direct routes open.
6. Centralize storage scope. Default stores currently construct secure storage
   in several modules, while WebView/Codex support directories and temporary
   paths are separate concerns. Distinct application IDs plus explicit
   edition-scoped storage must cover all of them.
7. Preserve the existing installed application's identity/data as Legacy.
   Neither new edition should silently inherit it. Any future migration must
   be explicit, previewed, filtered and non-destructive, with no restricted
   thumbnails/history briefly appearing in Clean.

## Restricted access and privacy

Default restricted capabilities to locked. Use platform-backed user
authentication/access controls appropriate to the target platform, re-lock on
background/timeout and protect previews while locked. A PIN alone is not proof
of age and must never be described as regulatory age assurance. OS account and
parental controls matter on shared devices; an app lock is not protection from
a machine administrator.

Actual age-assurance obligations depend on service classification and countries
served. Select an appropriate verification arrangement only after that scope
decision; minimize data and avoid collecting identity documents/biometrics
casually. Separate normal streaming history from an explicitly designed private
mode; do not relabel the current shared history as private.

Keep legal/privacy documents truthful for each edition. Clean should not claim
to enable restricted endpoints, and Restricted must disclose the actual
providers/browser data/access behavior. Distinct binaries do not waive TMDB,
Gemini or other provider restrictions. See the
[legal assessment](LEGAL_REGULATORY_ASSESSMENT_2026-10-22.md) and
[data map](PRIVACY_DATA_MAP_2026-10-22.md).

## Packaging and release acceptance

- Explicit, validated Clean/Restricted profiles build from the same resolved
  source revision. Use stable, different app IDs, installer AppIds, install
  directories, executable/display names and update channels. Never repurpose
  upstream identities or replace the currently installed app as a side effect.
- Produce an edition-aware manifest containing source revision, native/Dart
  edition, policy version, package identity, supported platform, artifact hashes
  and verification state. Reject unknown editions and cross-edition updates
  before download/install. Checksums alone do not establish publisher identity.
- Audit Clean's dependency graph, assets and final artifacts for restricted
  modules, provider endpoints, routes and data; validate the actual build, not
  just a `const` condition that appears likely to tree-shake.
- Run shared-core tests, edition-specific tests and adversarial admission tests:
  category 6000/subcategories, missing/conflicting categories, spoofed ratings,
  stale metadata, AI text/IDs, cached records, direct NZB/file/URL routes, plugins,
  chapter/episode handoffs, locked/background states and failed verification.
- Verify co-installation, independent data/browser caches, old-installation
  preservation and clean-only/restricted-only upgrades on clean users/VMs.
  Include large text, screen readers, RTL and physical remote navigation.
- Separate CI artifacts and promotion gates. Clean is not permitted to receive
  a restricted artifact because a combined release happened to be latest.
  Restricted must not silently become a public/store release.

## Sequence and limits

Implement Clean first: define/classify admission, remove restricted production
imports, close every direct route, isolate data and prove the package. Reuse the
same shared core for Restricted, then add its authentication/age-assurance and
privacy behavior. Package independently only after cross-edition isolation and
update rejection pass. Do not attempt a single hidden setting or duplicate the
entire repository to get two names on installers.

Both editions still need resolution of upstream application redistribution
permission and exact native-library licensing before further public release.
The operator/contact/territory decisions for final legal documents also remain
open. This design records the best-practice direction; no edition split,
content-safety certification, installer or publication is claimed by this file.

## Implementation progress ? 26 October 2026

The Windows isolation, admission gates and independent development packaging are
implemented. See [implementation and remaining acceptance work](EDITION_SPLIT_IMPLEMENTATION_2026-10-26.md). Clean remains closed without a trusted
catalogue; the full two-edition release is not complete.
