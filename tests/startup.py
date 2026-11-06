import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


VOLUME = Path('/lzcapp/var')
STATE = VOLUME / 'cognate'
KEY = STATE / 'keys/master.key'
SERVER = '/lzcapp/pkg/content/cognate-server'
WRAPPER = '/lzcapp/pkg/content/run.sh'


def request(path, message, token=None):
    headers = {'Content-Type': 'application/json', 'Connect-Protocol-Version': '1'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    query = urllib.request.Request('http://127.0.0.1:8080' + path,
                                   data=json.dumps(message).encode(), headers=headers)
    try:
        with urllib.request.urlopen(query, timeout=5) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())


def environment(password):
    return {
        'PATH': '/usr/bin:/bin', 'HOME': '/test/home', 'TMPDIR': '/test/tmp',
        'LAZYCAT_APP_DOMAIN': 'cognate.example.invalid',
        'COGNATE_LAZYCAT_OIDC_ENABLED': 'false',
        'COGNATE_BOOTSTRAP_ADMIN_USERNAME_BASE64': base64.b64encode(b'initial-admin').decode(),
        'COGNATE_BOOTSTRAP_ADMIN_PASSWORD_BASE64': base64.b64encode(password.encode()).decode(),
    }


def run_healthy(settings, original_password):
    with tempfile.TemporaryFile() as logs:
        process = subprocess.Popen(['sh', WRAPPER], env=settings, stdout=logs, stderr=logs)
        try:
            ready = False
            for attempt in range(200):
                if process.poll() is not None:
                    break
                try:
                    with urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=.3) as response:
                        ready = response.status == 200
                    if ready:
                        break
                except (OSError, urllib.error.URLError):
                    pass
                time.sleep(.05)
            assert ready, 'packaged wrapper failed to reach health 200'
            with urllib.request.urlopen('http://127.0.0.1:8080/assets/react-bits-LICENSE.txt', timeout=5) as response:
                license_bytes = response.read(2061)
                assert response.status == 200 and len(license_bytes) == 2060, 'complete React Bits license unavailable'
                assert hashlib.sha256(license_bytes).hexdigest() == \
                    '4bdd1fa59a6b7d5954bc3b213dbc34e455c635a94bbcecf9293553797d0fad02', \
                    'packaged React Bits license differs from pinned upstream'
            status, login = request('/skillhub.auth.v1.AuthService/Login',
                                    {'username': 'initial-admin', 'password': original_password})
            assert status == 200 and login.get('sessionToken'), 'original administrator login failed'
            status, settings_response = request('/skillhub.management.v1.LogManagementService/GetLogSettings',
                                                {}, login['sessionToken'])
            assert status == 200 and settings_response.get('settings'), 'administrator authorization failed'
            command = Path(f'/proc/{process.pid}/cmdline').read_bytes().split(b'\0')
            assert command[command.index(b'--data-dir') + 1] == b'/lzcapp/var/cognate/data'
            assert command[command.index(b'--key-file') + 1] == b'/lzcapp/var/cognate/keys/master.key'
            assert b'--init-key-if-missing' in command
            child_environment = Path(f'/proc/{process.pid}/environ').read_bytes()
            for secret in [original_password.encode(), settings.get('COGNATE_BOOTSTRAP_ADMIN_PASSWORD_BASE64', '').encode()]:
                if secret:
                    assert secret not in b'\0'.join(command) and secret not in child_environment
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
            try:
                code = process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise
        assert code == 0, 'server did not exit cleanly'
        logs.seek(0)
        output = logs.read()
        assert original_password.encode() not in output, 'administrator password leaked'
        assert KEY.read_bytes() not in output, 'master key leaked'


def assert_lost_key_refusal(failed, database, original_database):
    assert failed.returncode != 0, 'lost key for existing data was accepted'
    diagnostics = re.compile(
        rb'Cognate storage diagnostics: (?:effective_uid=[0-9]+|master_key metadata unavailable|'
        rb'directory_level=[0-9]+ mode=[0-7]+ uid=[0-9]+ gid=[0-9]+ type=directory)\n')
    refusal = failed.stderr
    while diagnostic := diagnostics.match(refusal):
        refusal = refusal[diagnostic.end():]
    assert refusal == (b'runtime lease: needs attention\n'
                       b'runtime lease: release or persistence uncertain\n'), 'unexpected lost-key refusal protocol'
    assert not KEY.exists(), 'lost key for existing data was regenerated'
    metadata = database.stat()
    assert (metadata.st_dev, metadata.st_ino, database.read_bytes()) == original_database, \
        'lost-key refusal changed SQLite bytes or identity'


