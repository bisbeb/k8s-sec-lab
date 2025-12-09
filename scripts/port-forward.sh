#!/bin/bash
#
# Kubernetes Security Lab - Port Forward Script
# Starts port forwarding for all lab services
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Starting Port Forwards for Security Lab             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Kill existing port forwards
echo -e "${YELLOW}[*] Stopping any existing port forwards...${NC}"
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

# Start port forwards
echo -e "${BLUE}[*] Starting port forwards...${NC}"

kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &>/dev/null &
echo -e "${GREEN}[✓]${NC} DVWA:       http://localhost:8080"

kubectl port-forward -n vulnerable-apps svc/juice-shop-service 3000:3000 &>/dev/null &
echo -e "${GREEN}[✓]${NC} Juice Shop: http://localhost:3000"

kubectl port-forward -n vulnerable-apps svc/webgoat-service 8081:8080 &>/dev/null &
echo -e "${GREEN}[✓]${NC} WebGoat:    http://localhost:8081/WebGoat"

kubectl port-forward -n monitoring svc/kibana 5601:5601 &>/dev/null &
echo -e "${GREEN}[✓]${NC} Kibana:     http://localhost:5601"

echo ""
echo -e "${GREEN}All port forwards started in background.${NC}"
echo ""
echo "To stop all port forwards:"
echo "  pkill -f 'kubectl port-forward'"
echo ""
echo "Press Ctrl+C to exit this script (port forwards will continue)"
echo ""

# Wait to keep script running (optional)
wait
