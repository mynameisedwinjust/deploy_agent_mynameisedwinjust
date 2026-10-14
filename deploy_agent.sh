#!/usr/bin/env bash
# =============================================================================
# deploy_agent.sh - Automated Project Bootstrapping & Process Management
#
# Features:
#   1) deploy  - build attendance_tracker_<name>/ from templates/, then run it
#   2) run     - run the attendance app on an already deployed project
#   3) archive - archive reports/*.log into timestamped files under archives/
#
# Usage:
#   ./deploy_agent.sh              interactive menu
#   ./deploy_agent.sh deploy       deploy a new project
#   ./deploy_agent.sh run [name]   run a deployed project
#   ./deploy_agent.sh archive [name]  archive the logs of a deployed project
#   ./deploy_agent.sh help
#
# Ctrl+C (SIGINT) / Ctrl+Z (SIGTSTP) during deployment: the incomplete project
# is zipped to attendance_tracker_<name>_archive.zip and then removed.
# =============================================================================

# Must run under bash (not sh/dash): fail early with a clear message otherwise.
[ -n "${BASH_VERSION:-}" ] || { echo "Error: please run this script with bash:  bash deploy_agent.sh" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"
cd "$SCRIPT_DIR" || { echo "Error: cannot enter $SCRIPT_DIR"; exit 1; }

CREATED_DIR=""   # set only once WE have created the project dir (used by the trap)

# Sample data used by Option B (generate a fresh roster)
SAMPLE_NAMES=("Alice Johnson" "Bob Smith" "Charlie Davis" "Diana Prince" "Ethan Hunt"
              "Fiona Gallagher" "George Miller" "Hannah Lee" "Ian Wright" "Julia Roberts"
              "Kevin Brown" "Laura Wilson" "Michael Scott" "Nina Patel" "Oscar Diaz"
              "Paula Green" "Quincy Adams" "Rita Moreno" "Samuel Jones" "Tina Turner")
SAMPLE_EMAILS=("alice@example.com" "bob@example.com" "charlie@example.com" "diana@example.com" "ethan@example.com"
               "fiona@example.com" "george@example.com" "hannah@example.com" "ian@example.com" "julia@example.com"
               "kevin@example.com" "laura@example.com" "michael@example.com" "nina@example.com" "oscar@example.com"
               "paula@example.com" "quincy@example.com" "rita@example.com" "samuel@example.com" "tina@example.com")

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
pause() { sleep "${DEPLOY_DELAY:-0}"; }   # optional delay, handy for demoing Ctrl+C

# Print an error, remove anything half-built by this run, and stop.
fail() {
    echo "Error: $1" >&2
    if [[ -n "$CREATED_DIR" && -d "$CREATED_DIR" ]]; then
        rm -rf "$CREATED_DIR"
        echo "Incomplete directory '$CREATED_DIR' removed." >&2
    fi
    exit 1
}

# read with EOF protection: if input is closed, stop (and clean up) instead of looping forever
ask() {   # prompt varname
    read -r -p "$1" "$2" || { echo ""; fail "input closed before the script finished."; }
}

# Project names become part of a path (and of rm -rf), so keep them strict.
valid_name() { [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]; }

# Turn "v1" or "attendance_tracker_v1" into the directory name attendance_tracker_v1
resolve_project() {
    local input="${1#attendance_tracker_}"
    if [[ -z "$input" ]]; then
        echo "Error: project name cannot be empty." >&2; return 1
    fi
    if ! valid_name "$input"; then
        echo "Error: use only letters, numbers, '-' and '_' in the project name." >&2; return 1
    fi
    PROJECT_DIR="attendance_tracker_${input}"
}

# Ask for an existing project (Features 2 and 3)
ask_existing_project() {
    local input="$1"
    if [[ -z "$input" ]]; then
        echo "Deployed projects found:"
        ls -d attendance_tracker_*/ 2>/dev/null | sed 's#/$##; s/^/  - /' || true
        ask "Project name (the part after attendance_tracker_): " input
    fi
    resolve_project "$input" || return 1
    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo "Error: '$PROJECT_DIR' does not exist. Deploy it first (option 1)." >&2
        return 1
    fi
}

# Replace the number after a JSON key, in place, touching only that line.
# (-i.bak works with both GNU and BSD sed.)
set_json_number() {   # file key value
    sed -i.bak "s/\(\"$2\"[[:space:]]*:[[:space:]]*\)[0-9][0-9.]*/\1$3/" "$1" && rm -f "$1.bak"
}

# ----------------------------------------------------------------------------
# Signal handling (active only during Feature 1)
# ----------------------------------------------------------------------------
on_interrupt() {
    trap '' INT TSTP        # ignore further signals while we clean up
    echo ""
    echo "!! Deployment interrupted by $1."
    if [[ -n "$CREATED_DIR" && -d "$CREATED_DIR" ]]; then
        local zipfile="${CREATED_DIR}_archive.zip"
        echo "Archiving the incomplete project into $zipfile ..."
        if zip -rq "$zipfile" "$CREATED_DIR"; then
            echo "Archive created: $zipfile"
            rm -rf "$CREATED_DIR"
            echo "Incomplete directory '$CREATED_DIR' removed."
        else
            echo "Warning: zip failed; leaving '$CREATED_DIR' in place so nothing is lost." >&2
        fi
    else
        echo "No project directory had been created yet - nothing to archive."
    fi
    echo "Session closed cleanly."
    exit 130
}

# ----------------------------------------------------------------------------
# Feature 2: run the application
# ----------------------------------------------------------------------------
run_app() {   # project dir
    echo ""
    echo ">> Running $1 ..."
    ( cd "$1" && python3 attendance_checker.py )
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "The application exited with status $rc." >&2
    fi
    return $rc
}

feature_run() {
    ask_existing_project "$1" || return 1
    run_app "$PROJECT_DIR"
}

# ----------------------------------------------------------------------------
# Feature 3: archive the logs
# ----------------------------------------------------------------------------
feature_archive() {
    ask_existing_project "$1" || return 1
    local ts archived=0
    ts="$(date +%Y%m%d_%H%M%S)"

    mkdir -p "$PROJECT_DIR/archives/attendance" "$PROJECT_DIR/archives/absent" \
        || { echo "Error: cannot create archive directories (permission denied?)." >&2; return 1; }

    echo ""
    local name src dest
    for name in attendance absent; do
        src="$PROJECT_DIR/reports/${name}.log"
        dest="$PROJECT_DIR/archives/${name}/${name}_${ts}.log"
        local n=1
        while [[ -e "$dest" ]]; do   # same-second collision: keep every copy unique
            dest="$PROJECT_DIR/archives/${name}/${name}_${ts}_${n}.log"; n=$((n + 1))
        done
        if [[ -f "$src" ]]; then
            if mv "$src" "$dest"; then
                echo "Archived: $src -> $dest"
                archived=$((archived + 1))
            else
                echo "Error: could not archive $src" >&2
            fi
        else
            echo "Skipped:  ${name}.log not found in $PROJECT_DIR/reports/ (nothing to archive)."
        fi
    done

    if [[ $archived -eq 0 ]]; then
        echo "No logs were archived. Run the application first (option 2)."
    else
        echo "Done: $archived log(s) archived with timestamp $ts."
    fi
}

# ----------------------------------------------------------------------------
# Feature 1: deploy
# ----------------------------------------------------------------------------
preflight() {
    echo "== Pre-flight checks =="
    local missing=0
    if command -v python3 >/dev/null 2>&1; then
        echo "  [ok] $(python3 --version 2>&1)"
    else
        echo "  [!!] python3 is not installed (try: sudo apt install python3)" >&2; missing=1
    fi
    if command -v zip >/dev/null 2>&1; then
        echo "  [ok] zip found"
    else
        echo "  [!!] zip is not installed (try: sudo apt install zip)" >&2; missing=1
    fi
    local f
    for f in attendance_checker.py assets.csv config.json; do
        if [[ -f "$TEMPLATES/$f" ]]; then
            echo "  [ok] templates/$f"
        else
            echo "  [!!] templates/$f is missing" >&2; missing=1
        fi
    done
    if [[ $missing -ne 0 ]]; then
        echo "Error: pre-flight failed. Fix the items above and try again." >&2
        exit 1
    fi
}

ask_count() {   # prompt max -> sets COUNT
    local prompt="$1" max="$2" ans
    while true; do
        ask "$prompt (1-$max): " ans
        if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= max )); then
            COUNT=$ans; return
        fi
        echo "  Please enter a whole number between 1 and $max."
    done
}

