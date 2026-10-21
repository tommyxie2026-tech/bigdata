#!/usr/bin/env python3
import copy
import unittest
from component_reuse_scope import component_input_fingerprint

CONFIG={'os_image':'openEuler', 'components':{
    'hudi':{'builder':'custom','version':'1.2.1','depends_on':['spark']},
    'spark':{'version':'3.5.8','depends_on':[]},
    'hue':{'builder':'custom','version':'4.11.0','depends_on':[]}}}
TREE={p:'100644:original' for p in [
    'ci/components.yaml', '.gitattributes',
    '.github/workflows/component-lifecycle.yml', '.github/workflows/test-components.yml',
    'scripts/ci/test-bigtop-component.sh', 'scripts/ci/build-hudi-rpm-openeuler-container.sh',
    'scripts/ci/test-hudi-rpm-openeuler-container.sh', 'scripts/ci/build-bigtop-component.sh',
    'scripts/ci/build-spark-rpm-openeuler-container.sh', 'scripts/ci/trino_query_client.py',
    'repo/openeuler-22.03-lts-sp4/bigtop-3.6/spark/3.5.8/SHA256SUMS']}


class ScopeTests(unittest.TestCase):
    def fingerprint(self, tree=None, config=None):
        return component_input_fingerprint(tree or TREE, config or CONFIG, 'hudi')
    def test_unrelated_docs_fixture_and_other_component_recipe_do_not_invalidate(self):
        changed=dict(TREE, **{'docs/readme.md':'new','scripts/hadoop-s3a/test.sh':'new',
                            'scripts/ci/build-hue-rpm-openeuler-container.sh':'new'})
        self.assertEqual(self.fingerprint(), self.fingerprint(changed))
    def test_own_test_recipe_shared_helper_and_dependency_rpm_changes_invalidate(self):
        for path in ['scripts/ci/test-hudi-rpm-openeuler-container.sh',
                     'scripts/ci/build-hudi-rpm-openeuler-container.sh',
                     'scripts/ci/trino_query_client.py',
                     '.github/workflows/test-components.yml',
                     'repo/openeuler-22.03-lts-sp4/bigtop-3.6/spark/3.5.8/SHA256SUMS']:
            changed=dict(TREE);changed[path]='changed'
            self.assertNotEqual(self.fingerprint(), self.fingerprint(changed),path)
    def test_unrelated_catalog_entry_does_not_invalidate(self):
        config=copy.deepcopy(CONFIG);config['components']['hue']['version']='new'
        self.assertEqual(self.fingerprint(),self.fingerprint(config=config))
    def test_target_dependency_and_global_runtime_changes_invalidate(self):
        for name in ['hudi','spark']:
            config=copy.deepcopy(CONFIG);config['components'][name]['version']='changed'
            self.assertNotEqual(self.fingerprint(),self.fingerprint(config=config))
        config=copy.deepcopy(CONFIG);config['os_image']='new'
        self.assertNotEqual(self.fingerprint(),self.fingerprint(config=config))
    def test_file_mode_is_part_of_identity(self):
        tree=dict(TREE);tree['scripts/ci/test-hudi-rpm-openeuler-container.sh']='100755:original'
        self.assertNotEqual(self.fingerprint(),self.fingerprint(tree))
    def test_incomplete_scope_unknown_dependency_or_cycle_is_rejected(self):
        tree=dict(TREE);del tree['scripts/ci/test-hudi-rpm-openeuler-container.sh']
        with self.assertRaises(ValueError):self.fingerprint(tree)
        config=copy.deepcopy(CONFIG);config['components']['hudi']['depends_on']=['missing']
        with self.assertRaises(ValueError):self.fingerprint(config=config)
        config=copy.deepcopy(CONFIG);config['components']['spark']['depends_on']=['hudi']
        with self.assertRaises(ValueError):self.fingerprint(config=config)


if __name__=='__main__':unittest.main()
