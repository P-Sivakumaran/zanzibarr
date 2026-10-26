# Terms/privacy interface and assessment

Baseline: `d8f4ac0`, with unrelated hosted-catalog WIP preserved. Implemented
locally at the user's request for terms/privacy inspired by NZBgeek, rather
than adding an indexer connection or copying NZBgeek's agreement.

## Result

Settings → Terms & privacy opens an offline summary and separate versioned
Terms of use / Privacy notice drafts, a contents navigator, registered Flutter
package licences, TMDB attribution and user-selected external provider-policy
links. Text uses the active theme, supports selection, and has an explicit
English fallback notice. No new dependency, acceptance log, compulsory agreement
screen, browser session, background request or destructive data reset was added.

`assets/legal/terms.json` and `privacy.json` are the content source of truth.
Readable copies are [Terms](legal/TERMS_DRAFT.md) and
[Privacy](legal/PRIVACY_DRAFT.md). Run
`python tools/export_legal_documents.py --check` to detect stale copies.

The private-contact, publisher-identity and distribution-territory question
remains unanswered. Draft labels are prominent in the hub and documents; no
legal entity, address, licence grant, DMCA agent or compliance approval was
invented. Existing public project-profile navigation is clearly labelled public,
with instructions not to send sensitive material there.

The [regulatory assessment](LEGAL_REGULATORY_ASSESSMENT_2026-10-22.md) and
[data map](PRIVACY_DATA_MAP_2026-10-22.md) separate confirmed source behavior from
conditional legal obligations. Material unresolved items include top-level
software redistribution permission, native binary licensing/provenance, adult
service/age-assurance scope, provider conditions and an operational private
complaint/privacy contact. Mandatory consumer rights are preserved; provider
subscriptions do not become application billing or a licence to media.

The cost guide now distinguishes Gemini free-quota pricing from contractual
eligibility, age/audience restrictions and regional Paid Services requirements.
Neither this notice nor a user-supplied key waives those conditions.

## Verification

- Five focused widget checks passed: Settings navigation, draft disclosure,
  document/contents navigation, package licences, sanitized asset-load retry,
  and both documents at 360 px / 200% text.
- A load-failure regression found that a synchronous AssetBundle exception could
  escape initialization. The loader now captures synchronous and asynchronous
  failures and evicts the failed document before retry. The initial navigation
  test was corrected to scroll the off-screen link before tapping it.
- Ordered working-tree gate passed: **280 Rust tests**, Clippy with warnings
  denied, **Flutter analysis with no issues**, native host build and
  **519 Flutter tests** (**10 optional skips**), then whitespace validation.
  Analysis initially reported two unnecessary imports; removed them and resumed
  the gate from analysis. Native source was unchanged after its passing checks.
- Legal-text re-review found no blocking drafting issue within its scope, while
  preserving the explicit owner/legal-review decisions. It is not an
  enforceability opinion, worldwide legal due diligence or code/data-flow
  certification.
- Generated Markdown copies match the JSON assets. New-file whitespace and JSON
  validation passed. Logs: ignored `dist/audit/legal-*.log`.

This evidence covers the current working tree, including preserved unrelated WIP;
it does not certify a clean release snapshot. The root v1.27 version edit remains
untouched apart from adding legal asset entries. No new installer, installation,
process shutdown, commit, push or publication was performed. The previous v1.30
installer does not include these pages. Final legal adoption still needs the
identified owner inputs and qualified jurisdiction-specific review.
