#!/bin/bash

interrupt() {
    echo ""
    echo "Interrupt detected!"
    echo "Cleaning up and archiving current state..."
    if [ -d "$name" ]; then
        tar czf "${name}_archive.tar.gz" "$name"
        echo "Archive created: ${name}_archive.tar.gz"
        rm -rf "$name"
        echo "Incomplete directory '$name' removed."
    fi
    echo "Setup cancelled. Exiting."
    exit 1
}

trap interrupt SIGINT


echo "======================================"
echo " Student Attendance Tracker — Setup"
echo "======================================"
echo ""

echo "Checking if python3 is installed..."
sleep 1
if python3 --version 2>/dev/null; then
    echo "python3 found, moving forward."
else
    echo "Warning: python3 not found. You can install it by running: sudo apt install python3"
fi

echo ""
read -p "Enter the desired project name: " folder

if [ -z "$folder" ]; then
    echo "Error: Project name cannot be empty. Exiting."
    exit 1
fi

name="attendance_tracker_$folder"

if [ -d "$name" ]; then
    echo ""
    echo "Warning: '$name' already exists."
    read -p "Overwrite it? (y/n): " overwrite
    if [ "$overwrite" = "y" ]; then
        rm -rf "$name"
        echo "Old directory removed."
    else
        echo "Exiting to avoid overwriting existing files."
        exit 1
    fi
fi

echo ""
echo "Creating workspace..."
sleep 0.5

mkdir -p "$name"
mkdir -p "$name/Helpers"
mkdir -p "$name/reports"

if [ $? -ne 0 ]; then
    echo "Error: Could not create directories. Check your permissions."
    exit 1
fi

echo "Directories created."
sleep 0.5

echo "Copying project files..."
cp attendance_checker.py "$name/"
cp assets.csv            "$name/Helpers/"
cp config.json           "$name/Helpers/"
cp reports.log           "$name/reports/"
sleep 1
echo "Files copied successfully."

echo ""
read -p "Do you want to update the attendance thresholds? (y/n): " choice

if [ "$choice" = "y" ]; then

    while true; do
        read -p "Enter Warning threshold (default 75, numeric only): " warning
        if [[ "$warning" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            break
        else
            echo "Invalid input. Please enter a number."
        fi
    done

    while true; do
        read -p "Enter Failure threshold (default 50, numeric only): " failure
        if [[ "$failure" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            break
        else
            echo "Invalid input. Please enter a number."
        fi
    done

    sed -i "s/\"warning_threshold\": 75/\"warning_threshold\": $warning/" "$name/Helpers/config.json"
    sed -i "s/\"failure_threshold\": 50/\"failure_threshold\": $failure/" "$name/Helpers/config.json"
    echo "Thresholds updated -> Warning: $warning% | Failure: $failure%"

else
    echo "Keeping default thresholds (Warning: 75%, Failure: 50%)."
fi

echo ""
echo "Running health check..."
sleep 0.5

errors=0
for filepath in "$name/attendance_checker.py" "$name/Helpers/assets.csv" "$name/Helpers/config.json" "$name/reports/reports.log"; do
    if [ -e "$filepath" ]; then
        echo "  Found: $filepath"
    else
        echo "  Missing: $filepath"
        errors=$((errors + 1))
    fi
done

if [ "$errors" -eq 0 ]; then
    echo "Health check passed. All files are in place."
else
    echo "Health check found $errors missing file(s). Setup may be incomplete."
fi

echo ""
echo "======================================"
echo " '$name' created successfully!"
echo " Run: cd $name && python3 attendance_checker.py"
echo "======================================"
exit 0

