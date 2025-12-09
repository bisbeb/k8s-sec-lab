# Advanced Module 1: Kubernetes Network Security

**Difficulty:** ⭐⭐⭐ Advanced  
**Time Required:** 3-4 hours  
**Prerequisites:** Completed Intermediate modules, Kubernetes basics

---

## Learning Objectives

- Implement Network Policies for pod isolation
- Understand Kubernetes network model
- Create defense-in-depth network architectures
- Monitor and audit network traffic

---

## Kubernetes Network Model

### Default Behavior

By default, Kubernetes allows **all** pod-to-pod communication:

```bash
# From Kali, test connectivity to all services
kubectl exec -it -n attacker deploy/kali-attacker -- curl -s http://dvwa-service.vulnerable-apps.svc.cluster.local
kubectl exec -it -n attacker deploy/kali-attacker -- curl -s http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000
```

**This is a security risk!** Compromised pods can attack other services.

---

## Exercise 1.1: Default Deny Policy

### Create Default Deny

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

### Verify Isolation

```bash
# This should now timeout
kubectl exec -it -n attacker deploy/kali-attacker -- \
  curl -s --max-time 5 http://dvwa-service.vulnerable-apps.svc.cluster.local

# Even within the namespace, pods can't communicate
kubectl exec -it -n vulnerable-apps deploy/dvwa -- \
  curl -s --max-time 5 http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000
```

---

## Exercise 1.2: Allow DNS

Without DNS, pods can't resolve service names:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

---

## Exercise 1.3: Selective Allow Policies

### Allow Ingress from Attacker Namespace (for lab)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-attacker
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          security-zone: attack
EOF
```

### Allow Only Specific Pods

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dvwa-only
  namespace: vulnerable-apps
spec:
  podSelector:
    matchLabels:
      app: dvwa
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          security-zone: attack
    ports:
    - protocol: TCP
      port: 80
EOF
```

### Verify

```bash
# Should work (DVWA allowed)
kubectl exec -it -n attacker deploy/kali-attacker -- \
  curl -s --max-time 5 http://dvwa-service.vulnerable-apps.svc.cluster.local

# Should fail (Juice Shop not allowed)
kubectl exec -it -n attacker deploy/kali-attacker -- \
  curl -s --max-time 5 http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000
```

---

## Exercise 1.4: Egress Restrictions

### Restrict Outbound Traffic

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: vulnerable-apps
spec:
  podSelector:
    matchLabels:
      app: dvwa
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
  # Allow internal database only
  - to:
    - podSelector:
        matchLabels:
          app: mysql
    ports:
    - protocol: TCP
      port: 3306
EOF
```

This prevents compromised pods from:
- Downloading malware
- Communicating with C2 servers
- Exfiltrating data

---

## Exercise 1.5: Complete Segmentation

### Production-Like Network Policy Set

```bash
kubectl apply -f - <<'EOF'
# Default deny everything
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow DNS for all pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - ports:
    - protocol: UDP
      port: 53
---
# Allow ingress from ingress controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
---
# Allow monitoring to scrape metrics
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: vulnerable-apps
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          security-zone: monitoring
    ports:
    - protocol: TCP
      port: 9090
EOF
```

---

## Exercise 1.6: Audit Network Policies

### List All Policies

```bash
kubectl get networkpolicies --all-namespaces
```

### Analyze Policy

```bash
kubectl describe networkpolicy default-deny -n vulnerable-apps
```

### Test Connectivity Matrix

```bash
#!/bin/bash
# network-test.sh

NAMESPACES="vulnerable-apps attacker monitoring"
TARGETS=(
  "dvwa-service.vulnerable-apps.svc.cluster.local:80"
  "juice-shop-service.vulnerable-apps.svc.cluster.local:3000"
  "elasticsearch.monitoring.svc.cluster.local:9200"
)

echo "Network Connectivity Matrix"
echo "==========================="

for ns in $NAMESPACES; do
  POD=$(kubectl get pods -n $ns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$POD" ]; then continue; fi
  
  echo ""
  echo "From namespace: $ns"
  
  for target in "${TARGETS[@]}"; do
    result=$(kubectl exec -n $ns $POD -- curl -s --max-time 2 -o /dev/null -w "%{http_code}" http://$target 2>/dev/null || echo "BLOCKED")
    printf "  → %-50s : %s\n" "$target" "$result"
  done
done
```

---

## Knowledge Check

1. What happens without Network Policies?
2. Why is a default-deny policy important?
3. How do you allow DNS while denying other traffic?
4. What's the difference between Ingress and Egress policies?

<details>
<summary>✅ Answers</summary>

1. All pods can communicate with all other pods
2. It implements zero-trust networking - explicit allow required
3. Create egress policy allowing only UDP/TCP port 53 to kube-dns
4. Ingress controls incoming traffic; Egress controls outgoing traffic

</details>

---

## Summary

- ✅ Default deny policies
- ✅ Selective allow rules
- ✅ Namespace isolation
- ✅ Egress restrictions
- ✅ Network policy auditing

### Next Steps

Continue to: **Advanced Module 2: RBAC and Secrets**

---

## Quick Reference

### Network Policy Template

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-name
  namespace: target-namespace
spec:
  podSelector:
    matchLabels:
      app: target-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: allowed-ns
    - podSelector:
        matchLabels:
          app: allowed-app
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 443
```