def inside(scenario):
    assert os.geteuid() == 0, 'test requires namespace root'
    password = secrets.token_urlsafe(32) + '\n\'"#:$\\\n'
    settings = environment(password)
    if scenario == 'external-ancestor':
        external = Path('/test/external')
        external.mkdir(mode=0o777)
        external.chmod(0o777)
        settings['COGNATE_LAZYCAT_STATE'] = str(external / 'cognate')
        failed = subprocess.run(['sh', WRAPPER], env=settings, capture_output=True, timeout=15)
        assert failed.returncode != 0 and b'ancestor is writable' in failed.stderr
        assert external.stat().st_mode & 0o777 == 0o777
        assert VOLUME.stat().st_mode & 0o777 == 0o777
        assert not (external / 'cognate/keys/master.key').exists()
        print('PASS: external unsafe ancestor refused without changing its permissions')
        return
    if scenario == 'unsafe-platform-ancestor':
        Path('/lzcapp').chmod(0o777)
    if scenario in ('volume-symlink', 'readonly-volume', 'unsafe-platform-ancestor'):
        failed = subprocess.run(['sh', WRAPPER], env=settings, capture_output=True, timeout=15)
        assert failed.returncode != 0, 'unsafe or read-only volume was accepted'
        assert not KEY.exists(), 'rejected volume generated a key'
        assert VOLUME.stat().st_mode & 0o777 == 0o777, 'rejected volume was modified'
        print('PASS:', scenario)
        return
    VOLUME.chmod(0o777)
    assert VOLUME.stat().st_uid == 0
    original = None
    original_identity = None
    if scenario == 'upgrade':
        (STATE / 'keys').mkdir(parents=True, mode=0o700)
        STATE.chmod(0o700)
        (STATE / 'data').mkdir(mode=0o700)
        original = secrets.token_bytes(32)
        KEY.write_bytes(original)
        KEY.chmod(0o600)
        original_identity = KEY.stat().st_ino
        failed = subprocess.run([SERVER, '--data-dir', str(STATE / 'data'), '--key-file', str(KEY)],
                                env=settings, capture_output=True, timeout=15)
        assert failed.returncode != 0 and b'ancestor is writable' in failed.stderr
        assert KEY.read_bytes() == original
        print('PASS: root/0777 ancestor reproduces the device rejection before repair')
    run_healthy(settings, password)
    assert VOLUME.stat().st_mode & 0o777 == 0o700
    assert KEY.stat().st_mode & 0o777 == 0o600 and KEY.stat().st_nlink == 1
    assert len(KEY.read_bytes()) == 32
    if original is not None:
        assert KEY.read_bytes() == original and KEY.stat().st_ino == original_identity
    original = KEY.read_bytes()
    settings['COGNATE_BOOTSTRAP_ADMIN_PASSWORD_BASE64'] = base64.b64encode(secrets.token_bytes(32)).decode()
    VOLUME.chmod(0o777)
    run_healthy(settings, password)
    assert KEY.read_bytes() == original, 'restart replaced the master key'
    assert VOLUME.stat().st_mode & 0o777 == 0o700
    for mode in (0o644, 0o600):
        if mode == 0o600:
            extra = KEY.with_suffix('.linked')
            os.link(KEY, extra)
        KEY.chmod(mode)
        failed = subprocess.run(['sh', WRAPPER], env=settings, capture_output=True, timeout=15)
        assert failed.returncode != 0, 'unsafe existing key was accepted'
        assert KEY.read_bytes() == original, 'unsafe existing key was replaced'
        if mode == 0o600:
            extra.unlink()
    database = STATE / 'data/server.db'
    database_metadata = database.stat()
    original_database = (database_metadata.st_dev, database_metadata.st_ino, database.read_bytes())
    KEY.unlink()
    failed = subprocess.run(['sh', WRAPPER], env=settings, capture_output=True, timeout=15)
    assert_lost_key_refusal(failed, database, original_database)
    print('PASS:', scenario, 'health, explicit paths, original admin/key, restart, unsafe/lost-key refusal')


def outside(server, wrapper):
    package = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='cognate-lzc-startup.') as temporary:
        workspace = Path(temporary)
        content = workspace / 'content'
        content.mkdir()
        shutil.copy2(server, content / 'cognate-server')
        shutil.copy2(wrapper or package / 'run.sh', content / 'run.sh')
        shutil.copy2(package / 'tests/startup.py', workspace / 'startup.py')
        for scenario in ('fresh', 'upgrade', 'volume-symlink', 'readonly-volume',
                         'unsafe-platform-ancestor', 'external-ancestor'):
            volume = workspace / scenario
            volume.mkdir(mode=0o777)
            volume.chmod(0o777)
            (workspace / 'home').mkdir(exist_ok=True)
            (workspace / 'tmp').mkdir(exist_ok=True)
            command = ['bwrap', '--unshare-all', '--die-with-parent', '--new-session', '--uid', '0', '--gid', '0',
                       '--tmpfs', '/', '--ro-bind', '/usr', '/usr', '--ro-bind', '/lib', '/lib',
                       '--ro-bind', '/lib64', '/lib64', '--ro-bind', '/etc', '/etc',
                       '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/sbin', '/sbin',
                       '--proc', '/proc', '--dev', '/dev', '--bind', str(workspace), '/test',
                       '--dir', '/lzcapp', '--dir', '/lzcapp/pkg',
                       '--ro-bind', str(content), '/lzcapp/pkg/content',
                       '--ro-bind', str(workspace / 'startup.py'), '/startup.py']
            if scenario == 'volume-symlink':
                command += ['--symlink', '/test/' + scenario, '/lzcapp/var']
            else:
                command += ['--ro-bind' if scenario == 'readonly-volume' else '--bind', str(volume), '/lzcapp/var']
            command += ['--clearenv', '--setenv', 'PATH', '/usr/bin:/bin',
                        '--', '/usr/bin/python3', '/startup.py', '--inside', scenario]
            subprocess.run(command, check=True, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--server', type=Path)
    parser.add_argument('--wrapper', type=Path)
    parser.add_argument('--inside')
    arguments = parser.parse_args()
    if arguments.inside:
        inside(arguments.inside)
    else:
        if arguments.server is None:
            parser.error('--server is required')
        outside(arguments.server.resolve(), arguments.wrapper)
