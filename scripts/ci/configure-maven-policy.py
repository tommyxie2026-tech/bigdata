#!/usr/bin/env python3
"""Apply the CI Maven network policy without caching or printing credentials."""
import argparse
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit
import xml.etree.ElementTree as ET


def configure(path, mode, mirror):
    if mode not in ('online', 'offline'):
        raise ValueError('MAVEN_NETWORK_MODE must be online or offline')
    if mirror:
        parsed = urlsplit(mirror)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError('MAVEN_MIRROR_URL requires HTTPS; put credentials in Maven servers settings')
    if mode == 'online' and not mirror:
        print('Maven policy: mode=online, existing/default settings preserved')
        return
    if path.exists():
        tree = ET.parse(path)
        root = tree.getroot()
    else:
        root = ET.Element('settings')
        tree = ET.ElementTree(root)
    namespace = root.tag.partition('}')[0] + '}' if root.tag.startswith('{') else ''
    if root.tag != namespace + 'settings':
        raise ValueError('Maven settings root must be settings')

    def get(parent, name):
        node = parent.find(namespace + name)
        return node if node is not None else ET.SubElement(parent, namespace + name)

    get(root, 'offline').text = 'true' if mode == 'offline' else 'false'
    if mirror:
        mirrors = get(root, 'mirrors')
        for entry in list(mirrors):
            if entry.findtext(namespace + 'id') == 'ci-dependency-mirror':
                mirrors.remove(entry)
        entry = ET.SubElement(mirrors, namespace + 'mirror')
        for name, value in [('id', 'ci-dependency-mirror'), ('mirrorOf', 'external:*'), ('url', mirror)]:
            ET.SubElement(entry, namespace + name).text = value
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.ci-tmp')
    with temporary.open('wb') as stream:
        os.chmod(temporary, 0o600)
        tree.write(stream, encoding='utf-8', xml_declaration=True)
    temporary.replace(path)
    print('Maven policy: mode={}, mirror={}'.format(mode, 'configured' if mirror else 'existing/default'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--settings-file', type=Path, default=Path.home() / '.m2/settings.xml')
    args = parser.parse_args()
    try:
        configure(args.settings_file, os.environ.get('MAVEN_NETWORK_MODE', 'online'),
                  os.environ.get('MAVEN_MIRROR_URL', ''))
    except (ValueError, OSError, ET.ParseError) as error:
        print('Invalid Maven dependency policy: {}'.format(error), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
