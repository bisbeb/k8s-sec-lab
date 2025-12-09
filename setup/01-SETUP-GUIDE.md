# Kubernetes Security Lab - Setup Guide

## Overview

This guide walks you through setting up a complete Kubernetes security training lab. The lab includes vulnerable applications, attack tools, and monitoring infrastructure.

---

## Prerequisites

### Required Software

| Software | Minimum Version | Purpose |
|----------|----------------|---------|
| kubectl | 1.28+ | Kubernetes CLI |
| Helm | 3.0+ | Package manager |
| Docker | 24.0+ | Container runtime (for local clusters) |

### Cluster Options

Choose one of the following:

#### Option A: Minikube (Recommended for beginners)

```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server
```

#### Option B: kind (Kubernetes in Docker)

```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster with config
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
  - containerPort: 30300
    hostPort: 3000
  - containerPort: 30081
    hostPort: 8081
EOF
```

#### Option C: k3s (Lightweight)

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Verify Cluster

```bash
# Check cluster is running
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes

# Check available resources
kubectl top nodes
```

---

## Resource Requirements

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| DVWA | 100m | 128Mi | 500m | 512Mi |
| Juice Shop | 200m | 256Mi | 500m | 512Mi |
| WebGoat | 200m | 512Mi | 1000m | 1Gi |
| Kali Linux | 500m | 512Mi | 2000m | 2Gi |
| Elasticsearch | 500m | 1Gi | 1000m | 2Gi |
| Kibana | 200m | 256Mi | 500m | 512Mi |
| **Total** | **1.7 cores** | **2.7Gi** | **5.5 cores** | **7Gi** |

**Minimum Cluster Size:** 4 CPU cores, 8GB RAM

---

## Quick Start

### Step 1: Clone or Create Lab Files

```bash
# Create lab directory
mkdir -p ~/k8s-security-lab
cd ~/k8s-security-lab

# Download all files (or copy from this guide)
# Structure:
# ├── setup/
# ├── beginner/
# ├── intermediate/
# ├── advanced/
# └── scripts/
```

### Step 2: Run Setup Script

```bash
# Make executable
chmod +x scripts/setup.sh

# Run setup
./scripts/setup.sh
```

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods --all-namespaces -l purpose=security-training

# Expected output: All pods should show STATUS: Running
```

### Step 4: Access Applications

```bash
# Start port forwarding (run in background or separate terminals)
./scripts/port-forward.sh

# Access in browser:
# DVWA:       http://localhost:8080
# Juice Shop: http://localhost:3000
# WebGoat:    http://localhost:8081/WebGoat
# Kibana:     http://localhost:5601
```

---

## Manual Setup (Step by Step)

If you prefer to set up manually or the script fails:

### Create Namespaces

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: vulnerable-apps
  labels:
    purpose: security-training
    security-zone: untrusted
---
apiVersion: v1
kind: Namespace
metadata:
  name: attacker
  labels:
    purpose: security-training
    security-zone: attack
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    purpose: security-training
    security-zone: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: secure-zone
  labels:
    purpose: security-training
    security-zone: trusted
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
EOF
```

### Deploy DVWA

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dvwa
  namespace: vulnerable-apps
  labels:
    purpose: security-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dvwa
  template:
    metadata:
      labels:
        app: dvwa
        purpose: security-training
    spec:
      containers:
      - name: dvwa
        image: vulnerables/web-dvwa:latest
        ports:
        - containerPort: 80
          name: http
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "dvwa"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: dvwa-service
  namespace: vulnerable-apps
spec:
  selector:
    app: dvwa
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
EOF
```

### Deploy Juice Shop

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: juice-shop
  namespace: vulnerable-apps
  labels:
    purpose: security-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: juice-shop
  template:
    metadata:
      labels:
        app: juice-shop
        purpose: security-training
    spec:
      containers:
      - name: juice-shop
        image: bkimminich/juice-shop:latest
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: juice-shop-service
  namespace: vulnerable-apps
spec:
  selector:
    app: juice-shop
  ports:
  - port: 3000
    targetPort: 3000
    name: http
  type: ClusterIP
EOF
```

### Deploy WebGoat

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webgoat
  namespace: vulnerable-apps
  labels:
    purpose: security-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webgoat
  template:
    metadata:
      labels:
        app: webgoat
        purpose: security-training
    spec:
      containers:
      - name: webgoat
        image: webgoat/webgoat:latest
        ports:
        - containerPort: 8080
          name: webgoat
        - containerPort: 9090
          name: webwolf
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: webgoat-service
  namespace: vulnerable-apps
