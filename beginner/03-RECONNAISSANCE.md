# Beginner Module 3: Reconnaissance

**Difficulty:** ⭐ Beginner  
**Time Required:** 2 hours  
**Prerequisites:** Lab setup complete, Kali pod accessible

---

## Learning Objectives

By the end of this module, you will be able to:

- Understand the importance of reconnaissance in penetration testing
- Use automated scanning tools (nikto, nmap, dirb)
- Identify common web application vulnerabilities
- Gather information about target systems
- Document findings professionally

---

## What is Reconnaissance?

Reconnaissance (recon) is the first phase of penetration testing. It involves gathering information about the target to identify potential attack vectors.

### Types of Reconnaissance

| Type | Description | Example |
|------|-------------|---------|
| **Passive** | No direct interaction with target | WHOIS, DNS lookups, Google dorking |
| **Active** | Direct interaction with target | Port scanning, vulnerability scanning |

---

## Lab Setup

### Connect to Kali

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash
```

### Target Information

| Application | URL |
|-------------|-----|
| DVWA | `http://dvwa-service.vulnerable-apps.svc.cluster.local` |
| Juice Shop | `http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000` |
| WebGoat | `http://webgoat-service.vulnerable-apps.svc.cluster.local:8080` |

---

## Exercise 3.1: Network Reconnaissance with Nmap

### Basic Service Scan

```bash
# Scan DVWA service
nmap -sV dvwa-service.vulnerable-apps.svc.cluster.local
```

### Scan with Default Scripts

```bash
nmap -sV -sC dvwa-service.vulnerable-apps.svc.cluster.local
```

### Scan All Applications

```bash
# Scan Juice Shop
nmap -sV -sC juice-shop-service.vulnerable-apps.svc.cluster.local -p 3000

# Scan WebGoat
nmap -sV -sC webgoat-service.vulnerable-apps.svc.cluster.local -p 8080,9090
```

### Understanding Output

| Application | Ports | Technologies |
|-------------|-------|--------------|
| DVWA | 80 | Apache 2.4.25, PHP, MySQL 5.7 |
| Juice Shop | 3000 | Node.js, Express |
| WebGoat | 8080, 9090 | Java, Spring Boot |

---

## Exercise 3.2: Web Vulnerability Scanning with Nikto

### Basic Nikto Scan

```bash
nikto -h http://dvwa-service.vulnerable-apps.svc.cluster.local
```

### Save Output

```bash
nikto -h http://dvwa-service.vulnerable-apps.svc.cluster.local -o nikto_dvwa.txt
```

### Common Findings

| Finding | Risk | Implication |
|---------|------|-------------|
| Missing X-Frame-Options | Medium | Clickjacking possible |
| Cookie without HttpOnly | Medium | XSS can steal cookies |
| Directory indexing | Medium | Can browse server files |
| phpinfo.php exposed | High | Exposes server configuration |

---

## Exercise 3.3: Directory Bruteforcing

### Using Dirb

```bash
dirb http://dvwa-service.vulnerable-apps.svc.cluster.local /usr/share/dirb/wordlists/common.txt
```

### Using Gobuster (Faster)

```bash
gobuster dir -u http://dvwa-service.vulnerable-apps.svc.cluster.local \
  -w /usr/share/dirb/wordlists/common.txt \
  -x php,txt,html,bak \
  -t 50
```

### Interesting Directories Found

| Path | Description |
|------|-------------|
| `/setup.php` | DVWA setup page |
| `/config/` | Configuration directory |
| `/phpinfo.php` | PHP information |
| `/robots.txt` | May reveal hidden paths |
| `/ftp/` | Juice Shop FTP directory |
| `/api/` | API endpoints |

---

## Exercise 3.4: Web Technology Fingerprinting

### Using WhatWeb

```bash
whatweb http://dvwa-service.vulnerable-apps.svc.cluster.local
whatweb http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000
```

### Manual Fingerprinting

```bash
# Check HTTP Headers
curl -I http://dvwa-service.vulnerable-apps.svc.cluster.local

# Check robots.txt
curl http://dvwa-service.vulnerable-apps.svc.cluster.local/robots.txt

# Check for common files
curl -s http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/package.json
```

---

## Exercise 3.5: Automated Recon Script

```bash
cat > /tmp/recon.sh << 'EOF'
#!/bin/bash
TARGET=$1
OUTPUT_DIR="/tmp/recon_$(date +%Y%m%d_%H%M%S)"

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target_url>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
HOST=$(echo "$TARGET" | sed 's|http[s]*://||' | cut -d'/' -f1 | cut -d':' -f1)

echo "[*] Scanning: $TARGET"

echo "[*] Running Nmap..."
nmap -sV "$HOST" -oN "$OUTPUT_DIR/nmap.txt" 2>/dev/null

echo "[*] Running Nikto..."
nikto -h "$TARGET" -o "$OUTPUT_DIR/nikto.txt" 2>/dev/null

echo "[*] Running Gobuster..."
gobuster dir -u "$TARGET" -w /usr/share/dirb/wordlists/common.txt -o "$OUTPUT_DIR/gobuster.txt" -q 2>/dev/null

echo "[*] Checking common files..."
for file in robots.txt sitemap.xml .git/config package.json; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET/$file")
    [ "$STATUS" = "200" ] && echo "    [+] Found: $TARGET/$file"
done

echo "[*] Results saved to: $OUTPUT_DIR"
EOF
chmod +x /tmp/recon.sh

# Run it
/tmp/recon.sh http://dvwa-service.vulnerable-apps.svc.cluster.local
```

---

## Knowledge Check

1. What's the difference between passive and active reconnaissance?
2. Which tool would you use for port scanning?
3. What does Nikto check for?
4. Why is directory bruteforcing useful?

<details>
<summary>✅ Answers</summary>

1. Passive doesn't touch the target; Active directly interacts
2. Nmap
3. Web server vulnerabilities, misconfigurations, dangerous files
4. Finds hidden files, admin panels, backup files, API endpoints

</details>

---

## Summary

In this module, you learned:

- ✅ Network scanning with Nmap
- ✅ Web vulnerability scanning with Nikto
- ✅ Directory enumeration with Dirb/Gobuster
- ✅ Technology fingerprinting

### Next Steps

You've completed the **Beginner** modules! Continue to:

**Intermediate Module 1: Authentication Attacks**

---

## Quick Reference

### Nmap

```bash
nmap -sV <target>           # Service detection
nmap -sV -sC <target>       # With scripts
nmap -p- <target>           # All ports
nmap -A <target>            # Aggressive
```

### Nikto

```bash
nikto -h <url>              # Basic scan
nikto -h <url> -o out.txt   # Save output
```

### Gobuster

```bash
gobuster dir -u <url> -w <wordlist>           # Basic
gobuster dir -u <url> -w <wordlist> -x php    # With extensions
gobuster dir -u <url> -w <wordlist> -t 50     # More threads
```
