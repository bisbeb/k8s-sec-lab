# Advanced Module 4: Runtime Security

**Difficulty:** ⭐⭐⭐ Advanced  
**Time Required:** 2-3 hours  
**Prerequisites:** Completed Container Security module

---

## Learning Objectives

- Deploy and configure Falco for runtime security
- Create custom detection rules
- Monitor for security threats
- Respond to security incidents

---

## What is Runtime Security?

Runtime security monitors containers during execution to detect:
- Suspicious process execution
- Unexpected network connections
- File system modifications
- Privilege escalation attempts

---

## Exercise 4.1: Deploy Falco

### Install with Helm

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace monitoring \
  --set driver.kind=ebpf \
  --set tty=true
```

### Verify

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=falco
kubectl logs -n monitoring -l app.kubernetes.io/name=falco -f
```

---

## Exercise 4.2: Trigger Alerts

### Shell in Container

```bash
kubectl exec -it -n vulnerable-apps deploy/dvwa -- /bin/bash
# Triggers: "Terminal shell in container"
```

### Read Sensitive Files

```bash
kubectl exec -n vulnerable-apps deploy/dvwa -- cat /etc/shadow
# Triggers: "Read sensitive file"
```

### View Alerts

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=falco | grep -i warning
```

---

## Exercise 4.3: Custom Rules

```yaml
# custom-rules.yaml
- rule: Crypto Miner Detected
  desc: Detect cryptocurrency miners
  condition: >
    spawned_process and container and
    (proc.name in (xmrig, minerd) or 
     proc.cmdline contains "stratum+tcp")
  output: "Crypto miner (command=%proc.cmdline container=%container.name)"
  priority: CRITICAL

- rule: Reverse Shell
  desc: Detect reverse shell attempts
  condition: >
    spawned_process and container and
    proc.cmdline contains "/dev/tcp"
  output: "Reverse shell (command=%proc.cmdline container=%container.name)"
  priority: CRITICAL
```

---

## Exercise 4.4: kube-bench Audit

```bash
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
  namespace: monitoring
spec:
  template:
    spec:
      hostPID: true
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:latest
        command: ["kube-bench"]
      restartPolicy: Never
  backoffLimit: 0
EOF

kubectl logs job/kube-bench -n monitoring
```

---

## Exercise 4.5: Incident Response

### Isolate Compromised Pod

```bash
# Apply deny-all network policy
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-compromised
  namespace: vulnerable-apps
spec:
  podSelector:
    matchLabels:
      app: dvwa
  policyTypes:
  - Ingress
  - Egress
EOF

# Scale down
kubectl scale deployment dvwa -n vulnerable-apps --replicas=0

# Collect evidence
kubectl logs deploy/dvwa -n vulnerable-apps > evidence.log
```

---

## Summary

- ✅ Falco deployment and monitoring
- ✅ Custom detection rules
- ✅ Security auditing with kube-bench
- ✅ Incident response procedures

---

## Course Complete! 🎉

### Beginner
1. ✅ SQL Injection
2. ✅ XSS Attacks  
3. ✅ Reconnaissance

### Intermediate
1. ✅ Authentication Attacks
2. ✅ CSRF and IDOR

### Advanced
1. ✅ Kubernetes Network Security
2. ✅ RBAC and Secrets
3. ✅ Container Security
4. ✅ Runtime Security