spec:
  selector:
    app: webgoat
  ports:
  - name: webgoat
    port: 8080
    targetPort: 8080
  - name: webwolf
    port: 9090
    targetPort: 9090
  type: ClusterIP
EOF
```

### Deploy Kali Linux Attacker

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kali-attacker
  namespace: attacker
  labels:
    purpose: security-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kali
  template:
    metadata:
      labels:
        app: kali
        purpose: security-training
    spec:
      containers:
      - name: kali
        image: kalilinux/kali-rolling:latest
        command: ["/bin/bash", "-c"]
        args:
        - |
          apt-get update && \
          DEBIAN_FRONTEND=noninteractive apt-get install -y \
            sqlmap nikto nmap curl wget \
            dirb gobuster hydra netcat-openbsd \
            python3 python3-pip vim jq dnsutils \
            whatweb wfuzz sslscan && \
          pip3 install requests beautifulsoup4 pyjwt --break-system-packages && \
          echo "Kali tools installed successfully" && \
          tail -f /dev/null
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2"
        securityContext:
          privileged: false
EOF
```

### Deploy Monitoring Stack

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: monitoring
  labels:
    purpose: security-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
        purpose: security-training
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        ports:
        - containerPort: 9200
        env:
        - name: discovery.type
          value: single-node
        - name: xpack.security.enabled
          value: "false"
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: monitoring
spec:
  selector:
    app: elasticsearch
  ports:
  - port: 9200
    targetPort: 9200
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: monitoring
  labels:
    purpose: security-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
        purpose: security-training
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:8.11.0
        ports:
        - containerPort: 5601
        env:
        - name: ELASTICSEARCH_HOSTS
          value: "http://elasticsearch:9200"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: monitoring
spec:
  selector:
    app: kibana
  ports:
  - port: 5601
    targetPort: 5601
EOF
```

---

## Initial Configuration

### DVWA Setup

1. Access DVWA at http://localhost:8080
2. Click "Create / Reset Database"
3. Login with `admin` / `password`
4. Go to "DVWA Security" → Set to "Low" for beginners

### Juice Shop Setup

1. Access Juice Shop at http://localhost:3000
2. Register a new account
3. Explore the application

### WebGoat Setup

1. Access WebGoat at http://localhost:8081/WebGoat
2. Register a new account
3. Start with the Introduction lessons

---

## Connecting to Kali

```bash
# Connect to Kali pod
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# Verify tools are installed
which sqlmap nmap nikto hydra

# Test connectivity to targets
curl -s http://dvwa-service.vulnerable-apps.svc.cluster.local | head -5
curl -s http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000 | head -5
```

---

## Learning Path

After setup, proceed through the guides in order:

### Beginner (Weeks 1-2)
1. `beginner/01-SQL-INJECTION.md` - SQL Injection fundamentals
2. `beginner/02-XSS-ATTACKS.md` - Cross-Site Scripting
3. `beginner/03-RECONNAISSANCE.md` - Information gathering

### Intermediate (Weeks 3-4)
1. `intermediate/01-AUTHENTICATION-ATTACKS.md` - Brute force, session hijacking
2. `intermediate/02-CSRF-IDOR.md` - CSRF and access control
3. `intermediate/03-API-SECURITY.md` - JWT and API vulnerabilities

### Advanced (Weeks 5-8)
1. `advanced/01-KUBERNETES-NETWORK-SECURITY.md` - Network policies
2. `advanced/02-RBAC-SECRETS.md` - RBAC and secrets management
3. `advanced/03-CONTAINER-SECURITY.md` - Container escapes, image scanning
4. `advanced/04-RUNTIME-SECURITY.md` - Falco, supply chain security

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -A -l purpose=security-training

# Describe failing pod
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| ImagePullBackOff | Can't pull image | Check internet connectivity |
| CrashLoopBackOff | Container crashing | Check logs: `kubectl logs <pod>` |
| Pending | No resources | Increase cluster resources |
| Kali tools missing | Init not complete | Wait 5-10 minutes, or restart pod |

### Reset Everything

```bash
./scripts/teardown.sh
./scripts/setup.sh
```

---

## Next Steps

1. Complete the setup verification checklist below
2. Read `beginner/01-SQL-INJECTION.md`
3. Start your first exercise!

### Setup Verification Checklist

- [ ] All namespaces created
- [ ] DVWA accessible and database initialized
- [ ] Juice Shop accessible
- [ ] WebGoat accessible
- [ ] Kali pod running with tools installed
- [ ] Can connect from Kali to vulnerable apps
- [ ] Monitoring stack running (optional)
