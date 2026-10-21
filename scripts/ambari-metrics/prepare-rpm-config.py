#!/usr/bin/env python3
"""Prepare upstream config without discarding user-facing metrics or storage settings."""
import configparser
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from port_monitor import metric_groups_json

collector, monitor, metric_groups = map(Path, sys.argv[1:])


def properties(path, values):
    tree = ET.parse(path)
    root = tree.getroot()
    for name, value in values.items():
        prop = next((p for p in root.findall('property') if p.findtext('name') == name), None)
        if prop is None:
            prop = ET.SubElement(root, 'property')
            ET.SubElement(prop, 'name').text = name
            ET.SubElement(prop, 'value')
        prop.find('value').text = value
    tree.write(path, encoding='utf-8', xml_declaration=True)


# Keep all upstream settings, explicitly ensuring durable local embedded storage.
for relative in ['etc/ams-hbase/conf/hbase-site.xml', 'etc/ambari-metrics-collector/conf/hbase-site.xml']:
    properties(collector/relative, {'hbase.rootdir': 'file:///var/lib/ambari-metrics-collector/hbase',
        'hbase.tmp.dir': '/var/lib/ambari-metrics-collector/hbase-tmp',
        'hbase.cluster.distributed': 'false', 'hbase.zookeeper.quorum': 'localhost',
        'hbase.zookeeper.property.clientPort': '2182'})
path = monitor/'etc/ambari-metrics-monitor/conf'
(path/'metric_groups.conf').write_text(metric_groups_json(metric_groups.read_text()))
config = configparser.RawConfigParser()
config.read(path/'metric_monitor.ini')
config.set('default', 'metrics_servers', 'localhost')
# Host identity is resolved on installation rather than captured from the build container.
config.set('default', 'hostname', '__INSTALL_HOSTNAME__')
config.set('collector', 'port', '6188')
with (path/'metric_monitor.ini').open('w') as stream:
    config.write(stream)
