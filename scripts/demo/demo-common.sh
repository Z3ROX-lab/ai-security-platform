#!/bin/bash
###############################################################################
# Demo Common Library
# Shared functions and Traefik URLs for all demo scenario scripts
###############################################################################

# =============================================================================
# Traefik URLs — All services via ingress, zero port-forward
# =============================================================================
OPENWEBUI_URL="https://chat.ai-platform.localhost"
GUARDRAILS_URL="https://guardrails.ai-platform.localhost"
QDRANT_URL="https://qdrant.ai-platform.localhost"
RAG_URL="https://rag.ai-platform.localhost"
GRAFANA_URL="https://grafana.ai-platform.localhost"
PROMETHEUS_URL="https://prometheus.ai-platform.localhost"
ALERTMANAGER_URL="https://alertmanager.ai-platform.localhost"
KEYCLOAK_URL="https://auth.ai-platform.localhost"
ARGOCD_URL="https://argocd.ai-platform.localhost"

# curl with self-signed cert support
CURL="curl -sk --max-time 60"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  $1$(printf '%*s' $((58 - ${#1})) '')║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

step() {
    echo ""
    echo -e "  ${BOLD}${CYAN}[$1]${NC} ${BOLD}$2${NC}"
    echo -e "  ${CYAN}$(printf '%.0s─' {1..60})${NC}"
}

pass() { echo -e "  ${GREEN}✅ PASS:${NC} $1"; }
fail() { echo -e "  ${RED}❌ FAIL:${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️  WARN:${NC} $1"; }
info() { echo -e "  ${BLUE}ℹ️ ${NC} $1"; }

result() {
    echo ""
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}✅ $1${NC}"
    echo -e "  ${CYAN}Results:${NC} $2"
    [[ -d "$2" ]] && find "$2" -type f | sort | while read -r f; do echo -e "    📄 $(basename "$f")"; done
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

screenshot_prompt() {
    echo ""
    echo -e "  ${YELLOW}📸 SCREENSHOT:${NC} $1"
    [[ -n "${2:-}" ]] && echo -e "  ${YELLOW}   URL:${NC} $2"
    echo ""
    if [[ -t 0 ]]; then
        read -p "  Press ENTER when done (or 's' to skip)... " -r choice
        [[ "$choice" == "s" || "$choice" == "S" ]] && echo -e "  ${YELLOW}⏭️  Skipped${NC}" || echo -e "  ${GREEN}✅ Captured${NC}"
    fi
}

get_pod() {
    kubectl get pods -n "$1" --no-headers 2>/dev/null | grep "$2" | grep Running | head -1 | awk '{print $1}'
}