build_roster() {   # sets total_sessions in config.json to stay consistent
    local roster="$CREATED_DIR/Helpers/assets.csv" cfg="$CREATED_DIR/Helpers/config.json"
    local choice
    echo ""
    echo "How should the roster (Helpers/assets.csv) be built?"
    echo "  A) Copy students from templates/assets.csv (4 prior sessions each)"
    echo "  B) Generate a fresh roster (counts start at 0)"
    while true; do
        ask "Choose A or B: " choice
        case "${choice^^}" in A|B) break ;; *) echo "  Please type A or B." ;; esac
    done

    if [[ "${choice^^}" == "A" ]]; then
        local available=$(( $(awk 'END{print NR}' "$TEMPLATES/assets.csv") - 1 ))   # awk counts a last line with no trailing newline
        ask_count "How many students to copy" "$available"
        head -n $((COUNT + 1)) "$TEMPLATES/assets.csv" > "$roster" || fail "could not write $roster"
        set_json_number "$cfg" total_sessions 5 || fail "could not update total_sessions"
        echo "Copied $COUNT student(s) from the template. total_sessions = 5 (4 prior + today)."
    else
        ask_count "How many students to generate" "${#SAMPLE_NAMES[@]}"
        echo "Email,Names,Attendance Count,Absence Count" > "$roster" || fail "could not write $roster"
        local i
        for ((i = 0; i < COUNT; i++)); do
            echo "${SAMPLE_EMAILS[$i]},${SAMPLE_NAMES[$i]},0,0" >> "$roster"
        done
        set_json_number "$cfg" total_sessions 1 || fail "could not update total_sessions"
        echo "Generated $COUNT student(s). total_sessions = 1 (first session)."
    fi
}

