# deploy_agent_mynameisedwinjust

This repository contains a shell script that automatically builds an **Attendance Tracker Project Factory**. The script creates the project workspace, generates all required files, configures attendance thresholds, verifies system requirements, and safely handles interruptions.

---
# Attendance Tracker Bootstrapper

The script (`setup_project.sh`) automatically creates and configures an Attendance Tracker project. It generates the complete directory structure, starter files, and attendance checking system without requiring any external resources.

## Requirements

* Bash
* Python 3

## How to Run

```bash
chmod 755 setup_project.sh
./setup_project.sh
```
---

## What the Script Does

### 1. Verifies System Requirements

Before creating any files, the script checks whether Python 3 is installed on the machine. If Python 3 is not available, the script exits with an error message.

### 2. Creates the Project Workspace

The script prompts the user for a project name and creates a workspace using the format:

```text
attendance_tracker_<project_name>/
```
If a directory with the same name already exists, the script stops and asks for a different project name.

### 3. Generates the Project Structure

The following directory hierarchy is automatically created:

```text
attendance_tracker_<project_name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
└── reports/
    └── reports.log
```
### 4. Creates All Project Files

Using embedded heredocs, the script automatically generates:

* `attendance_checker.py`
* `Helpers/assets.csv`
* `Helpers/config.json`
* `reports/reports.log`
No external files are required.
### 5. Configures Attendance Thresholds
The default attendance thresholds are:
* Warning Threshold: 75%
* Failure Threshold: 50%
The user can choose to modify these values during setup.
The script validates the entered values before saving them to `config.json` using `sed`.
### 6. Confirms Successful Setup
After creation, the script verifies that all required files and directories exist and confirms successful setup.

---
# Running the Attendance Checker
Navigate into the generated project directory:
```bash
cd attendance_tracker_<project_name>
python3 attendance_checker.py
```
The program:
1. Reads attendance records from `Helpers/assets.csv`
2. Loads threshold values from `Helpers/config.json`
3. Evaluates student attendance
4. Writes warnings and results into:
```text
reports/reports.log
```
---
# Ctrl+C Safety Feature
The script includes signal handling for interruptions.
If the user presses **Ctrl+C** while the setup process is running:
1. The current project state is archived into:
```text
attendance_tracker_<project_name>_archive.tar.gz
```
2. The incomplete project directory is removed.
This prevents partially created workspaces from being left behind.
---
## Restoring an Archived Project
To extract the archived workspace:
```bash
tar -xzf attendance_tracker_<project_name>_archive.tar.gz
```
---
# Testing the Archive Feature
You can safely test the Ctrl+C functionality using a temporary project name.
### Steps

1. Run the script:
```bash
./setup_project.sh
```
2. Enter a project name such as:
```text
test
```
3. Wait until the project structure begins creating (or during threshold configuration).
4. Press:
```text
Ctrl+C
```
### Expected Result
The script will:
* Create an archive of the current progress.
* Delete the incomplete project directory.
* Exit gracefully without leaving unfinished files behind.
---
# Summary
This project demonstrates:
* Bash scripting
* Directory and file automation
* User input validation
* Configuration management
* Python integration
* Signal handling with Ctrl+C
* Automatic backup and recovery
* Project bootstrapping techniques

The Attendance Tracker Bootstrapper provides a complete example of how shell scripts can automate project setup while maintaining reliability and safe recovery mechanisms.
