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

- Kubernetes cluster (minikube, kind, k3s, Podman, or cloud)
- kubectl configured
- 4 CPU cores, 8GB RAM minimum

### 2. Deploy the Lab

```bash
cd k8s-security-lab
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 3. Access Applications

```bash
./scripts/port-forward.sh
```

| Application | URL | Credentials |
|-------------|-----|-------------|
| DVWA | http://localhost:8080 | admin / password |
| Juice Shop | http://localhost:3000 | Register new |
| WebGoat | http://localhost:8081/WebGoat | Register new |
| Kibana | http://localhost:5601 | No auth |

### 4. Initialize DVWA

1. Open http://localhost:8080
2. Click **"Create / Reset Database"**
3. Login: `admin` / `password`
4. Set security level to **Low**

### 5. Connect to Attack Machine

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash
```

---

## 📊 Configure Kibana for Log Monitoring

The lab includes ELK stack (Elasticsearch + Kibana) with Fluent Bit for log collection.

### Create Data View (Index Pattern)

1. Open Kibana: http://localhost:5601

2. Go to **☰ Menu → Stack Management → Data Views**

3. Click **Create data view**

4. Configure:
   - **Name:** `k8s-logs`
   - **Index pattern:** `k8s-logs-*`
   - **Timestamp field:** `@timestamp`

5. Click **Save data view to Kibana**

### View Logs

1. Go to **☰ Menu → Discover**
2. Select the `k8s-logs` data view
3. Add useful columns from the left sidebar:
   - `kubernetes.namespace_name`
   - `kubernetes.container_name`
   - `log`

### Useful KQL Queries

```bash
# Filter by namespace
kubernetes.namespace_name: "vulnerable-apps"

# Filter by application
kubernetes.container_name: "dvwa"

# Detect SQL injection attempts
log: *UNION* OR log: *SELECT* OR log: *1=1*

# Detect XSS attempts
log: *<script>* OR log: *alert(* OR log: *onerror*

# Detect reconnaissance tools
log: *nikto* OR log: *sqlmap* OR log: *nmap*

# Show errors only
log: *error* OR log: *ERROR*

# Traffic from attacker namespace
kubernetes.namespace_name: "attacker"
```

---

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

---

## 🧹 Cleanup

```bash
./scripts/teardown.sh
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    vulnerable-apps namespace                     │
│  ┌─────────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ DVWA Pod        │  │ Juice Shop  │  │ WebGoat             │  │
│  │ ┌─────┐ ┌─────┐ │  │             │  │                     │  │
│  │ │DVWA │ │Maria│ │  │  Port 3000  │  │  Port 8080/9090     │  │
│  │ │:80  │ │DB   │ │  │             │  │                     │  │
│  │ └─────┘ └─────┘ │  └─────────────┘  └─────────────────────┘  │
│  └─────────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      attacker namespace                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Kali Linux Pod                                           │    │
│  │ Tools: sqlmap, nikto, nmap, hydra, gobuster, etc.       │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     monitoring namespace                         │
│  ┌───────────────┐  ┌────────┐  ┌────────────────────────────┐  │
│  │ Elasticsearch │  │ Kibana │  │ Fluent Bit (DaemonSet)     │  │
│  │    :9200      │  │ :5601  │  │ Collects logs from nodes   │  │
│  └───────────────┘  └────────┘  └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Warning

**This lab contains intentionally vulnerable applications.**

- Only run in isolated environments
- Never expose to the internet
- For educational purposes only

---

## 🔧 Troubleshooting

### DVWA not starting
```bash
# Check both containers (should be 2/2 ready)
kubectl get pods -n vulnerable-apps -l app=dvwa
kubectl logs -n vulnerable-apps -l app=dvwa -c dvwa
kubectl logs -n vulnerable-apps -l app=dvwa -c mysql
```

### No logs in Kibana
```bash
# Check Fluent Bit
kubectl get pods -n monitoring -l app=fluent-bit
kubectl logs -n monitoring -l app=fluent-bit

# Check Elasticsearch indices
kubectl port-forward -n monitoring svc/elasticsearch 9200:9200 &
curl http://localhost:9200/_cat/indices?v
```

### Kali tools not installed
```bash
# Wait 5-10 minutes, or check progress
kubectl logs -n attacker deploy/kali-attacker
```

---

## 📖 Additional Resources

- [OWASP Top 10](https://owasp.org/Top10/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Falco Documentation](https://falco.org/docs/)
