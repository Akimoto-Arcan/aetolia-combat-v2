import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('installer', ROOT / 'install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)

with tempfile.TemporaryDirectory(prefix='cv2-test-') as tmp:
    profile = Path(tmp) / 'Combat V2'
    profile.mkdir()
    target = installer.install(profile)
    assert {p.name for p in target.glob('*.lua')} == installer.MODULES
    original = (target / 'bootstrap.lua').read_bytes()
    (target / 'bootstrap.lua').write_text('-- previous version\n')
    installer.install(profile)
    backups = list((profile / 'combat-v2-backups').glob('*/bootstrap.lua'))
    assert len(backups) == 1 and backups[0].read_text() == '-- previous version\n'
    assert (target / 'bootstrap.lua').read_bytes() == original
    for source in sorted(target.glob('*.lua')):
        subprocess.run(['luac', '-p', str(source)], check=True)
    for script in ['engine.lua', 'backend.lua', 'combat_text.lua', 'ih.lua', 'policy.lua', 'mental.lua', 'defense.lua', 'gui.lua']:
        subprocess.run(['lua', str(ROOT / 'tests' / script), target.as_posix() + '/'], check=True)
    tree = ET.parse(ROOT / 'loader.xml')
    assert tree.find('.//Script').get('isActive') == 'yes'
    assert 'sysLoadEvent' in tree.findtext('.//script')
    try:
        installer.install(Path(tmp) / 'missing')
    except ValueError:
        pass
    else:
        raise AssertionError('Installer should reject nonexistent profile')
print('PASS installer, backup/restore content, missing-profile refusal, loader XML, manifest Lua syntax checks, engine, backend and GUI suites')