set_permissions() {
    chmod +x "$CREATED_DIR/attendance_checker.py" || fail "chmod +x failed"
    chmod 600 "$CREATED_DIR/Helpers/config.json"  || fail "chmod 600 failed"
    echo ""
    echo "Permissions set:"
    ls -l "$CREATED_DIR/attendance_checker.py" "$CREATED_DIR/Helpers/config.json" | awk '{print "  " $1 "  " $NF}'
    echo "  (attendance_checker.py is executable; config.json is owner read/write only)"
}

ask_threshold() {   # prompt default -> sets THRESH
    local ans
    while true; do
        ask "$1 [default $2]: " ans
        ans="${ans:-$2}"
        if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 0 && ans <= 100 )); then
            THRESH=$ans; return
        fi
        echo "  Invalid input. Enter a whole number from 0 to 100."
    done
}

update_thresholds() {
    local cfg="$CREATED_DIR/Helpers/config.json" ans warning failure
    echo ""
    ask "Update the attendance alert thresholds in config.json? (y/n): " ans
    if [[ "${ans,,}" != "y" ]]; then
        echo "Keeping default thresholds (warning 75, failure 50)."
        return
    fi
    while true; do
        ask_threshold "Warning threshold (%)" 75; warning=$THRESH
        ask_threshold "Failure threshold (%)" 50; failure=$THRESH
        if (( failure < warning )); then break; fi
        echo "  The failure threshold must be lower than the warning threshold. Try again."
    done
    set_json_number "$cfg" warning "$warning" || fail "could not update warning threshold"
    set_json_number "$cfg" failure "$failure" || fail "could not update failure threshold"
    chmod 600 "$cfg"
    echo "Thresholds updated -> warning: $warning, failure: $failure"
}

