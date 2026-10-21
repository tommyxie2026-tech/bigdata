#!/usr/bin/env python3
"""Conservative component input closure for reuse across unrelated repository edits."""
import hashlib
import json
from pathlib import PurePosixPath
import re

SHARED_WORKFLOWS = {
    'build-components.yml', 'build-one-component.yml', 'component-lifecycle.yml',
    'check-component-repo.yml', 'test-components.yml', 'release-components.yml', 'ci-pr.yml',
}


def dependency_closure(config, component):
    components = config.get('components', {})
    selected = set()
    visiting = set()

    def visit(name):
        if name in visiting:
            raise ValueError('Cyclic component dependency: ' + name)
        if name in selected:
            return
        if name not in components:
            raise ValueError('Unknown component dependency: ' + name)
        visiting.add(name)
        entry = components[name]
        for dependency in entry.get('depends_on', []):
            visit(dependency)
        for engine in entry.get('compatibility', {}).get('engines', []):
            visit(engine)
        visiting.remove(name)
        selected.add(name)
    visit(component)
    return selected


def component_input_fingerprint(tree, config, component):
    selected = dependency_closure(config, component)
    components = config['components']
    required = {'ci/components.yaml', '.github/workflows/component-lifecycle.yml',
                '.github/workflows/test-components.yml', 'scripts/ci/test-bigtop-component.sh'}
    if components[component].get('builder', 'bigtop') == 'custom':
        required.update({'scripts/ci/build-' + component + '-rpm-openeuler-container.sh',
                         'scripts/ci/test-' + component + '-rpm-openeuler-container.sh'})
    else:
        required.add('scripts/ci/build-bigtop-component.sh')
    if not required.issubset(tree):
        raise ValueError('Incomplete component input tree')
    versions = {name: str(components[name]['version']) for name in selected}
    versions['common'] = str(config.get('bigtop_version', '3.6.0'))
    scoped = {}
    for path, blob in tree.items():
        parts = PurePosixPath(path).parts
        include = path == '.gitattributes'
        if path.startswith('.github/actions/') or path.startswith('packaging/'):
            include = True
        if path.startswith('.github/workflows/'):
            include = PurePosixPath(path).name in SHARED_WORKFLOWS or any(
                PurePosixPath(path).name in {name+'.yml', 'build-'+name+'.yml', 'test-'+name+'.yml'}
                for name in selected)
        if path.startswith('scripts/ci/') and not any(part == '__pycache__' for part in parts):
            include = True
            filename = PurePosixPath(path).name
            for other in set(components) - selected:
                if re.match(r'(?:build|test|preflight)-' + re.escape(other) + r'(?:-|\.)', filename):
                    include = False
        if len(parts) > 4 and parts[0] == 'repo' and parts[3] in versions:
            include = parts[4] == versions[parts[3]]
        if include:
            scoped[path] = blob
    payload = {'schema': 'bigdata.component-reuse-inputs/v1', 'component': component,
               'globals': {k:v for k,v in config.items() if k != 'components'},
               'components': {name:components[name] for name in sorted(selected)},
               'files': scoped}
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
