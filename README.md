# Kubernetes Security Training Lab

A comprehensive hands-on security training lab for learning web application security and Kubernetes hardening.

## 📁 Structure

```
k8s-security-lab/
├── setup/
│   └── 01-SETUP-GUIDE.md         # Complete setup instructions
├── beginner/                      # Weeks 1-2
│   ├── 01-SQL-INJECTION.md       # SQL injection attacks
│   ├── 02-XSS-ATTACKS.md         # Cross-site scripting
│   └── 03-RECONNAISSANCE.md      # Scanning and enumeration
├── intermediate/                  # Weeks 3-4
│   ├── 01-AUTHENTICATION-ATTACKS.md  # Brute force, sessions
│   └── 02-CSRF-IDOR.md           # CSRF and access control
├── advanced/                      # Weeks 5-8
│   ├── 01-KUBERNETES-NETWORK-SECURITY.md  # Network policies
│   ├── 02-RBAC-SECRETS.md        # RBAC and secrets
│   ├── 03-CONTAINER-SECURITY.md  # Container hardening
│   └── 04-RUNTIME-SECURITY.md    # Falco, auditing
├── scripts/
│   ├── setup.sh                  # Deploy the lab
│   ├── teardown.sh               # Remove everything
│   ├── port-forward.sh           # Start port forwarding
│   └── reset.sh                  # Reset applications
└── README.md                     # This file
```

## 🚀 Quick Start

### 1. Prerequisites

- Kubernetes cluster (minikube, kind, k3s, or cloud)
- kubectl configured
- 4 CPU cores, 8GB RAM minimum

### 2. Deploy the Lab

```bash
cd scripts
chmod +x *.sh
./setup.sh
```

### 3. Access Applications

```bash
./port-forward.sh
```

| Application | URL | Credentials |
|-------------|-----|-------------|
| DVWA | http://localhost:8080 | admin/password |
| Juice Shop | http://localhost:3000 | Register new |
| WebGoat | http://localhost:8081/WebGoat | Register new |

### 4. Connect to Attack Machine

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash
```

## 📚 Learning Path

### Beginner (2 weeks)
Start here if you're new to security testing.

1. **SQL Injection** - Extract data from databases
2. **XSS Attacks** - Steal cookies, deface pages
3. **Reconnaissance** - Scan and enumerate targets

### Intermediate (2 weeks)
Build on your foundation.

1. **Authentication Attacks** - Brute force, session hijacking
2. **CSRF & IDOR** - Bypass access controls

### Advanced (4 weeks)
Kubernetes-specific security.

1. **Network Security** - Network policies, isolation
2. **RBAC & Secrets** - Permissions, secret management
3. **Container Security** - Hardening, image scanning
4. **Runtime Security** - Falco, incident response

## 🧹 Cleanup

```bash
./scripts/teardown.sh
```

## ⚠️ Warning

**This lab contains intentionally vulnerable applications.**

- Only run in isolated environments
- Never expose to the internet
- For educational purposes only

## 📖 Additional Resources

- [OWASP Top 10](https://owasp.org/Top10/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Falco Documentation](https://falco.org/docs/)
