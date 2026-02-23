#!/bin/bash
###############################################################################
# AI Security Platform - Demo Runner
# Author: Z3ROX
# Description: Orchestrates all 6 demo scenarios sequentially
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$REPO_DIR/docs/demo/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

banner() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║          🎯 AI SECURITY PLATFORM — DEMO RUNNER              ║${NC}"
    echo -e "${BOLD}${BLUE}║          Testing all 6 security scenarios                    ║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Timestamp:${NC} $TIMESTAMP"
    echo -e "  ${CYAN}Results:${NC}   $RUN_DIR"
    echo ""
}

separator() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

screenshot_prompt() {
    local msg="$1"
    local url="${2:-}"
    echo ""
    echo -e "  ${YELLOW}📸 SCREENSHOT:${NC} $msg"
    [[ -n "$url" ]] && echo -e "  ${YELLOW}   URL:${NC} $url"
    echo ""
    read -p "  Press ENTER when screenshot is taken (or 's' to skip)... " -n 1 -r choice
    echo ""
    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
        echo -e "  ${YELLOW}⏭️  Skipped${NC}"
    else
        echo -e "  ${GREEN}✅ Captured${NC}"
    fi
}

check_prerequisites() {
    echo -e "${CYAN}🔍 Checking prerequisites...${NC}"
    
    local ok=true
    
    for cmd in kubectl curl jq; do
        if command -v $cmd &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $cmd"
        else
            echo -e "  ${RED}✗${NC} $cmd not found"
            ok=false
        fi
    done

    # Check cluster
    if kubectl cluster-info &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} K3d cluster reachable"
    else
        echo -e "  ${RED}✗${NC} Cluster not reachable"
        ok=false
    fi

    # Check key pods
    for ns_pod in "ai-apps/open-webui" "ai-inference/ollama" "ai-inference/guardrails-api" "falco/falco" "observability/prometheus"; do
        ns="${ns_pod%%/*}"
        name="${ns_pod##*/}"
        count=$(kubectl get pods -n "$ns" 2>/dev/null | grep -c "$name.*Running" || true)
        if [[ $count -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} $name ($ns)"
        else
            echo -e "  ${RED}✗${NC} $name ($ns) — not running"
            ok=false
        fi
    done

    if [[ "$ok" == false ]]; then
        echo -e "\n${RED}❌ Prerequisites not met. Fix issues above and retry.${NC}"
        exit 1
    fi

    echo -e "\n${GREEN}✅ All prerequisites OK${NC}"
}

# Create results directory
setup_results() {
    mkdir -p "$RUN_DIR"
    echo -e "${CYAN}📁 Results directory: $RUN_DIR${NC}"
}

run_scenario() {
    local num="$1"
    local name="$2"
    local color="$3"
    local script="$SCRIPT_DIR/demo-${num}-${name}.sh"

    separator
    echo -e "${BOLD}${color}▶ SCENARIO ${num}: $(echo "$name" | tr '[:lower:]' '[:upper:]')${NC}"

    if [[ -x "$script" ]]; then
        "$script" "$RUN_DIR"
    else
        echo -e "  ${RED}Script not found or not executable: $script${NC}"
        return 1
    fi
}

summary() {
    separator
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                    ✅ DEMO COMPLETE                          ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Results saved to:${NC} $RUN_DIR"
    echo ""
    echo -e "  ${CYAN}Files generated:${NC}"
    find "$RUN_DIR" -type f | sort | while read -r f; do
        echo -e "    📄 ${f#$RUN_DIR/}"
    done
    echo ""
    echo -e "  ${CYAN}Next steps:${NC}"
    echo -e "    1. Add screenshots to docs/demo/screenshots/"
    echo -e "    2. git add docs/demo/ && git commit -m 'docs: demo results'"
    echo -e "    3. git push"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

banner
check_prerequisites
setup_results

run_scenario "01" "chat"       "$BLUE"
run_scenario "02" "rag"        "$GREEN"
run_scenario "03" "injection"  "$RED"
run_scenario "04" "secrets"    "$YELLOW"
run_scenario "05" "runtime"    "$PURPLE"
run_scenario "06" "compliance" "$CYAN"

summary
