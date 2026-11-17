# Aetolia Combat V2

Private, shared source for a clean Mudlet Monk combat GUI and basic executable routes. Both computers run local copies; GitHub is code storage, not a hosted Mudlet session.

## First install on another computer

1. Install Mudlet, Git, and Python 3. Open a new Mudlet profile named `Combat V2` once so its directory exists. Keep account credentials local.
2. Authenticate Git with the GitHub account that can access this private repository. With GitHub CLI: `gh auth login`.
3. Clone this repository:

   `git clone https://github.com/Akimoto-Arcan/aetolia-combat-v2.git`

   `cd aetolia-combat-v2`

4. Close the target Mudlet profile, then install:

   Windows: `py install.py`

   Linux: `python3 install.py`

   For a differently named or nonstandard profile, use `--profile "FULL PROFILE DIRECTORY"`. To find the exact directory in Mudlet, run `lua echo(getMudletHomeDir())`. The installer refuses nonexistent profiles.
5. Open the profile and install `loader.xml` from this checkout using Mudlet's Package Manager. Install the loader only once. Reopen the profile to run its startup handler. Do not add a second startup script if one already exists.
6. Log into Aetolia normally. The system starts OFF. Source updates/reloads do not send commands by themselves.

The current work computer already has the loader and modules installed; do not import another loader there.

## Update either computer

Outside combat, in this repository directory:

    git pull --ff-only
    py install.py

Use `python3 install.py` instead on Linux. Then in Mudlet:

    cv2 reload

Updates are manual. The installer backs up replaced Lua modules under the local profile's `combat-v2-backups` directory. Reload starts attacks OFF. It does not automatically disable server FIRSTAID.

Development source of truth is this checkout, not deployed profile copies. After editing: run tests, commit and push, then install on each computer. Avoid simultaneous uncommitted edits on both computers. Code can be used offline after installation.

## Controls

    t <name or mob ID>
    cv2 bash
    cv2 auto
    cv2 assist
    cv2 approve
    cv2 off
    cv2 curing on
    cv2 curing off
    cv2 status
    cv2 reload

`cv2 target NAME` also works. BASH/AUTO send the existing Monk routes after logged-in vitals and full balance/equilibrium/arm balances permit. ASSIST requires approval. Repeated attacks require observed balance loss and recovery. STOP/OFF stops attacks; FIRSTAID must be toggled separately.

Curing uses Aetolia's native `firstaid on`, `firstaid curing on`, and `firstaid off`, preserving your server priorities. A GUI request is not proof that the server accepted it.

## Tests

Install Lua/luac (Lua 5.1 is the CI target) and Python, then run:

    python3 tests/run.py

Tests install into an isolated temporary profile, verify replacement backups, parse the loader XML, check all module syntax, and run engine/GUI suites with fake senders. No game connection is needed. GitHub Actions runs these tests on pushes and pull requests.

## Scope and privacy

Bashing/PvP testing build with hunting queues, Scorpion-aware bashing, parry-aware limb routes, conditional finishers, scoped combat-text tracking, safety gates and a bounded diagnostic trace. See [backend controls and limitations](docs/backend.md). Enemy trauma uses explicitly marked legacy estimates after confirmed hits; advanced Kaido/Telepathy routes and restoration prediction are not complete. Live game timing still requires controlled testing.

Only Lua modules, loader, installer, documentation and tests belong here. Never commit profile XML exports, passwords, tokens, logs, command history or live combat state. The loader XML contains only a startup script, not a complete profile.

Cloud source access does not grant remote desktop/MCP access to either computer. Live GUI debugging on the second computer needs separately configured access.
