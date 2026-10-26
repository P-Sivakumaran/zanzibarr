import json
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile
from audit_android_native import elf_16k, audit, audit_apk


def elf(alignment=16384):
    data = bytearray(120)
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, 1)
    struct.pack_into("<I", data, 64, 1)
    struct.pack_into("<Q", data, 112, alignment)
    return bytes(data)

class NativeAuditTests(unittest.TestCase):
    def test_elf_requires_load_alignment(self):
        self.assertTrue(elf_16k(elf()))
        self.assertFalse(elf_16k(elf(4096)))
        self.assertFalse(elf_16k(elf(24576)))
    def test_truncated_and_non_elf_are_rejected(self):
        for data in [b"no", elf()[:70]]:
            with self.assertRaises((ValueError, struct.error)):
                elf_16k(data)
    def test_every_apk_library_is_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            apk=Path(directory)/"fixture.apk"
            with zipfile.ZipFile(apk,'w',compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr('lib/arm64-v8a/good.so',elf())
                archive.writestr('lib/arm64-v8a/bad.so',elf(4096))
            result=audit_apk(apk)
            self.assertFalse(result['elf16k'])
            self.assertEqual(len(result['libraries']),2)
            self.assertFalse(result['deviceValidated'])
    def test_changed_cached_bytes_fail_the_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'fixture.jar').write_bytes(b'changed')
            manifest=root/'manifest.json'
            manifest.write_text(json.dumps({'schema':1,'artifacts':{'fixture.jar':{'size':7,'sha256':'0'*64}}}))
            with self.assertRaisesRegex(ValueError,'mismatch'):
                audit(manifest,root)

if __name__=='__main__': unittest.main()
