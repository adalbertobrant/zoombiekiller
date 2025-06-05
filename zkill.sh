#!/usr/bin/env bash
#
# zkill.sh - Zombie Process Killer & Analyzer
# Description: Detects, analyzes, and optionally kills parent processes of zombies.
#              Includes logging and cron-friendly features.
# Version: 3.0
# (c) 2023-2025 - DevOps Toolkit / Adalberto Brant
# License: The Unlicense

set -euo pipefail

# --- Configuration & Colors ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Default Settings
KILL_PARENT_PROCESSES=false
FORCE_KILL=false
VERBOSE_MODE=false
LOG_FILE=""
CRON_MODE=false
INTERACTIVE_MODE_USER_REQUESTED=false # User explicitly requests interactive mode
DEFAULT_LOG_DIR="$HOME/.zkill"
DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/zkill.log"

# --- Helper Functions ---

# Function to log messages
log_message() {
    local type="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_entry="[$timestamp] [$type] $message"

    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$log_entry" >> "$LOG_FILE"
    fi

    # Also print to stdout if not in cron mode or if verbose
    if [[ "$VERBOSE_MODE" == "true" ]] && [[ "$CRON_MODE" == "false" ]]; then
        case "$type" in
            INFO) echo -e "${GREEN}$log_entry${NC}" ;;
            WARN) echo -e "${YELLOW}$log_entry${NC}" ;;
            ERROR) echo -e "${RED}$log_entry${NC}" ;;
            DEBUG) echo -e "${BLUE}$log_entry${NC}" ;;
            *) echo -e "$log_entry" ;;
        esac
    elif [[ "$CRON_MODE" == "false" ]] && [[ "$type" != "DEBUG" ]]; then
         case "$type" in
            INFO) echo -e "${GREEN}$message${NC}" ;; # No timestamp for non-cron, non-verbose normal messages
            WARN) echo -e "${YELLOW}$message${NC}" ;;
            ERROR) echo -e "${RED}$message${NC}" ;;
            *) echo -e "$message" ;;
        esac
    fi
}

# Ensure log directory and file exist and are writable
setup_logging() {
    if [[ -n "$LOG_FILE_USER_SPECIFIED" ]]; then
        LOG_FILE="$LOG_FILE_USER_SPECIFIED"
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" || {
                echo -e "${RED}Error: Could not create log directory $log_dir. Please check permissions.${NC}" >&2
                LOG_FILE="" # Disable logging if directory can't be created
                return 1
            }
        fi
    elif [[ "$CRON_MODE" == "true" ]] || [[ "$VERBOSE_MODE" == "true" ]] ; then # Default logging for cron or verbose
        if [[ ! -d "$DEFAULT_LOG_DIR" ]]; then
            mkdir -p "$DEFAULT_LOG_DIR" || {
                echo -e "${RED}Error: Could not create default log directory $DEFAULT_LOG_DIR.${NC}" >&2
                LOG_FILE=""
                return 1
            }
        fi
        LOG_FILE="$DEFAULT_LOG_FILE"
    fi

    if [[ -n "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || {
            echo -e "${RED}Error: Could not create or touch log file $LOG_FILE. Logging disabled.${NC}" >&2
            LOG_FILE=""
            return 1
        }
        log_message "INFO" "zkill.sh session started."
        log_message "DEBUG" "Arguments: $*"
        log_message "DEBUG" "KILL_PARENT_PROCESSES=$KILL_PARENT_PROCESSES, FORCE_KILL=$FORCE_KILL, VERBOSE_MODE=$VERBOSE_MODE, CRON_MODE=$CRON_MODE, LOG_FILE=$LOG_FILE"
    fi
}


