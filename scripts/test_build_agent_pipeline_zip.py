"""Standard-library regression checks for archive reproducibility and exclusions."""
import tempfile
from pathlib import Path
import unittest
import zipfile

from build_agent_pipeline_zip import build, verify, source_files


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.output = self.root / 'starter.zip'

    def test_reproducible_and_exact(self):
        (self.source / 'z.txt').write_bytes(b'z\r\n')
        (self.source / 'a.txt').write_bytes(b'a\n')
        first = build(self.source, self.output)
        (self.source / 'a.txt').touch()
        self.assertEqual(first, build(self.source, self.output))
        verify(self.source, self.output)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.namelist(), [
                'agent-pipeline-demo-starter/a.txt', 'agent-pipeline-demo-starter/z.txt'])
            self.assertTrue(all(i.date_time == (1980, 1, 1, 0, 0, 0) for i in archive.infolist()))
        (self.source / 'a.txt').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            verify(self.source, self.output)

    def test_excludes_runtime_and_private_files(self):
        (self.source / 'README.md').write_text('public')
        for name in ('.git/config', 'logs/run.log', 'state/processed-commits.txt',
                     'control/file', 'builder/file', 'reviewer/file', 'origin.git/config',
                     'node_modules/file', '.env', '.env.local', '.ssh/id_rsa',
                     '.codex/auth.json', 'private.pem', 'tmp/input', 'test-results/trace.zip'):
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('excluded')
        self.assertEqual(list(source_files(self.source)), ['README.md'])

    def test_empty_missing_and_symlink_fail(self):
        for source in (self.source, self.root / 'missing'):
            with self.assertRaises(ValueError):
                build(source, self.output)
        (self.source / 'link').symlink_to(self.root / 'outside')
        with self.assertRaises(ValueError):
            build(self.source, self.output)

    def test_checksum_and_duplicate_entries_fail(self):
        (self.source / 'file').write_text('contents')
        build(self.source, self.output)
        self.output.with_suffix('.zip.sha256').write_text('wrong')
        with self.assertRaises(ValueError):
            verify(self.source, self.output)
        build(self.source, self.output)
        with zipfile.ZipFile(self.output, 'a') as archive:
            archive.writestr('../outside', b'not safe')
        with self.assertRaises(ValueError):
            verify(self.source, self.output)


if __name__ == '__main__':
    unittest.main()
