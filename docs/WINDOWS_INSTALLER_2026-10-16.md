# Windows installer with launch-time update checks — 2026-10-16

Created the local 1.10.0+11 Windows candidate installer from the already tested
release bundle, including the corrected icon and search refinements.

## Use

Run dist/windows/zanzibarr-windows-x64-setup.exe. Setup installs per user,
creates a Start menu shortcut, offers a desktop shortcut and can launch the app
after installation. Normal launches check the fork's latest stable release
from Home in the background. Offline failures do not block opening the app.
A newer release offers Update now, Later and Skip this version. Update now
verifies the downloaded installer against the same release's SHA256SUMS before
opening interactive Setup; installation is not silently forced.

No separate launcher was needed: launch checks already existed in HomeScreen.
The task added explicit startup-flow regression coverage and clarified the
release runbook, then packaged the existing verified application build.

Future updates require a higher version published on P-Sivakumaran/zanzibarr
with zanzibarr-windows-x64-setup.exe and SHA256SUMS. Draft releases are ignored.
No release, tag, push or publication was performed.

## Evidence

- Inno Setup 6.7.3 compilation and portable packaging passed.
- SHA-256 of both output artifacts verified against SHA256SUMS.
- ZIP CRC integrity and required native/CRT DLLs, notices and icon verified.
- New launch tests cover one background check, skipped-version policy, explicit
  Update now, Later, offline startup and disposal before a delayed response.
- 21 focused startup/release-check/Windows-download tests passed. Analysis and
  whitespace checks passed. An initial widget-test platform cleanup failure
  was fixed using the framework's managed Windows platform variant.
- The application was unchanged from the earlier full gate and Windows release
  build described in REFINEMENT_2026-10-16.md; those suites were not rerun here.
- Installer Authenticode status: NotSigned. No signing certificate was supplied.
- Lifecycle smoke refused the existing installed-copy registration and made no
  installation changes. Fresh-user/VM install, upgrade, settings retention,
  rendered launch and live update lifecycle remain unverified.

## Output hashes

```text
0030567c0521fa995b89583ee5f3514aa8c8faf0fb0e61fecbade9eeaac7cb68  zanzibarr-windows-x64-setup.exe
14272591d8f21e07f4c8aae9a325b57cce4426256e7c42c114995cb71c479fc6  zanzibarr-windows-x64.zip
```
