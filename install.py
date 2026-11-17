"""Install a local checkout into a Mudlet profile; never copy account data."""
import argparse
import datetime
import hashlib
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent

def default_profiles():
    if sys.platform == 'win32':
        return Path.home() / '.config/mudlet/profiles'
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Application Support/Mudlet/profiles'
    return Path.home() / '.config/mudlet/profiles'

def install(profile):
    profile = Path(profile).expanduser().resolve()
    if not profile.is_dir():
        raise ValueError('Profile directory does not exist. Create/open the profile in Mudlet first: ' + str(profile))
    target = profile / 'combat_v2'
    sources = sorted((ROOT / 'combat_v2').glob('*.lua'))
    if len(sources) != 7:
        raise ValueError('Expected seven source modules; checkout is incomplete')
    backup = profile / 'combat-v2-backups' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    existing = [target / s.name for s in sources if (target / s.name).exists()]
    if existing:
        backup.mkdir(parents=True)
        for source in existing:
            dest = backup / source.name
            shutil.copy2(source, dest)
            if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(dest.read_bytes()).digest():
                raise OSError('Backup integrity failure: ' + str(source))
        print('Previous code backed up:', backup)
    target.mkdir(parents=True, exist_ok=True)
    for source in sources:
        dest = target / source.name
        # Atomic replacement: avoids exposing a partially written Lua module.
        staged = dest.with_suffix('.lua.new')
        shutil.copy2(source, staged)
        os.replace(staged, dest)
    print('Installed seven modules:', target)
    print('First installation: install ' + str(ROOT / 'loader.xml') + ' using Mudlet Package Manager, then reopen the profile.')
    print('Existing installation: use cv2 reload while out of combat (reload starts OFF).')
    return target

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', type=Path, default=default_profiles() / 'Combat V2', help='Exact existing Mudlet profile directory')
    args = parser.parse_args()
    try:
        install(args.profile)
    except (OSError, ValueError) as exc:
        parser.exit(1, str(exc) + '\n')
