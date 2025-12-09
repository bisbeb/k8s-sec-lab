# Kubernetes Security Lab - Setup Guide

## Overview

This guide walks you through setting up a complete Kubernetes security training lab.

---

## Prerequisites

### Required Software

| Software | Minimum Version | Purpose |
|----------|----------------|---------|
| kubectl | 1.28+ | Kubernetes CLI |
| Docker | 24.0+ | Container runtime |

### Cluster Options

#### Option A: Minikube (Recommended)

```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker
```

#### Option B: kind (Kubernetes in Docker)

```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name security-lab
```

#### Option C: k3s (Lightweight)

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

---

## Resource Requirements

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| DVWA + MySQL | 200m | 384Mi | 1000m | 768Mi |
| Juice Shop | 200m | 256Mi | 500m | 512Mi |
| WebGoat | 200m | 512Mi | 1000m | 1Gi |
| Kali Linux | 500m | 512Mi | 2000m | 2Gi |
| Elasticsearch | 500m | 1Gi | 1000m | 2Gi |
| Kibana | 200m | 512Mi | 500m | 1Gi |
| **Total** | **1.8 cores** | **3.2Gi** | **6 cores** | **8Gi** |

**Minimum Cluster Size:** 4 CPU cores, 8GB RAM

---

## Quick Start

### Step 1: Run Setup Script

```bash
cd k8s-security-lab
chmod +x scripts/*.sh
./scripts/setup.sh
```

### Step 2: Wait for Pods

```bash
# Check status (DVWA takes ~60 seconds for MySQL to initialize)
kubectl get pods -n vulnerable-apps -w

# All pods should show Running and Ready (e.g., 2/2 for DVWA)
```

### Step 3: Start Port Forwarding

```bash
./scripts/port-forward.sh
```

### Step 4: Access Applications

| Application | URL | Credentials |
|-------------|-----|-------------|
| DVWA | http://localhost:8080 | admin / password |
| Juice Shop | http://localhost:3000 | Register new account |
| WebGoat | http://localhost:8081/WebGoat | Register new account |
| Kibana | http://localhost:5601 | No auth |

### Step 5: Initialize DVWA

1. Open http://localhost:8080
2. Click **"Create / Reset Database"**
3. Login with `admin` / `password`
4. Go to "DVWA Security" → Set to **Low**

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    vulnerable-apps namespace                     │
│  ┌─────────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ DVWA Pod        │  │ Juice Shop  │  │ WebGoat             │  │
│  │ ┌─────┐ ┌─────┐ │  │             │  │                     │  │
│  │ │DVWA │ │MySQL│ │  │  Port 3000  │  │  Port 8080/9090     │  │
│  │ │:80  │ │:3306│ │  │             │  │                     │  │
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
```

---

## Manual Deployment

If you prefer to deploy manually:

### Create Namespaces

```bash
kubectl create namespace vulnerable-apps
kubectl create namespace attacker
kubectl create namespace monitoring
kubectl create namespace secure-zone
```

### Deploy DVWA (with MySQL sidecar)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dvwa-config
  namespace: vulnerable-apps
data:
  DB_SERVER: "127.0.0.1"
  DB_DATABASE: "dvwa"
  DB_USER: "dvwa"
  DB_PASSWORD: "p@ssw0rd"
  SECURITY_LEVEL: "low"
  PHPIDS_ENABLED: "0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dvwa
  namespace: vulnerable-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dvwa
  template:
    metadata:
      labels:
        app: dvwa
    spec:
      containers:
      - name: dvwa
        image: ghcr.io/digininja/dvwa:latest
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: dvwa-config
      - name: mysql
        image: mysql:5.7
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "dvwa"
        - name: MYSQL_DATABASE
          value: "dvwa"
        - name: MYSQL_USER
          value: "dvwa"
        - name: MYSQL_PASSWORD
          value: "p@ssw0rd"
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
EOF
```

---

## Connecting to Kali

```bash
# Connect to Kali pod
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# Verify tools
which sqlmap nmap nikto hydra

# Test connectivity to targets
curl -s http://dvwa-service.vulnerable-apps.svc.cluster.local | head -5
curl -s http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000 | head -5
```

---

## Troubleshooting

### DVWA Not Starting

```bash
# Check both containers
kubectl logs -n vulnerable-apps -l app=dvwa -c dvwa
kubectl logs -n vulnerable-apps -l app=dvwa -c mysql

# MySQL needs ~30-60 seconds to initialize
# If still failing, restart the deployment
kubectl rollout restart deployment/dvwa -n vulnerable-apps
```

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod -n vulnerable-apps -l app=dvwa

# Check resources
kubectl top nodes
```

### Kali Tools Not Installed

```bash
# Kali takes 5-10 minutes to install tools
# Check progress
kubectl logs -n attacker deploy/kali-attacker

# If tools are missing, restart
kubectl rollout restart deployment/kali-attacker -n attacker
```

### Port Forward Issues

```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart
./scripts/port-forward.sh
```

---

## Cleanup

```bash
./scripts/teardown.sh
```

Or manually:

```bash
kubectl delete namespace vulnerable-apps attacker monitoring secure-zone
```

---

## Learning Path

After setup, proceed through the guides:

### Beginner
1. `beginner/01-SQL-INJECTION.md`
2. `beginner/02-XSS-ATTACKS.md`
3. `beginner/03-RECONNAISSANCE.md`

### Intermediate
1. `intermediate/01-AUTHENTICATION-ATTACKS.md`
2. `intermediate/02-CSRF-IDOR.md`

### Advanced
1. `advanced/01-KUBERNETES-NETWORK-SECURITY.md`
2. `advanced/02-RBAC-SECRETS.md`
3. `advanced/03-CONTAINER-SECURITY.md`
4. `advanced/04-RUNTIME-SECURITY.md`
