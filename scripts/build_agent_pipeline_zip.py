#!/usr/bin/env python3
"""Build the versioned starter ZIP; --verify also checks extracted bytes."""
import argparse
import fnmatch
import hashlib
from pathlib import Path
import stat
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src/agent-pipeline-demo-starter'
OUTPUT = ROOT / 'dist/agent-pipeline-demo-starter.zip'
EXCLUDED = {
    '.git', '.codex', '.claude', '.aws', '.azure', '.ssh', '.venv',
    'node_modules', '__pycache__', '.pytest_cache', '.cache', '.playwright',
    'logs', 'state', 'origin.git', 'control', 'builder', 'reviewer',
    'workspaces', 'checkouts', 'tmp', 'temp', 'coverage', 'test-results',
    'playwright-report', 'secrets', 'credentials', '.mcp.json', '.npmrc',
}
PATTERNS = ('*.log', '*.pyc', '*.tmp', '*.swp', '*~', '.env', '.env.*',
            '*.pem', '*.key', '*.pfx', '*.p12', 'id_rsa*', 'id_ed25519*',
            '*credentials*.json', '*secret*.json', 'auth.json', '.DS_Store')


def source_files(source):
    if not source.is_dir() or source.is_symlink():
        raise ValueError(f'Source directory is absent or unsafe: {source}')
    files = {}
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if any(part.lower() in EXCLUDED or any(fnmatch.fnmatch(part.lower(), p.lower()) for p in PATTERNS)
               for part in relative.parts):
            continue
        if path.is_symlink():
            raise ValueError(f'Symlinks are not distributable: {relative}')
        if path.is_file():
            files[relative.as_posix()] = path.read_bytes()
    if not files:
        raise ValueError(f'Source directory contains no distributable files: {source}')
    return files


def build(source=SOURCE, output=OUTPUT):
    files = source_files(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Stored entries avoid compression-library version differences.
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_STORED) as archive:
        for name, contents in sorted(files.items()):
            info = zipfile.ZipInfo(f'agent-pipeline-demo-starter/{name}', (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, contents)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n', encoding='ascii')
    return digest


def verify(source=SOURCE, output=OUTPUT):
    expected = {f'agent-pipeline-demo-starter/{name}': data for name, data in source_files(source).items()}
    with zipfile.ZipFile(output) as archive, tempfile.TemporaryDirectory() as temporary:
        if sorted(archive.namelist()) != sorted(expected):
            raise ValueError('ZIP paths do not match distributable source files')
        # Exact membership above excludes traversal and duplicate entries before extraction.
        archive.extractall(temporary)
        actual = {p.relative_to(temporary).as_posix(): p.read_bytes()
                  for p in Path(temporary).rglob('*') if p.is_file()}
        if actual != expected:
            raise ValueError('Extracted ZIP differs from canonical source bytes')
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    if output.with_suffix('.zip.sha256').read_text() != f'{digest}  {output.name}\n':
        raise ValueError('Checksum sidecar does not match ZIP')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true', help='verify extracted files after building')
    parser.add_argument('--check', action='store_true', help='verify existing ZIP without rebuilding')
    args = parser.parse_args()
    try:
        if not args.check:
            print(build())
        if args.verify or args.check:
            verify()
            print('Verified archive paths, extracted bytes, and SHA-256 sidecar.')
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, f'error: {error}\n')
