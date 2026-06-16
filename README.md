
# Student Attendance Tracker: Automated Deployment Agent

---
## What This Script Does

1. Verifies if Python 3 is installed on your machine before running anything else.
2. Builds the desired directory architecture (`attendance_tracker_{input}/`) 
 with the `Helpers/` and `reports/` subdirectories.
3. Migrates The  source  codes (`attendance_checker.py`, `assets.csv`, etc.) 
into their correct target destinations.
4. Prompts to modify the default attendance thresholds and modifies the `config.json`
  values  using `sed`.
5. It Listens for a `Ctrl+C` interrupt. If the process is canceled while  in mid-executio
n, it removes the half-built workspace and packages the current state into an  archive.

---

## How to Run It

To run the script, first  make  sure you have executable permissions and run it directly in
 your terminal:

```bash
chmod 755 setup_project.sh
```
```bash
./setup_project.sh 
```

