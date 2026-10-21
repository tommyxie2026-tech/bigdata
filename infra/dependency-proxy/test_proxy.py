import importlib.util
import pathlib
import unittest
import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.error
import yaml
ROOT=pathlib.Path(__file__).resolve().parent
class ProxyContract(unittest.TestCase):
    def test_deployment_pins_images_and_persists_nexus_without_public_admin_port(self):
        path=ROOT/'compose.yaml'
        self.assertTrue(path.exists(),'pinned proxy deployment is missing')
        config=yaml.safe_load(path.read_text())
        for service in config['services'].values():
            self.assertIn('@sha256:',service['image'])
            for port in service.get('ports',[]):self.assertTrue(port.startswith('127.0.0.1:'))
        self.assertIn('nexus-data:/nexus-data',config['services']['nexus']['volumes'])
    def load(self):
        path=ROOT/'configure.py'
        self.assertTrue(path.exists(),'repository configuration helper missing')
        spec=importlib.util.spec_from_file_location('proxy_config',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
    def test_proxy_recipes_only_use_official_https_sources(self):
        module=self.load()
        for kind,remote in [('maven','https://repo.maven.apache.org/maven2/'),('npm','https://registry.npmjs.org/'),('pypi','https://pypi.org/')]:
            payload=module.recipe(kind)
            self.assertEqual(payload['proxy']['remoteUrl'],remote)
            self.assertEqual(payload['httpClient']['connection']['timeout'],15)
            self.assertTrue(payload['storage']['strictContentTypeValidation'])
            self.assertFalse(payload['httpClient']['blocked'])
    def test_admin_endpoint_rejects_credentials_and_plaintext_remote(self):
        module=self.load()
        for url in ['http://proxy.example:8081','https://user:password@example.org','file:///etc/passwd','https://example.org/path?token=abc']:
            with self.assertRaises(ValueError):module.validate_base(url)
        self.assertEqual(module.validate_base('http://127.0.0.1:8081'),'http://127.0.0.1:8081')
        self.assertEqual(module.validate_base('https://proxy.example'),'https://proxy.example')
    def test_existing_maven2_repository_is_updated_and_redirects_are_rejected(self):
        module=self.load()
        requests=[]
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args): pass
            def do_GET(self):
                if self.path.endswith('/status'):
                    self.send_response(302);self.send_header('Location', '/would-leak-credentials');self.end_headers();return
                self.send_response(200);self.end_headers()
                value = ([{'name':'ci-maven','format':'maven2','type':'proxy'}] if self.path.endswith('/repositories')
                         else next(item[2] for item in requests if item[2]['name'] == self.path.rsplit('/',1)[-1]))
                self.wfile.write(json.dumps(value).encode())
            def do_PUT(self):
                requests.append(('PUT',self.path,json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
                self.send_response(204);self.end_headers()
            def do_POST(self):
                requests.append(('POST',self.path,json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
                self.send_response(201);self.end_headers()
        server=HTTPServer(('127.0.0.1',0),Handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            admin=module.Admin('http://127.0.0.1:'+str(server.server_port),'private-test-password')
            admin.configure(blocked=True)
            self.assertEqual(requests[0][0:2],('PUT','/service/rest/v1/repositories/maven/proxy/ci-maven'))
            self.assertTrue(requests[0][2]['httpClient']['blocked'])
            self.assertEqual(requests[-1][1],'/service/rest/v1/security/anonymous')
            self.assertFalse(requests[-1][2]['enabled'])
            with self.assertRaises(urllib.error.HTTPError) as raised:
                admin.request('GET','/service/rest/v1/status')
            self.assertEqual(raised.exception.code,302)
        finally:
            server.shutdown();server.server_close();thread.join()

    def test_live_probe_requires_restart_and_outbound_blocked_warm_fetch(self):
        path=ROOT/'verify-cache.sh'
        self.assertTrue(path.exists(),'actual server cache proof missing')
        source=path.read_text()
        for marker in ['block-outbound','docker compose','restart nexus','sha256sum','--fail','--connect-timeout','--max-time']:
            self.assertIn(marker,source)
if __name__=='__main__':unittest.main()
