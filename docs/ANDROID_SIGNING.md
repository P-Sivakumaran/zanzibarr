# Android release signing

Every distributed APK must use the same private signing key. Release builds fail when signing configuration is missing; debug builds continue to use the local debug key.

Configure these GitHub Actions repository secrets before running Android or release workflows:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded persistent JKS/PKCS12 keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Signing key password |

Create and retain the key in your secure signing-key management system. Import the existing signing key if upgrades must remain compatible with an already-installed build. A newly generated key cannot update APKs signed with a different old CI debug key; changing build configuration cannot recover a lost signing key.

CI restores the encrypted keystore into the runner's private temporary directory, supplies passwords through environment variables, and removes the temporary copy even if the build fails. Signing material is never placed in the repository, build artifacts, command arguments, or logs.

For a local release build, supply `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` through your secure environment, then run `flutter build apk --release`. Do not create a tracked `key.properties` file or put passwords in shell history. For normal development, use `flutter run` or `flutter build apk --debug`.

Manual release dispatch resolves its `tag` to a single commit. All platform builds and release notes use that commit, regardless of the branch selected in the dispatch UI.
