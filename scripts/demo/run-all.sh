#!/bin/bash
###############################################################################
# AI Security Platform - Demo Runner
# Orchestrates all 6 demo scenarios sequentially
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$REPO_DIR/docs/demo/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"

source "$SCRIPT_DIR/demo-common.sh"

banner() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║          🎯 AI SECURITY PLATFORM — DEMO RUNNER              ║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Timestamp:${NC}  $TIMESTAMP"
    echo -e "  ${CYAN}Results:${NC}    $RUN_DIR"
    echo ""
    echo -e "  ${CYAN}URLs:${NC}"
    echo -e "    Open WebUI:   $OPENWEBUI_URL"
    echo -e "    Guardrails:   $GUARDRAILS_URL"
    echo -e "    Grafana:      $GRAFANA_URL"
    echo -e "    Prometheus:   $PROMETHEUS_URL"
    echo -e "    Keycloak:     $KEYCLOAK_URL"
    echo -e "    Qdrant:       $QDRANT_URL"
    echo ""
}

separator() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_prerequisites() {
    echo -e "${CYAN}🔍 Checking prerequisites...${NC}"
    local ok=true

    for cmd in kubectl curl jq python3; do
        if command -v $cmd &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $cmd"
        else
            echo -e "  ${RED}✗${NC} $cmd not found"
            ok=false
        fi
    done

    # Cluster
    if kubectl cluster-info &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} K3d cluster"
    else
        echo -e "  ${RED}✗${NC} Cluster unreachable"
        ok=false
    fi

    # Traefik URLs
    for url_name in GUARDRAILS_URL OPENWEBUI_URL GRAFANA_URL PROMETHEUS_URL KEYCLOAK_URL; do
        url="${!url_name}"
        HTTP_CODE=$($CURL -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [[ "$HTTP_CODE" =~ ^[23] ]]; then
            echo -e "  ${GREEN}✓${NC} $url_name ($HTTP_CODE)"
        else
            echo -e "  ${RED}✗${NC} $url_name ($HTTP_CODE)"
            ok=false
        fi
    done

    if [[ "$ok" == false ]]; then
        echo -e "\n${RED}❌ Prerequisites not met. Fix and retry.${NC}"
        exit 1
    fi
    echo -e "\n${GREEN}✅ All prerequisites OK${NC}"
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
        echo -e "  ${RED}Script not found: $script${NC}"
        return 1
    fi
}

summary() {
    separator
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                    ✅ DEMO COMPLETE                          ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Results:${NC} $RUN_DIR"
    echo ""
    find "$RUN_DIR" -type f | sort | while read -r f; do
        echo -e "    📄 ${f#$RUN_DIR/}"
    done
    echo ""
    echo -e "  ${CYAN}Next steps:${NC}"
    echo "    1. Add screenshots to docs/demo/screenshots/"
    echo "    2. git add docs/demo/ && git commit -m 'docs: demo results $(date +%Y-%m-%d)'"
    echo "    3. git push"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

banner
check_prerequisites

mkdir -p "$RUN_DIR"

run_scenario "01" "chat"       "$BLUE"
run_scenario "02" "rag"        "$GREEN"
run_scenario "03" "injection"  "$RED"
run_scenario "04" "secrets"    "$YELLOW"
run_scenario "05" "runtime"    "$PURPLE"
run_scenario "06" "compliance" "$CYAN"

summary
