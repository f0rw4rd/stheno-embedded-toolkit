#!/bin/bash

set -euo pipefail

error_handler() {
    local line_no=$1
    local bash_lineno=$2
    local last_command=$3
    local code=$4
    
    if [ $code -ne 0 ]; then
        log_error "ERROR: Command failed with exit code $code"
        echo "  Command: $last_command" >&2
        echo "  Line: $line_no" >&2
        echo "  Function: ${FUNCNAME[2]:-main}" >&2
        echo "  Script: ${BASH_SOURCE[1]}" >&2
    fi
}

trap 'error_handler ${LINENO} ${BASH_LINENO} "$BASH_COMMAND" $?' ERR

export -f error_handler