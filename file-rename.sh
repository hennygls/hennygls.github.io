#!/bin/sh
# File Renaming Utility for EG Data
# Version: 20260525-3
# Purpose: Rename meterdata and report CSV files with date and location prefix
# Features: Auto-mode (option 6) runs all locations sequentially with file wait
# op windows PC start Umbuntu , en pas het script aan. Dir naar jouw download lokatie
# run het script b.v. sh file_renamer_Version2.sh
# 
# select optie 6 = alle files , je moet hier dus eerst de 2 files van Rijnvicus exporteren
# het script wacht 60 sec tot ze gedownload zijn in 'download' directory
# Als ze er beide zijn , worden ze gerenamed , en wacht het script op de files van Benthuizen etc.

set -e  # Exit on error

# ============= CONFIGURATION =============
Dir="/mnt/c/Users/henny/Downloads"
LOG_FILE="${Dir}/file_renamer.log"
MAX_WAIT_SECONDS=60
CHECK_INTERVAL=1

# ============= FUNCTIONS =============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

show_menu() {
    cat << 'EOF'
Select location:
  1 | r = Rijnvicus
  2 | b = Benthuizen
  3 | d = Demo2EA
  4 | h = Hazerswoude
  5 | a = Alphen
  6     = Auto (run all 1-5 sequentially)
EOF
}

wait_for_files() {
    local location=$1
    local elapsed=0
    
    log "Waiting for files ($location)... (max ${MAX_WAIT_SECONDS}s)"
    
    while [ $elapsed -lt $MAX_WAIT_SECONDS ]; do
        if [ -f "meterdata.csv" ] && [ -f "report.csv" ]; then
            log "✓ Files found after ${elapsed} seconds"
            return 0
        fi
        
        printf "."
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
    done
    
    # Timeout reached
    echo ""  # New line after dots
    log "⚠ Timeout waiting for files ($location) after ${MAX_WAIT_SECONDS}s"
    
    # Check which files are missing
    if [ ! -f "meterdata.csv" ]; then
        log "  Missing: meterdata.csv"
    fi
    if [ ! -f "report.csv" ]; then
        log "  Missing: report.csv"
    fi
    
    return 1
}

process_location() {
    local location=$1
    
    log "=========================================="
    log "Processing location: $location"
    log "=========================================="
    
    # Wait for files with timeout
    if ! wait_for_files "$location"; then
        log "⚠ Skipping location '$location' - files not available"
        return 1
    fi
    
    # Process files
    local success=true
    for file_type in meterdata report; do
        source_file="${file_type}.csv"
        target_file="${tomorrow}_${file_type}_${location}.csv"
        
        if [ -f "$source_file" ]; then
            log "Processing: $source_file -> $target_file"
            
            if mv "$source_file" "$target_file"; then
                log "✓ Successfully renamed: $source_file -> $target_file"
                ls -lh "$target_file" | tee -a "$LOG_FILE"
            else
                log "✗ Failed to rename: $source_file to $target_file"
                success=false
            fi
        else
            log "✗ File not found: $source_file"
            success=false
        fi
    done
    
    if [ "$success" = true ]; then
        return 0
    else
        return 1
    fi
}

run_auto_mode() {
    log "=========================================="
    log "AUTO MODE: Running all locations (1-5)"
    log "=========================================="
    
    local locations="Rijnvicus Benthuizen Demo2EA Hazerswoude Alphen"
    local count=0
    local success_count=0
    
    for location in $locations; do
        count=$((count + 1))
        if process_location "$location"; then
            success_count=$((success_count + 1))
        fi
        
        # Small delay between locations
        if [ $count -lt 5 ]; then
            log "Waiting 2 seconds before next location..."
            sleep 2
        fi
    done
    
    log "=========================================="
    log "AUTO MODE SUMMARY: $success_count/$count locations processed"
    log "=========================================="
}

# ============= MAIN LOGIC =============

# Verify directory exists
if [ ! -d "$Dir" ]; then
    error "Directory not found: $Dir"
fi

cd "$Dir" || error "Cannot change to directory: $Dir"
log "Working directory: $(pwd)"

# Calculate tomorrow's date (YYMMDD format)
tomorrow=$(date -d "+1 day" "+%y%m%d" 2>/dev/null || date -v+1d "+%y%m%d" 2>/dev/null || echo "ERROR")
if [ "$tomorrow" = "ERROR" ]; then
    error "Failed to calculate tomorrow's date"
fi
log "Target date: $tomorrow"

# Show menu and get user input
show_menu
printf "\nEnter choice: "
read -r x

# Handle choice
location=""
case "$x" in
    6) run_auto_mode ;;
    a|5) location="Alphen" ;;
    b|2) location="Benthuizen" ;;
    d|3) location="Demo2EA" ;;
    h|4) location="Hazerswoude" ;;
    r|1) location="Rijnvicus" ;;
    *) error "Invalid choice: '$x'. Valid options: 1-5, a, b, d, h, r, or 6 (auto)" ;;
esac

# Process single location if selected
if [ -n "$location" ]; then
    log "Selected location: $location"
    process_location "$location"
fi

log "=== Processing complete ==="
exit 0