verify_structure() {
    local f missing=0
    echo ""
    echo "Verifying structure:"
    for f in "$CREATED_DIR/attendance_checker.py" "$CREATED_DIR/Helpers/assets.csv" \
             "$CREATED_DIR/Helpers/config.json" "$CREATED_DIR/reports"; do
        if [[ -e "$f" ]]; then echo "  [ok] $f"; else echo "  [!!] missing: $f"; missing=1; fi
    done
    [[ $missing -eq 0 ]] || fail "deployment verification failed"
}

feature_deploy() {
    preflight

    # Signals are trapped from here until deployment finishes.
    trap 'on_interrupt SIGINT'  INT
    trap 'on_interrupt SIGTSTP' TSTP

    echo ""
    local input ans
    ask "Enter a project name: " input
    resolve_project "$input" || exit 1
    local target="$PROJECT_DIR"

    if [[ -e "$target" ]]; then
        echo "'$target' already exists."
        ask "Overwrite it? (y/n): " ans
        if [[ "${ans,,}" == "y" ]]; then
            rm -rf "$target" || { echo "Error: could not remove '$target'." >&2; exit 1; }
            echo "Old '$target' removed."
        else
            echo "Error: aborted - '$target' already exists and was not overwritten." >&2
            exit 1
        fi
    fi

    echo ""
    echo "== Creating structure =="
    mkdir "$target" 2>/dev/null || { echo "Error: cannot create '$target' (permission denied?)." >&2; exit 1; }
    CREATED_DIR="$target"
    pause
    mkdir "$CREATED_DIR/Helpers" "$CREATED_DIR/reports" || fail "could not create subdirectories"
    echo "  created $CREATED_DIR/, Helpers/, reports/"
    pause

    cp "$TEMPLATES/attendance_checker.py" "$CREATED_DIR/attendance_checker.py" || fail "could not copy attendance_checker.py"
    cp "$TEMPLATES/config.json" "$CREATED_DIR/Helpers/config.json"             || fail "could not copy config.json"
    echo "  copied attendance_checker.py and config.json (unmodified) from templates/"
    pause

    build_roster
    pause
    set_permissions
    pause
    update_thresholds
    pause
    verify_structure

    # Deployment finished: release the traps so they do not affect the marking session.
    trap - INT TSTP
    CREATED_DIR=""

    echo ""
    echo "== Deployment complete: verifying by running the application =="
    run_app "$target"
    echo ""
    echo "Next: ./deploy_agent.sh archive ${target#attendance_tracker_}   (archive the logs)"
}

# ----------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------
usage() {
    cat <<USAGE
Usage: ./deploy_agent.sh [command] [project_name]

Commands:
  deploy              Deploy a new attendance_tracker_<name> project, then run it
  run [name]          Run the application of an already deployed project
  archive [name]      Archive reports/attendance.log and reports/absent.log
  help                Show this help
(no command)          Interactive menu
USAGE
}

menu() {
    local choice
    while true; do
        echo ""
        echo "======================================"
        echo "  Attendance Tracker - Deploy Agent"
        echo "======================================"
        echo "  1) Deploy a new project"
        echo "  2) Run the application"
        echo "  3) Archive the logs"
        echo "  4) Quit"
        ask "Select an option [1-4]: " choice
        case "$choice" in
            1) feature_deploy ;;
            2) feature_run "" ;;
            3) feature_archive "" ;;
            4|q|Q) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
}

case "${1:-}" in
    deploy)  feature_deploy ;;
    run)     feature_run "${2:-}" ;;
    archive) feature_archive "${2:-}" ;;
    help|-h|--help) usage ;;
    "")      menu ;;
    *)       echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
