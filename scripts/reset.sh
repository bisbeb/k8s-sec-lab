#!/bin/bash
#
# Kubernetes Security Lab - Reset Script
# Resets vulnerable applications to their initial state
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_usage() {
    echo "Usage: $0 [app|all]"
    echo ""
    echo "Options:"
    echo "  dvwa       Reset DVWA only"
    echo "  juice      Reset Juice Shop only"
    echo "  webgoat    Reset WebGoat only"
    echo "  kali       Reset Kali attacker pod"
    echo "  all        Reset all applications (default)"
    echo ""
    echo "Examples:"
    echo "  $0 dvwa    # Reset only DVWA"
    echo "  $0 all     # Reset everything"
    echo "  $0         # Reset everything (same as 'all')"
}

reset_dvwa() {
    echo -e "${BLUE}[*]${NC} Resetting DVWA..."
    kubectl rollout restart deployment/dvwa -n vulnerable-apps
    kubectl wait --for=condition=ready pod -l app=dvwa -n vulnerable-apps --timeout=120s
    echo -e "${GREEN}[✓]${NC} DVWA reset complete"
    echo -e "${YELLOW}    Note: You'll need to click 'Create / Reset Database' again${NC}"
}

reset_juice_shop() {
    echo -e "${BLUE}[*]${NC} Resetting Juice Shop..."
    kubectl rollout restart deployment/juice-shop -n vulnerable-apps
    kubectl wait --for=condition=ready pod -l app=juice-shop -n vulnerable-apps --timeout=120s
    echo -e "${GREEN}[✓]${NC} Juice Shop reset complete"
}

reset_webgoat() {
    echo -e "${BLUE}[*]${NC} Resetting WebGoat..."
    kubectl rollout restart deployment/webgoat -n vulnerable-apps
    kubectl wait --for=condition=ready pod -l app=webgoat -n vulnerable-apps --timeout=120s
    echo -e "${GREEN}[✓]${NC} WebGoat reset complete"
}

reset_kali() {
    echo -e "${BLUE}[*]${NC} Resetting Kali (this will take 5-10 minutes to reinstall tools)..."
    kubectl rollout restart deployment/kali-attacker -n attacker
    echo -e "${GREEN}[✓]${NC} Kali reset initiated"
    echo -e "${YELLOW}    Tools are being reinstalled in background...${NC}"
}

reset_all() {
    echo -e "${BLUE}[*]${NC} Resetting all applications..."
    echo ""
    reset_dvwa
    echo ""
    reset_juice_shop
    echo ""
    reset_webgoat
    echo ""
    reset_kali
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}All applications have been reset!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
}

# Main
case "${1:-all}" in
    dvwa)
        reset_dvwa
        ;;
    juice|juice-shop|juiceshop)
        reset_juice_shop
        ;;
    webgoat)
        reset_webgoat
        ;;
    kali)
        reset_kali
        ;;
    all)
        reset_all
        ;;
    -h|--help|help)
        print_usage
        ;;
    *)
        echo "Unknown option: $1"
        print_usage
        exit 1
        ;;
esac
