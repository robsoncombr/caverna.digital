#!/bin/bash

###################################################
# Author: Robson Martins
# GitHub: https://github.com/robsoncombr
###################################################

# Script to Migrate YUM Repositories to Oracle Linux 7 on CentOS 7 systems
#
# This script handles migration to Oracle Linux 7 repositories. It disables 
# CentOS 7 repositories and replaces them with Oracle Linux 7 repositories.
# - `status`: Shows if the system has been migrated and if a backup is available.
# - `migrate`: Migrates the system to use Oracle Linux 7 repositories.
# - `rollback`: Restores the previous configuration from backup.
#
# Usage:
# ./script.sh status   - To check migration status and backup availability.
# ./script.sh migrate  - To migrate to Oracle Linux 7 repositories.
# ./script.sh rollback - To rollback to the previous configuration.

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "> WARNING! This script requires root privileges. Please run as root or use sudo."
    echo ""
    exit 1
fi

# Check if the system is CentOS 7
if ! grep -q "CentOS Linux release 7" /etc/centos-release 2>/dev/null; then
    echo ""
    echo "> This script requires CentOS 7. Exiting."
    echo ""
    exit 1
fi

# Variables
current_dir="/etc/yum.repos.d"
backup_dir="$current_dir.migration.bak"
oracle_repo_file="$current_dir/oraclelinux7.repo"
script_name=$(basename "$0")

# Function to display usage instructions
usage() {
    echo ""
    echo "Usage: $0 {status|migrate|rollback}"
    echo ""
    exit 1
}

# Function to handle errors and apply rollback
handle_error() {
    if [ "$1" == "migrate" ]; then
        echo ""
        echo "> ERROR! Error occurred during migration, invoking the rollback..."
        if [ -d "$backup_dir" ]; then
            rollback_repo 1  # Call the rollback function without confirmation
            echo ""
            echo "=====> Migration finished with error. Current settings remain in place. <====="
            echo ""
            exit 1
        fi
    fi

    echo ""
    echo "=====> Migration finished with error. <====="
    echo ""
    exit 1
}

# Function to disable specific repos using yum-config-manager
disable_specific_repos() {
    echo ""
    # Confirm that yum-config-manager exists
    if ! command -v yum-config-manager &> /dev/null; then
        echo "> WARNING! Required 'yum-config-manager' was not found."
        echo ""
        exit 0
    fi

    echo "Disabling base, updates, and extras repositories..."
    yum-config-manager --disable base || handle_error
    yum-config-manager --disable updates || handle_error
    yum-config-manager --disable extras || handle_error
}

# Function to disable all existing repos using sed while preserving original spacing
disable_existing_repos() {
    echo "Disabling all existing repositories with sed while preserving original spacing..."
    for repoconf in $(find /etc/yum.repos.d -type f); do
        sed -i 's/\(enabled[[:space:]]*=[[:space:]]*\)1/\10/' "$repoconf" || handle_error
    done
}

# Function to check migration and backup status
status() {
    echo ""
    echo "Checking system status..."
    echo ""

    if [ -f "$oracle_repo_file" ]; then
        echo "Migration Status: APPLIED! Oracle Linux 7 migration is in place."
    else
        echo "Migration Status: NOT PRESENT! No migration applied."
    fi

    if [ -d "$backup_dir" ]; then
        echo "Backup Status: AVAILABLE! Backup of previous repositories was detected."
    else
        echo "Backup Status: WARNING! No previous migration backup was found."
    fi

    echo ""
}

# Function to migrate to Oracle Linux 7 repositories
migrate_oracle_repo() {
    echo ""

    # Check if current exists
    if [ ! -d "$current_dir" ]; then
        echo ""
        echo "> WARNING! No current settings found, aborted."
        echo "$current_dir"
        echo ""
        exit 0
    fi

    # Check if the script is in the current settings folder
    if [[ $(find "$current_dir" -name "$script_name" | wc -l) -gt 0 ]]; then
        echo "> ERROR! The script is located in the current settings folder. Please move it out and try again."
        ls -a "$current_dir/$script_name"
        echo ""
        exit 1
    fi

    # Check if Oracle repo is already applied
    if [ -f "$oracle_repo_file" ]; then
        echo "Oracle Linux 7 repository is already migrated."
        echo ""

        # Check if backup exists
        if [ -d "$backup_dir" ]; then
            # Offer rollback option if migration has been applied
            read -p "ATTENTION! Instead, would you like to ROLLBACK to the previous repository configuration? Confirm (y/N): " rollback_choice
            rollback_choice=${rollback_choice:-N}

            if [[ "$rollback_choice" =~ ^[Yy]$ ]]; then
                rollback_repo
            else
                echo ""
                echo "> CANCELED! Exiting without changes."
                echo ""
                exit 0
            fi
        else
            echo "> WARNING! No previous backup ($backup_dir) was found to be reverted."
            echo ""
            exit 0
        fi
    else
        # Confirm migration
        echo "Are you sure you want to migrate to the Oracle Linux 7 repository?"
        echo "This will backup your existing repositories and disable them."
        read -p "You can rollback later if needed. Please confirm (y/N): " confirm
        echo ""
        confirm=${confirm:-N}

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Backup current repositories
            echo "Backing up current yum repositories to $backup_dir..."
            cp -Rdp $current_dir $backup_dir || handle_error

            # Disable specific repositories using yum-config-manager
            disable_specific_repos

            # Disable all other existing repositories (including 'CentOS 7') with sed
            disable_existing_repos

            # Add Oracle Linux 7 repository
            echo "Adding Oracle Linux 7 repository..."
            bash -c "cat << EOF > $oracle_repo_file
[ol7_latest]
name=Oracle Linux 7 Latest (aarch64)
baseurl=https://yum.oracle.com/repo/OracleLinux/OL7/latest/aarch64/
gpgcheck=1
gpgkey=https://yum.oracle.com/RPM-GPG-KEY-oracle-ol7
enabled=1

[ol7_optional_latest]
name=Oracle Linux 7 Optional Latest (aarch64)
baseurl=https://yum.oracle.com/repo/OracleLinux/OL7/optional/latest/aarch64/
gpgcheck=1
gpgkey=https://yum.oracle.com/RPM-GPG-KEY-oracle-ol7
enabled=1
EOF" || handle_error

            repo_count=$(yum repolist all | grep -i "^repolist: " | awk '{print $2}' | tr -d ',' || handle_error)
            if [ "$repo_count" -le 1 ]; then
                echo ""
                echo "> ERROR! Interrupting, no available repository, make sure that ($oracle_repo_file) exists."
                echo ""
                exit 1
            fi

            # Clean and update YUM cache
            echo "Cleaning yum cache and updating..."
            echo ""
            yum clean all || handle_error
            echo ""
            yum makecache || handle_error
            echo ""

            echo "> COMPLETED! Oracle Linux 7 repository is now migrated."
            echo ""
        else
            echo "Migration operation canceled."
            echo ""
            exit 0
        fi
    fi
}

