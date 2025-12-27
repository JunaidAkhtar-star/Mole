#!/usr/bin/env bash

# Set strict error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Determine script locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function for clean logging
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1" >&2; }
log_err()  { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

# 1. Linting Phase (ShellCheck)
if command -v shellcheck > /dev/null 2>&1; then
    log_info "Linting shell scripts..."
    
    # Efficiently collect targets into an array
    SHELLCHECK_TARGETS=()
    while IFS= read -r file; do
        SHELLCHECK_TARGETS+=("$file")
    done < <(find "$PROJECT_ROOT/tests" -type f \( -name '*.bats' -o -name '*.sh' \) | sort)

    if [[ ${#SHELLCHECK_TARGETS[@]} -gt 0 ]]; then
        # Check for .shellcheckrc, otherwise use default
        if [[ -f "$PROJECT_ROOT/.shellcheckrc" ]]; then
            shellcheck --rcfile "$PROJECT_ROOT/.shellcheckrc" "${SHELLCHECK_TARGETS[@]}"
        else
            shellcheck "${SHELLCHECK_TARGETS[@]}"
        fi
        log_info "Linting passed."
    else
        log_warn "No shell files found in tests/ for linting."
    fi
else
    log_warn "shellcheck not found; skipping linting phase."
fi

# 2. Test Execution Phase (Bats)
if command -v bats > /dev/null 2>&1; then
    cd "$PROJECT_ROOT"

    # Ensure TERM is set for colored output support
    export TERM="${TERM:-xterm-256color}"

    # Default to 'tests' directory if no arguments provided
    if [[ $# -eq 0 ]]; then
        set -- tests
    fi

    log_info "Running BATS test suite..."

    # Execution logic based on TTY (Interactive vs CI)
    if [[ -t 1 ]]; then
        # Interactive mode: Pretty formatting (falls back to default if --pretty is unsupported)
        bats --pretty "$@" || bats "$@"
    else
        # CI/Automated mode: TAP output for machine readability
        bats --tap "$@"
    fi
else
    log_err "bats-core is required to run the test suite."
    cat << 'EOF' >&2

To install BATS:
  - macOS: brew install bats-core
  - npm:   npm install -g bats
  - Linux: sudo apt-get install bats (or use the bats-core repo)

EOF
    exit 1
fi
