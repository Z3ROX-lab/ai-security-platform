#!/bin/bash
###############################################################################
# Demo Common Library
# Shared functions for all demo scenario scripts
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# --- Output functions ---

header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  $1$(printf '%*s' $((58 - ${#1})) '')║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

step() {
    local num="$1"
    local msg="$2"
    echo ""
    echo -e "  ${BOLD}${CYAN}[$num]${NC} ${BOLD}$msg${NC}"
    echo -e "  ${CYAN}$(printf '%.0s─' {1..60})${NC}"
}

pass() {
    echo -e "  ${GREEN}✅ PASS:${NC} $1"
}

fail() {
    echo -e "  ${RED}❌ FAIL:${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}⚠️  WARN:${NC} $1"
}

info() {
    echo -e "  ${BLUE}ℹ️ ${NC} $1"
}

result() {
    local title="$1"
    local dir="$2"
    echo ""
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}✅ $title${NC}"
    echo -e "  ${CYAN}Results saved to:${NC} $dir"
    if [[ -d "$dir" ]]; then
        find "$dir" -type f | sort | while read -r f; do
            echo -e "    📄 $(basename "$f")"
        done
    fi
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

screenshot_prompt() {
    local msg="$1"
    local url="${2:-}"
    echo ""
    echo -e "  ${YELLOW}📸 SCREENSHOT:${NC} $msg"
    [[ -n "$url" ]] && echo -e "  ${YELLOW}   URL:${NC} $url"
    echo ""
    if [[ -t 0 ]]; then
        read -p "  Press ENTER when screenshot taken (or 's' to skip)... " -r choice
        if [[ "$choice" == "s" || "$choice" == "S" ]]; then
            echo -e "  ${YELLOW}⏭️  Skipped${NC}"
        else
            echo -e "  ${GREEN}✅ Captured${NC}"
        fi
    else
        echo -e "  ${YELLOW}⏭️  Non-interactive mode — skipped${NC}"
    fi
}

# --- Helper functions ---

get_pod() {
    local ns="$1"
    local name="$2"
    kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "$name" | grep Running | head -1 | awk '{print $1}'
}

wait_for_pod() {
    local ns="$1"
    local label="$2"
    local timeout="${3:-60}"
    kubectl wait --for=condition=Ready pod -l "$label" -n "$ns" --timeout="${timeout}s" 2>/dev/null
}
