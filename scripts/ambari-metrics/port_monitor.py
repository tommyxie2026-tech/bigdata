#!/usr/bin/env python3
"""Port the pinned upstream Monitor; keep source and converted hashes for RPM evidence."""
import argparse
import ast
import hashlib
import json
import tempfile
from pathlib import Path
import fissix
_GRAMMAR_CACHE = tempfile.TemporaryDirectory(prefix="metrics-fissix-")
fissix.CACHE_DIR = Path(_GRAMMAR_CACHE.name)
from fissix.refactor import RefactoringTool, get_fixers_from_package

_TOOL = RefactoringTool(get_fixers_from_package('fissix.fixes'))


def convert_python(source, relative_path, source_filename=None):
    if relative_path == 'core/__init__.py':
        marker = 'import platform'
        if marker not in source:
            raise ValueError('Unexpected Monitor psutil bootstrap')
        # Retain upstream license text; require the distribution's Python 3 psutil.
        source = source[:source.index(marker)] + 'import platform\nimport psutil\nIS_WINDOWS = platform.system() == "Windows"\n'
    filename = (source_filename or relative_path) if relative_path.startswith('core/') else '/__metrics_entrypoint__/main.py'
    converted = str(_TOOL.refactor_string(source.rstrip() + '\n', filename))
    if relative_path == 'core/config_reader.py':
        converted = converted.replace('ambari-metrics-host-monitoring', 'ambari-metrics-monitor')
    if relative_path == 'core/application_metric_map.py':
        if converted.count(' / 60000') != 2:
            raise ValueError('Unexpected upstream minute-bucket arithmetic')
        converted = converted.replace(' / 60000', ' // 60000')
    if converted.startswith('#!'):
        converted = '#!/usr/bin/python3\n' + converted.split('\n', 1)[1]
    converted = converted.replace('.isSet(', '.is_set(').replace('.isAlive(', '.is_alive(')
    ast.parse(converted, filename=relative_path)
    return converted


def port_tree(source, output):
    source, output = Path(source), Path(output)
    if output.exists():
        raise ValueError('Port output must be a new directory')
    paths = [source/'main.py']
    if (source/'__init__.py').is_file():
        paths.append(source/'__init__.py')
    paths += sorted((source/'core').rglob('*.py'))
    if not (source/'core/__init__.py').is_file() or not paths[0].is_file():
        raise ValueError('Incomplete upstream Monitor source')
    manifest = {}
    for path in paths:
        if path.is_symlink():
            raise ValueError('Unexpected symlink in Monitor Python source')
        relative = path.relative_to(source).as_posix()
        original = path.read_bytes()
        converted = convert_python(original.decode('utf-8'), relative, source_filename=str(path)).encode('utf-8')
        destination = output/relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(converted)
        manifest[relative] = {'source_sha256': hashlib.sha256(original).hexdigest(),
                              'ported_sha256': hashlib.sha256(converted).hexdigest()}
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    manifest = port_tree(args.source,args.output)
    args.manifest.parent.mkdir(parents=True,exist_ok=True)
    args.manifest.write_text(json.dumps({'source_identity':'ce919386e963841ea37f032c5ba6ed9c48298dd8',
        'converter':'fissix==24.4.24','system_dependency':'python3-psutil', 'files':manifest},indent=2)+'\n')
    print('Ported {} upstream Monitor Python files'.format(len(manifest)))


if __name__ == '__main__':main()