show_header() {
    if [[ "$CRON_MODE" == "false" ]]; then
        echo -e "${GREEN}"
        echo "╔═══════════════════════════════════════════════╗"
        echo "║        ZKİLL - ZOMBIE PROCESS MANAGER v3.0    ║"
        echo "║        (c) 2023-2025 - DevOps Toolkit         ║"
        echo "╚═══════════════════════════════════════════════╝"
        echo -e "${NC}"
    fi
}

usage() {
    echo -e "${YELLOW}Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --kill          : Enable killing parent processes of zombies (uses SIGTERM)."
    echo "  --force         : Use SIGKILL instead of SIGTERM when --kill is active."
    echo "  --interactive   : Run in interactive mode, asking for confirmation before actions."
    echo "  --verbose       : Show detailed information and log to default file ($DEFAULT_LOG_FILE)."
    echo "  --log FILE      : Specify a custom log file path. Enables logging."
    echo "  --cron          : Cron mode (minimal output, logs to --log file or default if not set)."
    echo "  --help          : Display this help message."
    echo -e "${NC}"
    exit 0
}

# Detect zombie processes
# Returns: Array of zombie process lines (PID PPID USER STAT CMD)
# Sets global ZOMBIE_COUNT
declare -a ZOMBIES_INFO
ZOMBIE_COUNT=0

detect_zombies() {
    ZOMBIES_INFO=()
    ZOMBIE_COUNT=0
    local raw_zombies
    # Using ps command compatible with most systems.
    # -o fields: pid, ppid, user (effective user), stat (process state), comm (command name), args (full command)
    # Some systems might use 's' for stat, 'state' for longer stat. 'stat' is widely supported.
    # For cmd, 'args' or 'command' is usually better than 'cmd' or 'comm' for full path.
    raw_zombies=$(ps -eo pid=,ppid=,user=,stat=,args= | awk '$4 ~ /^[Zz]/')

    if [[ -n "$raw_zombies" ]]; then
        while IFS= read -r line; do
            ZOMBIES_INFO+=("$line")
            ((ZOMBIE_COUNT++))
        done <<< "$raw_zombies"
    fi

    if [[ "$ZOMBIE_COUNT" -eq 0 ]]; then
        log_message "INFO" "No zombie processes detected."
        return 0
    else
        log_message "WARN" "$ZOMBIE_COUNT zombie process(es) detected."
        return 1 # Indicates zombies were found
    fi
}

analyze_and_display_zombies() {
    if [[ "$ZOMBIE_COUNT" -eq 0 ]]; then
        return
    fi

    if [[ "$CRON_MODE" == "false" ]]; then
        echo -e "\n${CYAN}🔍 Analyzing zombie processes...${NC}\n"
        printf "%-10s %-8s %-15s %-6s %-s\n" "ZOMBIE_PID" "PPID" "USER" "STAT" "COMMAND"
        echo "-------------------------------------------------------------------------------------"
    fi

    for zombie_line in "${ZOMBIES_INFO[@]}"; do
        # shellcheck disable=SC2086 # We want word splitting here
        local z_pid z_ppid z_user z_stat z_cmd
        read -r z_pid z_ppid z_user z_stat z_cmd <<< "$zombie_line"

        if [[ "$CRON_MODE" == "false" ]]; then
            printf "%-10s %-8s %-15s %-6s %-s\n" "$z_pid" "$z_ppid" "$z_user" "$z_stat" "${z_cmd:0:60}"
        fi
        log_message "DEBUG" "Zombie Detail: PID=$z_pid, PPID=$z_ppid, USER=$z_user, STAT=$z_stat, CMD=$z_cmd"

        # Parent process info
        if [[ "$VERBOSE_MODE" == "true" ]] && [[ "$CRON_MODE" == "false" ]]; then
            local p_info
            p_info=$(ps -p "$z_ppid" -o pid=,user=,stat=,args= --no-headers 2>/dev/null || echo "Parent process $z_ppid not found or access denied.")
            echo -e "  ${BLUE}└─ Parent (PPID: $z_ppid): $p_info${NC}"
            log_message "DEBUG" "Parent (PPID: $z_ppid) info: $p_info"
        fi
    done

    if [[ "$CRON_MODE" == "false" ]]; then
        echo -e "\n${YELLOW}⚠ Zombie processes are defunct children waiting for their parent to reap them (call wait()).${NC}"
        echo -e "${YELLOW}ℹ They don't consume CPU/Memory but occupy slots in the process table.${NC}"
    fi
}

