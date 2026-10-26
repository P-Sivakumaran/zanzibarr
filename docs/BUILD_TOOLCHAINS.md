# Build toolchain and native artifact contract

Reviewed build inputs are recorded in `tools/build-toolchains.json`: Flutter 3.44.6, Dart 3.12.2, Rust 1.99.0 and Android NDK 28.2.13676358. CI pins actual action commits and the Rust compiler; the Android build installs/selects the exact NDK. Keep the SDK pins and this contract aligned when deliberately upgrading, then execute native/device gates. The repository does not change the developer's global default SDK.

Android media bytes are pinned in `vendor/media_kit_libs_android_video/native-artifacts.json`. Never refresh that manifest during a build. Review upstream source/changes and independently verify replacement bytes; record why pins changed. A changed or corrupted cached JAR must fail rather than silently be trusted. Retain Dolby Vision and C++ runtime compatibility until replacement evidence exists.

Run `python tools/test_prepare_edition.py`, `python tools/test_android_native.py`, `python tools/test_release_assets.py` and actionlint for tooling changes. Run `tools/audit_android_native.py --apk <apk> --report <report>` on each completed APK; all 64-bit native libraries and uncompressed ZIP placement must satisfy the 16 KiB checks. Then validate on an actual 16 KiB device/emulator. Alignment alone is not runtime certification.

Build workflows run `tools/record_build_provenance.py` and retain `audit-*` artifacts separately from installable `zanzibarr-*` packages. The inventory reports dependency versions, lockfile hashes, exact artifact hashes and the observed checkout revision/dirty state. It is not a signed build attestation, complete native SBOM/licence record or device result. Do not pair a report with a different build or infer its libraries solely from a Dart package version.

The scheduled Rust advisory workflow scans the engine and CLI. A passing scan means no matching known advisories in its database, not proof of safety. Handle applicable advisories explicitly; do not add blanket ignores. Dependabot proposals require review and the repository's gates before merging.

Manual Legacy release preparation supports one platform or all. It always creates a draft with exact assets and source SHA. Public promotion requires appropriate signing, licensing and physical/clean-user acceptance evidence; a successful builder or checksum file does not waive those requirements.
