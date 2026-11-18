"""Install a local checkout into a Mudlet profile; never copy account data."""
import argparse
import datetime
import hashlib
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent
MODULES = {'bootstrap.lua', 'state.lua', 'monk.lua', 'events.lua', 'runner.lua', 'curing.lua', 'gui.lua', 'tracker.lua', 'bashing.lua', 'policy.lua', 'mobs.lua', 'mental.lua', 'defense.lua'}

BODY_ASSETS = {'crt_grid.png'} | {
    f'{part}_{color}.png'
    for part in ('head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg')
    for color in ('unknown', 'clear', 'warning', 'broken', 'mangled')
}

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
    if {source.name for source in sources} != MODULES:
        raise ValueError('Expected module manifest does not match; checkout is incomplete')
    assets = sorted((ROOT / 'combat_v2/assets/body').glob('*.png'))
    if {source.name for source in assets} != BODY_ASSETS:
        raise ValueError('Body-scan asset manifest does not match; checkout is incomplete')
    sources += assets
    backup = profile / 'combat-v2-backups' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    existing = [target / s.relative_to(ROOT / 'combat_v2') for s in sources if (target / s.relative_to(ROOT / 'combat_v2')).exists()]
    if existing:
        backup.mkdir(parents=True)
        for source in existing:
            dest = backup / source.relative_to(target)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
            if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(dest.read_bytes()).digest():
                raise OSError('Backup integrity failure: ' + str(source))
        print('Previous code backed up:', backup)
    target.mkdir(parents=True, exist_ok=True)
    for source in sources:
        dest = target / source.relative_to(ROOT / 'combat_v2')
        dest.parent.mkdir(parents=True, exist_ok=True)
        # Atomic replacement: avoids exposing a partially written Lua module.
        staged = dest.with_name(dest.name + '.new')
        shutil.copy2(source, staged)
        os.replace(staged, dest)
    print('Installed', len(MODULES), 'modules and', len(assets), 'body-scan assets:', target)
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