kill_zombie_parents() {
    if ! $KILL_PARENT_PROCESSES || [[ "$ZOMBIE_COUNT" -eq 0 ]]; then
        if $KILL_PARENT_PROCESSES && [[ "$ZOMBIE_COUNT" -eq 0 ]]; then
             log_message "INFO" "Kill action requested, but no zombies to process."
        fi
        return
    fi

    local signal="-SIGTERM"
    local signal_name="SIGTERM"
    if [[ "$FORCE_KILL" == "true" ]]; then
        signal="-SIGKILL"
        signal_name="SIGKILL"
    fi

    log_message "WARN" "Attempting to kill parent processes of zombies using $signal_name."
    if [[ "$CRON_MODE" == "false" ]]; then
        echo -e "\n${RED}⚠ Attempting to send $signal_name to parent processes of zombies.${NC}"
        echo -e "${RED}This can lead to data loss or terminate important services if parent is critical.${NC}"
        if [[ "$INTERACTIVE_MODE_USER_REQUESTED" == "false" ]] && ! $FORCE_KILL; then # Auto-proceed if not interactive and not forced
             echo -e "${YELLOW}Proceeding automatically as not in interactive mode. Use --interactive for manual confirmation.${NC}"
        fi
    fi


    local killed_parents_count=0
    local distinct_ppids
    # Get unique PPIDs to avoid trying to kill the same parent multiple times
    distinct_ppids=$(printf "%s\n" "${ZOMBIES_INFO[@]}" | awk '{print $2}' | sort -u)

    for ppid in $distinct_ppids; do
        if [[ "$ppid" -eq 1 ]]; then # Skip init/systemd
            log_message "WARN" "Skipping kill attempt for PPID 1 (init/systemd)."
            if [[ "$CRON_MODE" == "false" ]]; then
                 echo -e "${YELLOW}ℹ Skipping attempt to kill PPID 1 (init/systemd).${NC}"
            fi
            continue
        fi

        local parent_cmd
        parent_cmd=$(ps -p "$ppid" -o args= --no-headers 2>/dev/null || echo "Unknown")

        if [[ "$INTERACTIVE_MODE_USER_REQUESTED" == "true" ]]; then
            local confirm_kill
            # shellcheck disable=SC2229 # `read -r` is fine here
            read -rp "$(echo -e "${YELLOW}❓ Do you want to send $signal_name to parent process PPID $ppid ($parent_cmd)? (y/N): ${NC}")" confirm_kill
            if [[ ! "$confirm_kill" =~ ^[yY]$ ]]; then
                log_message "INFO" "Skipped killing PPID $ppid by user choice."
                if [[ "$CRON_MODE" == "false" ]]; then
                    echo -e "${YELLOW}⏩ Skipping PPID $ppid.${NC}"
                fi
                continue
            fi
        fi

        log_message "WARN" "Sending $signal_name to PPID $ppid (Command: $parent_cmd)."
        if kill "$signal" "$ppid"; then
            log_message "INFO" "Successfully sent $signal_name to PPID $ppid."
            if [[ "$CRON_MODE" == "false" ]]; then
                echo -e "${GREEN}✔ Signal $signal_name sent to PPID $ppid.${NC}"
            fi
            ((killed_parents_count++))
        else
            log_message "ERROR" "Failed to send $signal_name to PPID $ppid."
            if [[ "$CRON_MODE" == "false" ]]; then
                echo -e "${RED}✖ Failed to send $signal_name to PPID $ppid. It might already be gone or you lack permissions.${NC}"
            fi
        fi
    done

    if [[ "$CRON_MODE" == "false" ]]; then
        if [[ "$killed_parents_count" -gt 0 ]]; then
            echo -e "\n${GREEN}✔ $killed_parents_count parent process(es) signaled.${NC}"
        elif $KILL_PARENT_PROCESSES; then # only show if kill was attempted
            echo -e "\n${YELLOW}ℹ No parent processes were signaled (or eligible for signaling).${NC}"
        fi
    fi
    log_message "INFO" "$killed_parents_count parent process(es) signaled."
}

