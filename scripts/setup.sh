#!/bin/bash
#
# Kubernetes Security Lab - Setup Script
# This script deploys all components for the security training lab
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMEOUT=300

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Kubernetes Security Lab - Setup Script               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl found"
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    print_success "Connected to cluster"
}

create_namespaces() {
    print_status "Creating namespaces..."
    
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
    
    print_success "Namespaces created"
}

deploy_dvwa() {
    print_status "Deploying DVWA (with MySQL sidecar)..."
    
    kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dvwa-config
  namespace: vulnerable-apps
data:
  RECAPTCHA_PRIV_KEY: ""
  RECAPTCHA_PUB_KEY: ""
  SECURITY_LEVEL: "low"
  PHPIDS_ENABLED: "0"
  DB_SERVER: "127.0.0.1"
  DB_DATABASE: "dvwa"
  DB_USER: "dvwa"
  DB_PASSWORD: "p@ssw0rd"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dvwa
  namespace: vulnerable-apps
  labels:
    app: dvwa
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
      # DVWA Web Application
      - name: dvwa
        image: ghcr.io/digininja/dvwa:latest
        ports:
        - containerPort: 80
          name: http
        envFrom:
        - configMapRef:
            name: dvwa-config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /login.php
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 5
          failureThreshold: 10
        livenessProbe:
          httpGet:
            path: /login.php
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 10
      # MariaDB Database (sidecar) - ARM64 compatible
      - name: mysql
        image: mariadb:10.11
        env:
        - name: MARIADB_ROOT_PASSWORD
          value: "dvwa"
        - name: MARIADB_DATABASE
          value: "dvwa"
        - name: MARIADB_USER
          value: "dvwa"
        - name: MARIADB_PASSWORD
          value: "p@ssw0rd"
        ports:
        - containerPort: 3306
          name: mysql
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          exec:
            command: ["mariadb-admin", "ping", "-h", "localhost"]
          initialDelaySeconds: 20
          periodSeconds: 5
        livenessProbe:
          exec:
            command: ["mariadb-admin", "ping", "-h", "localhost"]
          initialDelaySeconds: 30
          periodSeconds: 10
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
    print_success "DVWA deployed"
}

deploy_juice_shop() {
    print_status "Deploying Juice Shop..."
    
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
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
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
EOF
    print_success "Juice Shop deployed"
}

deploy_webgoat() {
    print_status "Deploying WebGoat..."
    
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
        - containerPort: 9090
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /WebGoat
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 10
        livenessProbe:
          httpGet:
            path: /WebGoat
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
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
EOF
    print_success "WebGoat deployed"
}

deploy_kali() {
    print_status "Deploying Kali Linux (tools installation takes 5-10 min)..."
    
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
            sqlmap nikto nmap curl wget dirb gobuster hydra \
            netcat-openbsd python3 python3-pip vim jq dnsutils \
            whatweb wfuzz sslscan 2>/dev/null || true && \
          pip3 install requests beautifulsoup4 pyjwt --break-system-packages 2>/dev/null || true && \
          echo "READY" > /tmp/ready && \
          tail -f /dev/null
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2"
        readinessProbe:
          exec:
            command: ["cat", "/tmp/ready"]
          initialDelaySeconds: 60
          periodSeconds: 10
          failureThreshold: 30
EOF
    print_success "Kali deployment created"
}

deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
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
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
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
EOF
    print_success "Monitoring deployed"
}

deploy_fluent_bit() {
    print_status "Deploying Fluent Bit log collector..."
    
    kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit-read
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluent-bit-read
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluent-bit-read
subjects:
- kind: ServiceAccount
  name: fluent-bit
  namespace: monitoring
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: monitoring
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off

    [OUTPUT]
        Name            es
        Match           kube.*
        Host            elasticsearch.monitoring.svc.cluster.local
        Port            9200
        Logstash_Format On
        Logstash_Prefix k8s-logs
        Replace_Dots    On
        Retry_Limit     False
        tls             Off
        Suppress_Type_Name On

  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep   On
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: monitoring
  labels:
    app: fluent-bit
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        ports:
        - containerPort: 2020
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
        resources:
          limits:
            memory: 200Mi
            cpu: 200m
          requests:
            memory: 100Mi
            cpu: 100m
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
EOF
    print_success "Fluent Bit deployed"
}

wait_for_pods() {
    print_status "Waiting for pods to be ready..."
    
    echo ""
    print_status "Waiting for MySQL to initialize (this takes ~30-60 seconds)..."
    sleep 10
    
    print_status "Waiting for DVWA..."
    kubectl wait --for=condition=ready pod -l app=dvwa -n vulnerable-apps --timeout=${TIMEOUT}s 2>/dev/null && \
        print_success "DVWA ready" || print_warning "DVWA still starting..."
    
    print_status "Waiting for Juice Shop..."
    kubectl wait --for=condition=ready pod -l app=juice-shop -n vulnerable-apps --timeout=${TIMEOUT}s 2>/dev/null && \
        print_success "Juice Shop ready" || print_warning "Juice Shop pending"
    
    print_status "Waiting for WebGoat..."
    kubectl wait --for=condition=ready pod -l app=webgoat -n vulnerable-apps --timeout=${TIMEOUT}s 2>/dev/null && \
        print_success "WebGoat ready" || print_warning "WebGoat pending"
    
    print_warning "Kali is installing tools in background (5-10 min)"
}

print_summary() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    Setup Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Pod Status:"
    kubectl get pods -n vulnerable-apps
    kubectl get pods -n attacker
    echo ""
    echo -e "${BLUE}Port Forward Commands:${NC}"
    echo "  kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &"
    echo "  kubectl port-forward -n vulnerable-apps svc/juice-shop-service 3000:3000 &"
    echo "  kubectl port-forward -n vulnerable-apps svc/webgoat-service 8081:8080 &"
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  DVWA:       http://localhost:8080       (admin/password)"
    echo "  Juice Shop: http://localhost:3000"
    echo "  WebGoat:    http://localhost:8081/WebGoat"
    echo ""
    echo -e "${BLUE}Connect to Kali:${NC}"
    echo "  kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash"
    echo ""
    echo -e "${YELLOW}IMPORTANT: DVWA requires clicking 'Create / Reset Database' on first access${NC}"
    echo ""
}

# Main
check_prerequisites
create_namespaces
deploy_dvwa
deploy_juice_shop
deploy_webgoat
deploy_kali
deploy_monitoring
deploy_fluent_bit
wait_for_pods
print_summary
