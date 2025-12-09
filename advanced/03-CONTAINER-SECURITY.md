# Advanced Module 3: Container Security

**Difficulty:** ⭐⭐⭐ Advanced  
**Time Required:** 3-4 hours  
**Prerequisites:** Completed RBAC module

---

## Learning Objectives

- Understand container isolation mechanisms
- Identify and prevent container escapes
- Implement Pod Security Standards
- Scan images for vulnerabilities
- Secure the software supply chain

---

## Part 1: Container Isolation

### What Keeps Containers Contained?

| Mechanism | Purpose |
|-----------|---------|
| Namespaces | Isolate process trees, networks, users |
| Cgroups | Limit resource usage |
| Seccomp | Filter system calls |
| AppArmor/SELinux | Mandatory access control |
| Capabilities | Fine-grained root privileges |

---

## Exercise 3.1: Analyze Container Security

### Check Container Capabilities

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: capability-test
  namespace: attacker
spec:
  containers:
  - name: test
    image: ubuntu:latest
    command: ["sleep", "3600"]
EOF

# Wait for pod
kubectl wait --for=condition=ready pod/capability-test -n attacker

# Check capabilities
kubectl exec -n attacker capability-test -- cat /proc/1/status | grep Cap
```

### Decode Capabilities

```bash
# CapEff (Effective capabilities)
kubectl exec -n attacker capability-test -- \
  sh -c 'apt-get update && apt-get install -y libcap2-bin && capsh --decode=$(cat /proc/1/status | grep CapEff | awk "{print \$2}")'
```

---

## Exercise 3.2: Privileged Container Risks

### Deploy Privileged Pod (DANGEROUS!)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged-test
  namespace: attacker
spec:
  containers:
  - name: priv
    image: ubuntu:latest
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
EOF
```

### Demonstrate Container Escape

```bash
kubectl exec -it -n attacker privileged-test -- bash

# Inside the container - you have full host access!
# List host devices
ls -la /dev/

# Mount host filesystem
mkdir -p /mnt/host
mount /dev/sda1 /mnt/host 2>/dev/null || mount /dev/vda1 /mnt/host
ls /mnt/host/

# Read host's /etc/shadow (if mounted)
cat /mnt/host/etc/shadow

# Exit
exit
```

**This is why privileged containers are dangerous!**

---

## Exercise 3.3: Hardened Pod Configuration

### Create Secure Pod

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
  namespace: secure-zone
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
      requests:
        memory: "64Mi"
        cpu: "250m"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF
```

### Verify Security Settings

```bash
kubectl exec -n secure-zone hardened-pod -- whoami
# nobody (UID 65534)

kubectl exec -n secure-zone hardened-pod -- touch /test
# Read-only file system error

kubectl exec -n secure-zone hardened-pod -- cat /etc/shadow
# Permission denied
```

---

## Exercise 3.4: Pod Security Standards

### Enable PSS on Namespace

```bash
kubectl label namespace secure-zone \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```

### Test Policy Enforcement

```bash
# This should be REJECTED
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: secure-zone
spec:
  containers:
  - name: bad
    image: nginx
    securityContext:
      privileged: true
EOF
# Error: violates PodSecurity "restricted"
```

---

## Part 2: Image Security

## Exercise 3.5: Image Scanning with Trivy

### Install Trivy

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- bash

# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

### Scan Vulnerable Images

```bash
# Scan DVWA
trivy image vulnerables/web-dvwa:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL bkimminich/juice-shop:latest

# JSON output for automation
trivy image --format json --output scan.json nginx:latest
```

### Sample Output

```
vulnerables/web-dvwa:latest
===========================
Total: 847 (UNKNOWN: 0, LOW: 425, MEDIUM: 298, HIGH: 102, CRITICAL: 22)

┌──────────────────┬────────────────┬──────────┬─────────────────────┐
│     Library      │ Vulnerability  │ Severity │  Installed Version  │
├──────────────────┼────────────────┼──────────┼─────────────────────┤
│ openssl          │ CVE-2021-3711  │ CRITICAL │ 1.1.0g-2            │
│ php7.0           │ CVE-2019-11043 │ CRITICAL │ 7.0.33-0            │
└──────────────────┴────────────────┴──────────┴─────────────────────┘
```

---

## Exercise 3.6: Supply Chain Security

### Sign Images with Cosign

```bash
# Install cosign
curl -LO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
mv cosign-linux-amd64 /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair

# Sign an image (requires push access)
# cosign sign --key cosign.key your-registry/image:tag

# Verify a signature
# cosign verify --key cosign.pub your-registry/image:tag
```

### Generate SBOM

```bash
# Install syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generate SBOM
syft nginx:latest -o spdx-json > nginx-sbom.json

# Scan SBOM for vulnerabilities
# grype sbom:nginx-sbom.json
```

---

## Exercise 3.7: Image Policy with Kyverno

### Install Kyverno

```bash
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.11.0/install.yaml
```

### Block Latest Tag

```bash
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
  - name: require-image-tag
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Using 'latest' tag is not allowed."
      pattern:
        spec:
          containers:
          - image: "!*:latest"
EOF
```

### Test Policy

```bash
# This should be rejected
kubectl run test --image=nginx:latest
# Error: Using 'latest' tag is not allowed

# This should work
kubectl run test --image=nginx:1.25
```

---

## Security Checklist

### Container Hardening

- [ ] Run as non-root user
- [ ] Read-only root filesystem
- [ ] Drop all capabilities
- [ ] No privilege escalation
- [ ] Seccomp profile enabled
- [ ] Resource limits set

### Image Security

- [ ] Scan images for vulnerabilities
- [ ] Use minimal base images
- [ ] Pin image versions (no `latest`)
- [ ] Sign and verify images
- [ ] Generate SBOMs
- [ ] Use private registries

### Runtime Security

- [ ] Enable Pod Security Standards
- [ ] Monitor for anomalies
- [ ] Log container activity
- [ ] Regular security audits

---

## Summary

- ✅ Container isolation mechanisms
- ✅ Container escape risks
- ✅ Pod Security Standards
- ✅ Image vulnerability scanning
- ✅ Supply chain security

### Next Steps

Continue to: **Advanced Module 4: Runtime Security**
