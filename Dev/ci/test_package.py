import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile


spec = importlib.util.spec_from_file_location("ci_package", Path(__file__).with_name("package.py"))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
COMMIT = "a" * 40
SOURCE = "## Interface: 16001\n## Version: 4.2.0-alpha.1\nCore/Addon.lua\n"
PATTERNS = ["Dev", "tests", ".github", "Features/*/Dev.lua"]


class PackageTests(unittest.TestCase):
    def test_main_is_identifiable_without_changing_interface(self):
        toc = package.stamp(SOURCE, "main", COMMIT, "main")
        self.assertEqual(package.field(toc, "Version"), "4.2.0-alpha.1+main.aaaaaaaaaaaa")
        self.assertEqual(package.field(toc, "Interface"), "16001")
        self.assertEqual(package.field(toc, "X-Social-Diary-Commit"), COMMIT)

    def test_release_requires_matching_supported_tag(self):
        self.assertEqual(package.field(package.stamp(SOURCE, "tag", COMMIT, "v4.2.0-alpha.1"), "Version"), "4.2.0-alpha.1")
        for ref in ("main", "v4.2.0", "v4.2.0-alpha.2"):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                package.stamp(SOURCE, "tag", COMMIT, ref)
        with self.assertRaises(ValueError):
            package.stamp(SOURCE.replace("alpha", "rc"), "tag", COMMIT, "v4.2.0-rc.1")

    def test_main_rejects_other_branches_and_invalid_sha(self):
        with self.assertRaises(ValueError):
            package.stamp(SOURCE, "main", COMMIT, "feature/preview")
        with self.assertRaises(ValueError):
            package.stamp(SOURCE, "main", "short", "main")

    def test_ignore_patterns_come_from_pkgmeta(self):
        patterns = package.ignored_paths("package-as: social_diary\nignore:\n  - Dev\n  - Features/*/Dev.lua\n")
        self.assertIn("Dev", patterns)
        self.assertIn("Features/*/Dev.lua", patterns)

    def verify(self, additions=None, missing=None, changed_toc=None):
        toc = package.stamp(SOURCE, "tag", COMMIT, "v4.2.0-alpha.1")
        members = {"social_diary/social_diary.toc": changed_toc or toc,
                   "social_diary/Core/Addon.lua": "-- runtime", "social_diary/LICENSE": "licence"}
        members.update(additions or {})
        members.pop(missing, None)
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "addon.zip"
            with zipfile.ZipFile(archive, "w") as writer:
                for name, contents in members.items():
                    writer.writestr(name, contents)
            return package.verify_archive(archive, toc, PATTERNS)

    def test_valid_installable_archive(self):
        self.assertEqual(self.verify(), "4.2.0-alpha.1")

    def test_missing_loaded_file_or_licence_rejected(self):
        for name in ("social_diary/Core/Addon.lua", "social_diary/LICENSE"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.verify(missing=name)

    def test_dev_files_and_wrong_roots_rejected(self):
        for name in ("social_diary/Dev/data.lua", "social_diary/tests/mock.lua", "social_diary/.github/workflows/release.yml", "social_diary/Features/Help/Dev.lua", "wrong/Addon.lua", "social_diary/../outside"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.verify(additions={name: "excluded"})

    def test_changed_identity_and_unstripped_dev_block_rejected(self):
        toc = package.stamp(SOURCE, "tag", COMMIT, "v4.2.0-alpha.1")
        for changed in (toc.replace(COMMIT, "b" * 40), toc.replace("16001", "16002"), toc + "#@do-not-package@\n#@end-do-not-package@\n"):
            with self.subTest(toc=changed), self.assertRaises(ValueError):
                self.verify(changed_toc=changed)


if __name__ == "__main__":
    unittest.main()
