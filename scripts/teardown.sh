#!/bin/bash
#
# Kubernetes Security Lab - Teardown Script
# This script removes all components of the security training lab
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Kubernetes Security Lab - Teardown Script             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Confirmation prompt
confirm_teardown() {
    echo -e "${YELLOW}WARNING: This will delete all lab resources!${NC}"
    echo ""
    echo "The following namespaces will be deleted:"
    echo "  - vulnerable-apps (DVWA, Juice Shop, WebGoat)"
    echo "  - attacker (Kali Linux)"
    echo "  - monitoring (Elasticsearch, Kibana)"
    echo "  - secure-zone"
    echo ""
    
    if [[ "$1" != "-y" && "$1" != "--yes" ]]; then
        read -p "Are you sure you want to continue? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Teardown cancelled."
            exit 0
        fi
    fi
}

# Kill port forwards
kill_port_forwards() {
    print_status "Stopping port forwards..."
    
    # Kill kubectl port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true
    pkill -f "port-forward.*vulnerable-apps" 2>/dev/null || true
    pkill -f "port-forward.*monitoring" 2>/dev/null || true
    
    print_success "Port forwards stopped"
}

# Delete resources in namespace before deleting namespace
cleanup_namespace() {
    local ns=$1
    
    if kubectl get namespace "$ns" &>/dev/null; then
        print_status "Cleaning up namespace: $ns"
        
        # Delete all resources
        kubectl delete all --all -n "$ns" --timeout=60s 2>/dev/null || true
        kubectl delete configmaps --all -n "$ns" --timeout=30s 2>/dev/null || true
        kubectl delete secrets --all -n "$ns" --timeout=30s 2>/dev/null || true
        kubectl delete pvc --all -n "$ns" --timeout=30s 2>/dev/null || true
        kubectl delete networkpolicies --all -n "$ns" --timeout=30s 2>/dev/null || true
        kubectl delete rolebindings --all -n "$ns" --timeout=30s 2>/dev/null || true
        kubectl delete roles --all -n "$ns" --timeout=30s 2>/dev/null || true
        kubectl delete serviceaccounts --all -n "$ns" --timeout=30s 2>/dev/null || true
        
        print_success "Resources in $ns cleaned up"
    fi
}

# Delete namespace
delete_namespace() {
    local ns=$1
    
    if kubectl get namespace "$ns" &>/dev/null; then
        print_status "Deleting namespace: $ns"
        kubectl delete namespace "$ns" --timeout=120s 2>/dev/null || \
            kubectl delete namespace "$ns" --force --grace-period=0 2>/dev/null || true
        print_success "Namespace $ns deleted"
    else
        print_warning "Namespace $ns not found (already deleted?)"
    fi
}

# Delete cluster-wide resources
delete_cluster_resources() {
    print_status "Cleaning up cluster-wide resources..."
    
    # Delete ClusterRoleBindings created by lab
    kubectl delete clusterrolebinding security-reader-binding 2>/dev/null || true
    kubectl delete clusterrolebinding dangerous-admin-binding 2>/dev/null || true
    
    # Delete ClusterRoles created by lab
    kubectl delete clusterrole security-reader 2>/dev/null || true
    kubectl delete clusterrole dangerous-admin 2>/dev/null || true
    
    # Delete any Kyverno policies if installed
    kubectl delete clusterpolicy --all 2>/dev/null || true
    
    print_success "Cluster resources cleaned up"
}

# Main teardown
main() {
    confirm_teardown "$1"
    
    echo ""
    print_status "Starting teardown..."
    echo ""
    
    # Stop port forwards first
    kill_port_forwards
    
    # Clean up each namespace
    for ns in vulnerable-apps attacker monitoring secure-zone; do
        cleanup_namespace "$ns"
    done
    
    echo ""
    
    # Delete namespaces
    for ns in vulnerable-apps attacker monitoring secure-zone; do
        delete_namespace "$ns"
    done
    
    # Clean up cluster resources
    delete_cluster_resources
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                   Teardown Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "All lab resources have been removed."
    echo ""
    echo "To redeploy the lab, run:"
    echo "  ./scripts/setup.sh"
    echo ""
}

main "$@"
