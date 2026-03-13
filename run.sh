#!/bin/bash
# 5-Agent Autonomous Build System - Main Entry Point
# Version 6.0.0
#
# Usage:
#   ./run.sh path/to/doc.md                    # Process single document
#   ./run.sh path/to/folder/                   # Process all .md files in folder
#   ./run.sh path/to/folder/ --parallel        # Process in parallel (experimental)

set -euo pipefail

# ══════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${SCRIPT_DIR}/.claude"
CONFIG_PATH="${CLAUDE_DIR}/agents/config.yaml"
AGENTS_PATH="${CLAUDE_DIR}/agents/agents.yaml"
ORCHESTRATOR_SCRIPT="${SCRIPT_DIR}/orchestrator.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ══════════════════════════════════════════════════════════════
# FUNCTIONS
# ══════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_phase() {
    echo -e "${MAGENTA}▸${NC} $1"
}

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     5-AGENT AUTONOMOUS BUILD SYSTEM v6.0                    ║
║                                                              ║
║     Orchestrator → Planner → Validator → Builder            ║
║                      ↓          ↓          ↓                 ║
║                   Tester ←  Reviewer                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if .claude directory exists
    if [[ ! -d "${CLAUDE_DIR}" ]]; then
        log_error ".claude directory not found at: ${CLAUDE_DIR}"
        log_error "Please ensure the system is properly installed."
        exit 1
    fi

    # Check if config files exist
    if [[ ! -f "${CONFIG_PATH}" ]]; then
        log_error "config.yaml not found at: ${CONFIG_PATH}"
        exit 1
    fi

    if [[ ! -f "${AGENTS_PATH}" ]]; then
        log_error "agents.yaml not found at: ${AGENTS_PATH}"
        exit 1
    fi

    # Check if orchestrator script exists (we'll create this next)
    if [[ ! -f "${ORCHESTRATOR_SCRIPT}" ]]; then
        log_warning "orchestrator.sh not found - will create stub"
        create_orchestrator_stub
    fi

    log_success "Prerequisites check passed"
}

create_orchestrator_stub() {
    cat > "${ORCHESTRATOR_SCRIPT}" << 'EOFORCH'
#!/bin/bash
# Orchestrator Stub - To be implemented
# This is where the full orchestrator implementation goes

echo "🤖 ORCHESTRATOR starting..."
echo "   Doc: $1"
echo "   Output: $2"
echo ""
echo "⚠ This is a stub. Full implementation needed:"
echo "   1. Spawn PLANNER with doc"
echo "   2. Read plan.interface-check.md"
echo "   3. For each phase: VALIDATE → BUILD → TEST → REVIEW loop"
echo "   4. Final integration test"
echo "   5. Write FINAL_SUMMARY.md"
echo ""
echo "See .claude/agents/orchestrator/PROTOCOL.md for full spec"
EOFORCH
    chmod +x "${ORCHESTRATOR_SCRIPT}"
}

get_doc_name() {
    local doc_path="$1"
    basename "${doc_path}" .md
}

create_output_structure() {
    local doc_path="$1"
    local doc_name=$(get_doc_name "${doc_path}")
    local output_dir="${SCRIPT_DIR}/${doc_name}"

    log_info "Creating output structure for: ${doc_name}"

    # Create main output directory
    mkdir -p "${output_dir}"

    # Create placeholder directories (phases will be created by Planner)
    # mkdir -p "${output_dir}/phases"

    # Copy doc to output directory for reference
    cp "${doc_path}" "${output_dir}/doc.md"

    echo "${output_dir}"
}

