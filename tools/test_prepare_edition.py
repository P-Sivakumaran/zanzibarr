import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from prepare_edition import audit_clean, dart_graph, prepare, verify, PROFILES
from audit_edition_bundle import audit, validate_aot_marker


class EditionPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        for relative, text in {
            "lib/main_clean.dart": "import 'editions/edition.dart'; void main() {}",
            "lib/editions/edition.dart": "import 'edition_config.dart';",
            "lib/editions/edition_config.dart": "const builtEdition = 'legacy'; const marker = 'ZANZIBARR_BUILD_LEGACY_POLICY_1';",
            "lib/adult/secret.dart": "// restricted provider",
            "windows/CMakeLists.txt": 'set(BINARY_NAME "zanzibarr")',
            "windows/runner/main.cpp": 'L"zanzibarr"',
            "windows/runner/Runner.rc": '"zanzibarr" "zanzibarr.exe"',
            "rust/src/edition.rs": 'const NAME: &str = "legacy";',
            "tools/windows/package.ps1": "    $integrations = Join-Path x\n    $licenses = Join-Path x\nzanzibarr.exe zanzibarr-windows-x64",
            "tools/windows/installer.iss": "AppId={{C39B6F7D-9326-4E4B-B0AE-123BCB782461}\nAppName=zanzibarr\nDefaultGroupName=zanzibarr\nDefaultDirName=zanzibarr\n",
            "pubspec.yaml": "name: zanzibarr\nflutter:\n  assets:\n    - assets/legal/terms.json\n",
            "assets/legal/terms.json": "{}",
        }.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
    def tearDown(self):
        self.temp.cleanup()
    def prepare(self):
        paths = [p.relative_to(self.root).as_posix() for p in self.root.rglob("*") if p.is_file()]
        def git(command, **kwargs):
            return ("\0".join(paths) + "\0").encode() if command[1] == "ls-files" else "a" * 40
        destination = self.root / "dist/editions/clean/source"
        with patch("prepare_edition.subprocess.check_output", side_effect=git):
            prepare(self.root, destination)
        return destination
    def test_default_is_clean_and_prunes_restricted_sources(self):
        target = self.prepare()
        manifest = verify(target)
        self.assertEqual(manifest["edition"], "clean")
        self.assertFalse((target / "lib/adult").exists())
        self.assertFalse((target / "assets/legal").exists())
        self.assertFalse(manifest["releaseEligible"])
        installer = (target / "tools/windows/installer.iss").read_text()
        self.assertIn(PROFILES["clean"]["app_id"].strip("{}"), installer)
        self.assertNotIn("C39B6F7D", installer)
        self.assertIn("'clean'", (target / "lib/editions/edition_config.dart").read_text())
    def test_adult_import_is_rejected_before_destination_created(self):
        (self.root / "lib/main_clean.dart").write_text("import 'adult/secret.dart';")
        with self.assertRaisesRegex(ValueError, "Restricted Clean import"):
            self.prepare()
        self.assertFalse((self.root / "dist/editions/clean/source").exists())
    def test_conditional_imports_are_all_audited(self):
        (self.root / "lib/main_clean.dart").write_text(
            "import 'editions/edition.dart' if (dart.library.io) 'adult/secret.dart';")
        with self.assertRaisesRegex(ValueError, "Restricted Clean import"):
            audit_clean(self.root)
    def test_source_tampering_and_cross_edition_manifest_are_rejected(self):
        target = self.prepare()
        p = target / "lib/main_clean.dart"
        p.write_text(p.read_text() + "// changed")
        with self.assertRaisesRegex(ValueError, "Changed build input"):
            verify(target)
        manifest = json.loads((target / "edition-manifest.json").read_text())
        manifest["nativeEdition"] = "restricted"
        (target / "edition-manifest.json").write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "identity mismatch"):
            verify(target)
    def test_unmanifested_sources_and_reused_destinations_are_rejected(self):
        target = self.prepare()
        (target / "lib/extra.dart").write_text("// unexpected")
        with self.assertRaisesRegex(ValueError, "Unmanifested"):
            verify(target)
        with self.assertRaisesRegex(ValueError, "already exists"):
            prepare(self.root, target)
    def test_unmanifested_root_configuration_is_rejected(self):
        target = self.prepare()
        (target / "pubspec_overrides.yaml").write_text("dependency_overrides: {}")
        with self.assertRaisesRegex(ValueError, "Unmanifested root"):
            verify(target)

    def test_mixed_aot_cannot_pass_edition_audit(self):
        clean = b"Zanzibarr Clean Zanzibarr Restricted ZANZIBARR_BUILD_CLEAN_POLICY_1"
        restricted = b"Zanzibarr Clean Zanzibarr Restricted ZANZIBARR_BUILD_RESTRICTED_POLICY_1"
        validate_aot_marker(clean, "clean")
        validate_aot_marker(restricted, "restricted")
        with self.assertRaisesRegex(ValueError, "marker mismatch"):
            validate_aot_marker(restricted, "clean")
        with self.assertRaisesRegex(ValueError, "marker mismatch"):
            validate_aot_marker(clean, "restricted")
    def test_unreviewed_project_module_cannot_enter_clean(self):
        (self.root / "lib/unknown.dart").write_text("void route() {}")
        (self.root / "lib/main_clean.dart").write_text("import 'unknown.dart';")
        with self.assertRaisesRegex(ValueError, "Unreviewed Clean import"):
            self.prepare()

    def test_bundled_manifest_cannot_be_swapped(self):
        source = self.prepare()
        bundle = self.root / "bundle"
        bundle.mkdir()
        (bundle / "edition-manifest.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "Bundled source manifest mismatch"):
            audit(source, bundle)

    def test_identities_never_overlap_legacy_or_each_other(self):
        for key in ("name", "binary", "app_id"):
            self.assertNotEqual(PROFILES["clean"][key], PROFILES["restricted"][key])
        self.assertNotIn("C39B6F7D", str(PROFILES))


if __name__ == "__main__":
    unittest.main()