# --- Argument Parsing ---
# Use a temporary variable for LOG_FILE specified by user to distinguish from default
LOG_FILE_USER_SPECIFIED=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kill)
            KILL_PARENT_PROCESSES=true
            shift
            ;;
        --force)
            FORCE_KILL=true # Implies --kill, but let user specify --kill explicitly for clarity
            shift
            ;;
        --interactive)
            INTERACTIVE_MODE_USER_REQUESTED=true
            CRON_MODE=false # Interactive overrides cron
            shift
            ;;
        --verbose)
            VERBOSE_MODE=true
            shift
            ;;
        --log)
            if [[ -n "${2:-}" ]]; then
                LOG_FILE_USER_SPECIFIED="$2"
                shift 2
            else
                echo -e "${RED}Error: --log option requires a file path.${NC}" >&2
                usage
            fi
            ;;
        --cron)
            CRON_MODE=true
            INTERACTIVE_MODE_USER_REQUESTED=false # Cron overrides interactive
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
            usage
            ;;
    esac
done

# --- Main Execution ---
# Setup logging based on parsed arguments
# Pass all original script arguments to setup_logging for debug purposes
setup_logging "$@" # Call after parsing all args

show_header # Show header if not in cron mode

log_message "INFO" "Starting zombie detection."
if ! detect_zombies; then # zombies were found
    analyze_and_display_zombies

    if $KILL_PARENT_PROCESSES; then
        kill_zombie_parents
        if [[ "$CRON_MODE" == "false" ]]; then
            echo -e "\n${CYAN}📊 Performing post-kill check in a few seconds...${NC}"
        fi
        log_message "INFO" "Waiting for processes to terminate before post-kill check."
        sleep 3 # Give time for processes to terminate

        log_message "INFO" "Starting post-kill zombie detection."
        if ! detect_zombies; then # zombies still found
            log_message "WARN" "Post-kill check: Zombie processes still present."
            if [[ "$CRON_MODE" == "false" ]]; then
                echo -e "\n${RED}⚠ Post-kill check: Zombie processes may still be present!${NC}"
                analyze_and_display_zombies # Show remaining zombies
            fi
        else
            log_message "INFO" "Post-kill check: All targeted zombie processes appear to be cleared."
            if [[ "$CRON_MODE" == "false" ]]; then
                 echo -e "\n${GREEN}✅ Post-kill check: No zombies detected related to killed parents (or no parents were killed).${NC}"
            fi
        fi
    else
        if [[ "$ZOMBIE_COUNT" -gt 0 ]]; then
             log_message "INFO" "Analysis mode only. To attempt cleanup, use the --kill option."
             if [[ "$CRON_MODE" == "false" ]]; then
                echo -e "\n${YELLOW}ℹ Analysis mode only. To attempt cleanup, run with '--kill'.${NC}"
                echo -e "${YELLOW}  Example: $0 --kill${NC}"
                echo -e "${YELLOW}  Example (force kill): $0 --kill --force${NC}"
             fi
        fi
    fi
else # No zombies found initially
    if [[ "$CRON_MODE" == "false" ]]; then
        echo -e "${GREEN}✅ System clean. No zombie processes found.${NC}"
    fi
fi

log_message "INFO" "zkill.sh session finished."
exit 0
