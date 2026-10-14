# deploy_agent_mynameisedwinjust

`deploy_agent.sh` bootstraps, runs and archives the logs of the **Student Attendance Tracker**
(`attendance_checker.py`, which is never modified), and cleans up safely if you interrupt a deployment.

## Repository layout

```text
deploy_agent_mynameisedwinjust/
├── deploy_agent.sh          # the master script (all 3 features + signal handling)
├── README.md
├── .gitignore               # keeps generated projects / zips out of git
└── templates/
    ├── attendance_checker.py   # official file from the assignment (unmodified)
    ├── assets.csv              # sample roster: 10 students, 4 prior sessions each
    └── config.json             # thresholds 75 / 50, total_sessions 5
```

## Requirements

Bash, `python3`, `zip`. (Ubuntu: `sudo apt install python3 zip`.)

**Windows:** this is a Bash script, so it does not run in PowerShell/CMD directly. Use **WSL (Ubuntu)**:
`sudo apt install python3 zip`, then clone/copy the repo into your WSL home (e.g. `~/deploy_agent_mynameisedwinjust`), not under `/mnt/c`
(NTFS does not honour `chmod 600`). The repo includes a `.gitattributes` so `deploy_agent.sh` keeps Unix (LF) line endings.
Run it with `bash deploy_agent.sh` (not `sh`).

## Video walkthrough

<PASTE YOUR VIDEO LINK HERE>

## How to run and choose a feature

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh            # interactive menu
```

I support **both** an interactive menu and command-line arguments:

| Command | Feature |
|---|---|
| `./deploy_agent.sh deploy` (menu option 1) | Feature 1 - deploy a new project, then run it |
| `./deploy_agent.sh run [name]` (option 2) | Feature 2 - run a deployed project |
| `./deploy_agent.sh archive [name]` (option 3) | Feature 3 - archive the logs |
| `./deploy_agent.sh help` | usage |

`name` is the part after `attendance_tracker_` (e.g. `v1` for `attendance_tracker_v1`). If omitted, the script lists the
deployed projects and asks. Projects are created next to `deploy_agent.sh`.

## Feature 1 - Deploy

1. **Pre-flight**: checks `python3` (prints `python3 --version`), `zip`, and that the three files exist in `templates/`. Exits early with a clear message if anything is missing.
2. **Name**: asks for a project name (letters, numbers, `-`, `_` only) and creates `attendance_tracker_<name>/`. If it already exists you are asked to overwrite or the script aborts with an error - it never overwrites silently. Failed `mkdir`/`cp` (e.g. permission denied) print an error and remove anything half-built.
3. **Structure created**:
   ```text
   attendance_tracker_<name>/
   ├── attendance_checker.py
   ├── Helpers/
   │   ├── assets.csv
   │   └── config.json
   └── reports/            (empty - the app creates the logs on first run)
   ```
4. **Roster** (`Helpers/assets.csv`):
   - **Option A** - copy N students (+ header) from `templates/assets.csv` using `head`.
   - **Option B** - generate N students from name/email arrays inside the script, counts start at `0`.
5. **`total_sessions` stays consistent with the roster** (no prompt):
   - Option A: sample rows carry 4 prior sessions, so `total_sessions = 5` (4 prior + today).
   - Option B: fresh roster, so `total_sessions = 1` (session one).
6. **Permissions**: `chmod +x attendance_checker.py` and `chmod 600 Helpers/config.json` (owner read/write only because it holds grading thresholds). The resulting permissions are printed.
7. **Threshold update** (optional): asks `y/n`. If yes, it prompts for `warning` (default 75) and `failure` (default 50). Pressing Enter keeps the default. Input must be a **whole number 0-100** (empty/letters are rejected and re-asked) and `failure` must be lower than `warning`. The file is then edited in place with `sed`, targeting only the `"warning": <n>` and `"failure": <n>` lines, so the file is not reformatted or reordered.
8. **Verify**: checks the structure exists, then runs the application (Feature 2). A successful start proves structure, roster and config work together.

## Feature 2 - Run

`cd attendance_tracker_<name> && python3 attendance_checker.py`, handled by the script. The app is interactive, so it takes over the terminal for the marking session.

## Feature 3 - Archive logs

After a run, `./deploy_agent.sh archive <name>`:

```text
attendance_tracker_<name>/
├── reports/                (logs are moved out after archiving)
└── archives/
    ├── attendance/attendance_YYYYMMDD_HHMMSS.log
    └── absent/absent_YYYYMMDD_HHMMSS.log
```

- Checks for `reports/attendance.log` and `reports/absent.log`, and archives each one that exists into its own folder.
- Both logs from one archive run share the same timestamp, so every archived copy is unique and traceable (a `_1`, `_2` suffix is added if two archives happen in the same second).
- Logs are **moved**, so the next session starts with fresh logs. (Change `mv` to `cp` in `feature_archive` if you prefer to keep the originals.)
- Prints which logs were archived and their final paths. A missing log (for example no `absent.log` because nobody was absent) is reported as "Skipped" and does not crash the script.

## Ctrl+C / Ctrl+Z handling (during deployment only)

`trap` is set for `SIGINT` (Ctrl+C) and `SIGTSTP` (Ctrl+Z) when deployment starts and **removed once deployment finishes**, so it never affects the marking session in `attendance_checker.py`.

On either signal the script:
1. prints that the deployment was interrupted,
2. zips whatever exists of the project into `attendance_tracker_<name>_archive.zip` (using `zip`),
3. deletes the incomplete `attendance_tracker_<name>/` directory,
4. exits cleanly (status 130).

If the interrupt arrives before the directory is created (e.g. at the name prompt), nothing is zipped. An already-existing project you declined to overwrite is never touched.

**How to test it**

```bash
DEPLOY_DELAY=1 ./deploy_agent.sh deploy     # optional: 1s pause between steps
# enter a name such as: test
# when the roster prompt "Choose A or B:" appears, press Ctrl+C (or Ctrl+Z)
ls                                          # attendance_tracker_test_archive.zip exists, attendance_tracker_test/ is gone
unzip -l attendance_tracker_test_archive.zip
```

The zip contains the partial project at the moment of interruption, e.g. `attendance_checker.py`, `Helpers/config.json` and an empty `reports/`
(`assets.csv` is absent if you interrupted before the roster was built).

## How the deployment was tested

- Deployed with Option A and Option B; confirmed `assets.csv` rows, header, and `total_sessions` (5 vs 1).
- `ls -l` confirmed `-rwxr-xr-x` on `attendance_checker.py` and `-rw-------` on `config.json`.
- Entered empty/non-numeric/out-of-range thresholds and confirmed they are rejected; confirmed `sed` changed only the two threshold lines.
- Re-deployed an existing name and answered `n` (aborts) and `y` (overwrites).
- Ran a marking session, archived, and checked both archive folders; archived again with no logs to confirm the graceful skip; marked everyone present to confirm a missing `absent.log` is handled.
- Sent SIGINT and SIGTSTP mid-deploy and confirmed the zip exists, the directory is removed, and the exit is clean.