process_single_document() {
    local doc_path="$1"
    local doc_name=$(get_doc_name "${doc_path}")

    echo ""
    log_phase "═══════════════════════════════════════════════════════"
    log_phase "Processing: ${doc_name}"
    log_phase "═══════════════════════════════════════════════════════"
    echo ""

    # Validate document exists
    if [[ ! -f "${doc_path}" ]]; then
        log_error "Document not found: ${doc_path}"
        return 1
    fi

    # Create output structure
    local output_dir=$(create_output_structure "${doc_path}")
    log_success "Output directory: ${output_dir}"

    # Run orchestrator
    log_info "Spawning ORCHESTRATOR..."
    echo ""

    local start_time=$(date +%s)

    # Execute orchestrator
    bash "${ORCHESTRATOR_SCRIPT}" \
        "${output_dir}/doc.md" \
        "${output_dir}" \
        "${CONFIG_PATH}" \
        "${AGENTS_PATH}"

    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""

    # Handle result
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Build completed successfully in ${duration}s"
        log_success "Results: ${output_dir}/FINAL_SUMMARY.md"
        return 0
    elif [[ ${exit_code} -eq 2 ]]; then
        log_warning "Build paused - waiting for user input"
        log_info "Check: ${output_dir}/QUESTIONS.md"
        return 2
    else
        log_error "Build failed (exit code: ${exit_code})"
        log_info "Check: ${output_dir}/.claude/memory/RUN_STATE.md"
        return 1
    fi
}

process_folder() {
    local folder_path="$1"
    local parallel="${2:-false}"

    log_info "Processing all .md files in: ${folder_path}"

    # Find all .md files
    local docs=()
    while IFS= read -r -d '' doc; do
        docs+=("$doc")
    done < <(find "${folder_path}" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)

    if [[ ${#docs[@]} -eq 0 ]]; then
        log_error "No .md files found in: ${folder_path}"
        exit 1
    fi

    log_info "Found ${#docs[@]} document(s) to process"
    echo ""

    # Process each document
    local success_count=0
    local fail_count=0
    local pause_count=0

    for doc in "${docs[@]}"; do
        if [[ "${parallel}" == "true" ]]; then
            # Parallel processing (experimental)
            process_single_document "${doc}" &
        else
            # Sequential processing (default)
            process_single_document "${doc}"
            local result=$?

            if [[ ${result} -eq 0 ]]; then
                ((success_count++))
            elif [[ ${result} -eq 2 ]]; then
                ((pause_count++))
            else
                ((fail_count++))
            fi
        fi
    done

    # Wait for parallel jobs if applicable
    if [[ "${parallel}" == "true" ]]; then
        wait
        log_warning "Parallel mode: Check individual output directories for results"
    fi

    # Print summary
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "BATCH PROCESSING SUMMARY"
    echo "════════════════════════════════════════════════════════"
    echo "Total documents: ${#docs[@]}"
    echo -e "${GREEN}Success: ${success_count}${NC}"
    echo -e "${YELLOW}Paused: ${pause_count}${NC}"
    echo -e "${RED}Failed: ${fail_count}${NC}"
    echo "════════════════════════════════════════════════════════"
}

show_usage() {
    cat << EOF
Usage: $0 <input> [options]

Process software requirements documents with the 5-agent autonomous build system.

Arguments:
    <input>         Path to a .md file OR a folder containing .md files

Options:
    --parallel      Process multiple documents in parallel (experimental)
    --help          Show this help message

Examples:
    # Process single document
    $0 requirements.md

    # Process all documents in a folder
    $0 ./pocs/

    # Process folder in parallel (experimental)
    $0 ./pocs/ --parallel

Exit Codes:
    0    Build complete - FINAL_SUMMARY.md written
    1    Build failed - check RUN_STATE.md
    2    Waiting for user input - check QUESTIONS.md

For more information, see .claude/README.md
EOF
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

main() {
    # Parse arguments
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi

    local input_path="$1"
    local parallel="false"

    if [[ $# -gt 1 ]] && [[ "$2" == "--parallel" ]]; then
        parallel="true"
    fi

    # Print banner
    print_banner

    # Check prerequisites
    check_prerequisites

    # Determine if input is file or folder
    if [[ -f "${input_path}" ]]; then
        # Single file
        if [[ "${input_path}" != *.md ]]; then
            log_error "File must be a .md file: ${input_path}"
            exit 1
        fi

        process_single_document "${input_path}"
        exit $?

    elif [[ -d "${input_path}" ]]; then
        # Folder
        process_folder "${input_path}" "${parallel}"
        exit 0

    else
        log_error "Input not found: ${input_path}"
        log_error "Please provide a valid .md file or folder path"
        exit 1
    fi
}

main "$@"
