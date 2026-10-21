#!/usr/bin/env python3
"""Configure a dedicated proxy instance through its documented REST API."""
import argparse
import base64
import json
from pathlib import Path
import ssl
import time
from urllib.parse import urlsplit
import urllib.error
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None  # Never forward administrative credentials to another endpoint.


def validate_base(value):
    url = urlsplit(value)
    if (url.username or url.password or url.query or url.fragment
            or url.path not in ('', '/') or not url.hostname
            or (url.scheme != 'https' and not (url.scheme == 'http' and url.hostname == '127.0.0.1'))):
        raise ValueError('Use an HTTPS origin, or the loopback administrative port; credentials belong in a file')
    return value.rstrip('/')


def recipe(kind, blocked=False):
    remote = {'maven': 'https://repo.maven.apache.org/maven2/',
              'npm': 'https://registry.npmjs.org/', 'pypi': 'https://pypi.org/'}[kind]
    payload = {'name': 'ci-' + kind, 'online': True,
        'storage': {'blobStoreName': 'default', 'strictContentTypeValidation': True},
        'proxy': {'remoteUrl': remote, 'contentMaxAge': -1, 'metadataMaxAge': 1440},
        'negativeCache': {'enabled': True, 'timeToLive': 5},
        'httpClient': {'blocked': blocked, 'autoBlock': True,
                       'connection': {'timeout': 15, 'retries': 1}}}
    if kind == 'maven':
        payload['maven'] = {'versionPolicy': 'RELEASE', 'layoutPolicy': 'STRICT'}
    return payload


class Admin:
    def __init__(self, base, password, ca_file=None):
        self.base = validate_base(base)
        self.authorization = 'Basic ' + base64.b64encode(('admin:' + password).encode()).decode()
        context = ssl.create_default_context(cafile=ca_file)
        self.opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=context))

    def request(self, method, path, data=None, content_type='application/json'):
        if not path.startswith('/service/rest/v1/'):
            raise ValueError('Unexpected administrative API path')
        body = (json.dumps(data).encode() if content_type == 'application/json' else data.encode()) if data is not None else None
        request = urllib.request.Request(self.base + path, data=body, method=method,
            headers={'Authorization': self.authorization, 'Content-Type': content_type})
        with self.opener.open(request, timeout=20) as response:
            body = response.read()
        return json.loads(body) if body else None

    def wait(self, seconds):
        deadline = time.monotonic() + seconds
        while True:
            try:
                self.request('GET', '/service/rest/v1/status')
                return
            except urllib.error.HTTPError as error:
                if error.code not in (502, 503, 504):
                    raise
                if time.monotonic() >= deadline:
                    raise RuntimeError('Proxy readiness deadline exceeded') from None
                time.sleep(2)
            except (urllib.error.URLError, TimeoutError):
                if time.monotonic() >= deadline:
                    raise RuntimeError('Proxy readiness deadline exceeded') from None
                time.sleep(2)

    def configure(self, blocked=False, anonymous=False):
        existing = {r['name']: r for r in self.request('GET', '/service/rest/v1/repositories')}
        for kind in ('maven', 'npm', 'pypi'):
            payload = recipe(kind, blocked)
            name = payload['name']
            endpoint = '/service/rest/v1/repositories/' + kind + '/proxy'
            if name in existing:
                if existing[name].get('format') != ('maven2' if kind == 'maven' else kind) or existing[name].get('type') != 'proxy':
                    raise ValueError('Existing repository name has another format/type: ' + name)
                self.request('PUT', endpoint + '/' + name, payload)
            else:
                self.request('POST', endpoint, payload)
            observed = self.request('GET', endpoint + '/' + name)
            if (observed.get('httpClient', {}).get('blocked') is not blocked
                    or observed.get('proxy', {}).get('remoteUrl') != payload['proxy']['remoteUrl']):
                raise ValueError('Proxy state did not match requested configuration: ' + name)
            print('Configured ' + name + ', outbound=' + ('blocked' if blocked else 'enabled'))
        self.request('PUT', '/service/rest/v1/security/anonymous',
                     {'enabled': anonymous, 'userId': 'anonymous', 'realmName': 'NexusAuthorizingRealm'})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='http://127.0.0.1:8081')
    parser.add_argument('--password-file', type=Path, required=True)
    parser.add_argument('--ca-file')
    parser.add_argument('--wait-seconds', type=int, default=600)
    parser.add_argument('--block-outbound', action='store_true')
    parser.add_argument('--allow-anonymous', action='store_true', help='Dedicated public-dependency instance only')
    parser.add_argument('--wait-only', action='store_true')
    parser.add_argument('--rotate-admin-to', type=Path)
    args = parser.parse_args()
    if args.wait_seconds < 1 or args.wait_seconds > 900:
        raise ValueError('Readiness timeout must be between 1 and 900 seconds')
    password = args.password_file.read_text().strip()
    if not password:
        raise ValueError('Empty administrative password file')
    admin = Admin(args.base, password, args.ca_file)
    admin.wait(args.wait_seconds)
    if args.wait_only:
        return
    if args.rotate_admin_to:
        import os, secrets
        new_password = secrets.token_urlsafe(36)
        descriptor = os.open(args.rotate_admin_to, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(new_password + '\n')
        admin.request('PUT', '/service/rest/v1/security/users/admin/change-password', new_password, 'text/plain')
        admin = Admin(args.base, new_password, args.ca_file)
        print('Administrative password rotated; secret stored in the requested private file')
    admin.configure(args.block_outbound, args.allow_anonymous)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        # HTTP errors print status but never response bodies or credential-bearing URLs.
        raise SystemExit(type(error).__name__ + ': proxy configuration failed') from None
