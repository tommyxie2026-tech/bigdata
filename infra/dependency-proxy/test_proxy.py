import json
import unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parent
class ProxyProfileTests(unittest.TestCase):
    def test_package_links_cannot_bypass_tls_proxy(self):
        import importlib.util
        spec=importlib.util.spec_from_file_location('probe',ROOT/'probe.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        self.assertEqual(module.proxy_url('/npm/pkg/-/pkg.tgz','https://localhost:8443/npm/'),'https://localhost:8443/npm/pkg/-/pkg.tgz')
        for url in ['https://registry.npmjs.org/pkg.tgz','http://localhost:8443/npm/pkg.tgz','https://localhost:8443/admin']:
            with self.assertRaises(AssertionError):module.proxy_url(url,'https://localhost:8443/npm/')
        with self.assertRaises(AssertionError):module.get('http://registry.npmjs.org/pkg.tgz')
    def test_dedicated_servers_are_persistent_and_not_published_plaintext(self):
        profile=yaml.safe_load((ROOT/'compose.yaml').read_text())
        self.assertEqual(set(profile['services']),{'maven','npm','pypi','tls'})
        self.assertTrue(profile['networks']['internal']['internal'])
        self.assertEqual(profile['services']['tls']['networks'],['internal','frontend'])
        for name in ['maven','npm','pypi']:
            server=profile['services'][name]
            self.assertNotIn('ports',server)
            self.assertTrue(any(':/' in str(v) and not str(v).endswith(':ro') for v in server['volumes']))
        for server in profile['services'].values():
            if 'image' in server:self.assertRegex(server['image'],r'@sha256:[a-f0-9]{64}$')
    def test_maven_really_stores_proxied_bytes(self):
        spec=json.loads((ROOT/'reposilite.json').read_text())['maven']['repositories'][0]
        self.assertEqual(spec['id'],'ci-maven')
        self.assertEqual(spec['storagePolicy'],'STRICT')
        self.assertEqual(spec['proxied'][0]['reference'],'https://repo.maven.apache.org/maven2/')
        self.assertIs(spec['proxied'][0]['store'],True)
    def test_uploads_and_administration_are_not_public(self):
        caddy=(ROOT/'Caddyfile').read_text()
        self.assertIn('method GET HEAD',caddy)
        self.assertLess(caddy.index('route {'),caddy.index('respond @mutations'))
        self.assertLess(caddy.index('respond @mutations'),caddy.index('handle_path'))
        npm=yaml.safe_load((ROOT/'verdaccio.yaml').read_text())
        self.assertEqual(npm['auth']['htpasswd']['max_users'],-1)
        for package in npm['packages'].values():self.assertEqual(package['publish'],[])
        self.assertIn('--restrict-modify=root',(ROOT/'devpi-entrypoint.sh').read_text())
    def test_offline_proof_checks_actual_network_isolation(self):
        script=(ROOT/'verify-cache.sh').read_text()
        self.assertIn('docker network disconnect',script)
        self.assertIn('docker inspect',script)
        self.assertIn('PROXY_DISPOSABLE',script)
        self.assertIn('docker compose restart maven npm pypi',script)
if __name__=='__main__':unittest.main()