# Function to rollback to the previous configuration
rollback_repo() {
    echo ""

    # Check if backup exists
    if [ ! -d "$backup_dir" ]; then
        echo "> WARNING! No backup found. Unable to rollback."
        echo ""
        exit 1
    fi

    # Bypass user interaction sending 1 as parameter, for example when called by the 'handle_error' function
    FORCE=${1:-0}

    if [[ "$FORCE" < 1 ]]; then
        # Check if the user is in the directory that will be deleted
        if [[ "$(pwd)" == "$current_dir"* ]]; then
            echo "> ERROR! You are currently in the current setting directory ($current_dir). Please change to another directory and try again."
            echo ""
            exit 1
        fi
        # Check if the user is in the directory that will be moved
        if [[ "$(pwd)" == "$backup_dir"* ]]; then
            echo "> ERROR! You are currently in the backup setting directory ($backup_dir). Please change to another directory and try again."
            echo ""
            exit 1
        fi
        
        # Check if the script is in the current settings folder

        if [[ $(find "$current_dir" -name "$script_name" | wc -l) -gt 0 ]]; then
            echo "ERROR: The script is located in the current settings folder. Please move it out and try again."
            ls -a "$current_dir/$script_name"
            exit 1
        fi

        # Check if the script is in the backup settings folder

        if [[ $(find "$backup_dir" -name "$script_name" | wc -l) -gt 0 ]]; then
            echo "ERROR: The script is located in the backup settings folder. Please move it out and try again."
            ls -a "$backup_dir/$script_name"
            exit 1
        fi
    fi

    if [[ "$FORCE" < 1 ]]; then
        # Compare current and backup directories and inform user about changes
        echo "Comparing current and backup repository configurations..."

        # Check for new files in the current configuration not present in the backup
        new_files=$(comm -23 <(ls "$current_dir" | sort) <(ls "$backup_dir" | sort) | grep -v 'oraclelinux7.repo')
        if [ -n "$new_files" ]; then
            echo ". The following new files have been added in the current repository configuration:"
            echo "$new_files"
            echo "> IT IS OK! These files will be kept after the ROLLBACK."
        else
            echo ". No new files found."
        fi

        # Check for modified files, ignoring 'enabled=0' vs 'enabled=1' differences
        echo ""
        echo "Checking for other modifications..."
        modified_files=()
        for file in $(ls "$backup_dir"); do
            if [ -f "$current_dir/$file" ]; then
                # Ignore differences in 'enabled=0' vs 'enabled=1'
                diff_output=$(diff <(grep -v '^enabled=' "$current_dir/$file" | sed -E '/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*[01]/d') <(grep -v '^enabled=' "$backup_dir/$file" | sed -E '/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*[01]/d'))

                if [ -n "$diff_output" ]; then
                    modified_files+=("$file")
                fi
            fi
        done

        if [ "${#modified_files[@]}" -gt 0 ]; then
            echo ". The following files have been modified (excluding 'enabled' flag changes):"
            for file in "${modified_files[@]}"; do
                echo "$file"
            done
            echo "> WARNING! Modifications on these files will be lost after the ROLLBACK."
        else
            echo ". No significant modifications found."
        fi

        # Confirm rollback
        echo ""
        echo "Are you sure you want to rollback to the previous repository configuration?"
        read -p "Current setting will be lost, confirm (y/N): " confirm
        echo ""
        confirm=${confirm:-N}
    else
        confirm=Y
    fi

    # Rollback process
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Copy new files to the backup directory before rollback
        if [ -n "$new_files" ]; then
            echo "Copying new files to the backup..."
            for file in $new_files; do
                cp -Rdp "$current_dir/$file" "$backup_dir/"
            done
        fi

        # Perform rollback by deleting the current directory and replacing it with the backup
        echo "Performing rollback..."
        echo ""

        rm -rf "$current_dir"
        mv "$backup_dir" "$current_dir"

        # Clean and update YUM cache
        echo "Cleaning yum cache and updating..."
        echo ""

        yum clean all || handle_error
        echo ""
        yum makecache || handle_error
        echo ""

        echo "> COMPLETED! Previous repository configuration has been restored."
        echo ""
    else
        echo "Rollback canceled."
        echo ""
        exit 0
    fi
}

# Main logic to handle migrate, rollback, and status
case "$1" in
    status)
        status
        ;;
    migrate)
        migrate_oracle_repo
        ;;
    rollback)
        rollback_repo
        ;;
    *)
        usage
        ;;
esac
