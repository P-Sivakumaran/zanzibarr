from pathlib import Path
import tempfile,unittest,zipfile
from prepare_release_assets import prepare,ASSETS

class ReleaseAssetsTests(unittest.TestCase):
 def test_windows_does_not_require_android_signing_or_files(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory)
   for name in ASSETS['windows']: (root/name).write_bytes(b'fixture')
   files=prepare(root,'windows','a'*40)
   self.assertEqual(set(files),ASSETS['windows']|{'SOURCE.json','SHA256SUMS'})
 def test_missing_selected_artifact_fails(self):
  with tempfile.TemporaryDirectory() as directory:
   with self.assertRaisesRegex(ValueError,'Missing'): prepare(Path(directory),'linux','a'*40)
 def test_android_rejects_archive_traversal_before_writing(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory)
   with zipfile.ZipFile(root/'zanzibarr-android.zip','w') as archive: archive.writestr('../escape.apk',b'bad')
   with self.assertRaisesRegex(ValueError,'unexpected'): prepare(root,'android','a'*40)
 def test_android_exact_assets_are_hashed(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory)
   with zipfile.ZipFile(root/'zanzibarr-android.zip','w') as archive:
    for name in ASSETS['android']: archive.writestr(name,b'fixture')
   files=prepare(root,'android','a'*40)
   self.assertEqual(set(files),ASSETS['android']|{'SOURCE.json','SHA256SUMS'})
if __name__=='__main__': unittest.main()
