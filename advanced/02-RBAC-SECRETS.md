# Advanced Module 2: RBAC and Secrets Management

**Difficulty:** ⭐⭐⭐ Advanced  
**Time Required:** 3 hours  
**Prerequisites:** Completed Network Security module

---

## Learning Objectives

- Configure RBAC for least-privilege access
- Secure Kubernetes secrets
- Audit permissions and access
- Implement secrets management best practices

---

## Part 1: RBAC (Role-Based Access Control)

### RBAC Components

| Component | Scope | Purpose |
|-----------|-------|---------|
| Role | Namespace | Define permissions in a namespace |
| ClusterRole | Cluster | Define permissions cluster-wide |
| RoleBinding | Namespace | Grant Role to users/service accounts |
| ClusterRoleBinding | Cluster | Grant ClusterRole cluster-wide |

---

## Exercise 2.1: Create Limited Service Account

### Security Auditor Role

```bash
kubectl apply -f - <<'EOF'
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
  resources: ["pods", "pods/log", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: security-auditor-binding
  namespace: vulnerable-apps
subjects:
- kind: ServiceAccount
  name: security-auditor
  namespace: vulnerable-apps
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Test Permissions

```bash
# What can this service account do?
kubectl auth can-i list pods -n vulnerable-apps \
  --as=system:serviceaccount:vulnerable-apps:security-auditor
# yes

kubectl auth can-i delete pods -n vulnerable-apps \
  --as=system:serviceaccount:vulnerable-apps:security-auditor
# no

kubectl auth can-i list secrets -n vulnerable-apps \
  --as=system:serviceaccount:vulnerable-apps:security-auditor
# no

# List all permissions
kubectl auth can-i --list \
  --as=system:serviceaccount:vulnerable-apps:security-auditor \
  -n vulnerable-apps
```

---

## Exercise 2.2: Dangerous RBAC Patterns

### Overly Permissive Role (DON'T DO THIS)

```yaml
# DANGEROUS - grants all permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dangerous-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

### Find Dangerous Roles

```bash
# Find roles with wildcard permissions
kubectl get clusterroles -o json | jq -r '
  .items[] | 
  select(.rules[]?.verbs[]? == "*" or .rules[]?.resources[]? == "*") | 
  .metadata.name'

# Find who has cluster-admin
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | 
  select(.roleRef.name == "cluster-admin") | 
  "\(.metadata.name): \(.subjects)"'
```

### Dangerous Permissions to Audit

| Permission | Risk |
|------------|------|
| `secrets: get, list` | Can read all secrets |
| `pods/exec: create` | Can exec into any pod |
| `*: *` | Full admin access |
| `pods: create` + `serviceaccounts: create` | Can escalate privileges |

---

## Exercise 2.3: Developer Role

### Create Limited Developer Access

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer
  namespace: vulnerable-apps
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: vulnerable-apps
rules:
# Can view most resources
- apiGroups: ["", "apps"]
  resources: ["pods", "pods/log", "services", "deployments", "configmaps"]
  verbs: ["get", "list", "watch"]
# Can exec into pods (for debugging)
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
# Can update deployments (for releases)
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["update", "patch"]
# CANNOT access secrets
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: vulnerable-apps
subjects:
- kind: ServiceAccount
  name: developer
  namespace: vulnerable-apps
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

---

## Part 2: Secrets Management

## Exercise 2.4: Understanding Secrets Risks

### Secrets Are Base64, Not Encrypted

```bash
# Create a secret
kubectl create secret generic db-creds \
  -n vulnerable-apps \
  --from-literal=username=admin \
  --from-literal=password=supersecret123

# View the secret - it's just base64!
kubectl get secret db-creds -n vulnerable-apps -o yaml

# Decode it easily
kubectl get secret db-creds -n vulnerable-apps \
  -o jsonpath='{.data.password}' | base64 -d
```

### Anyone with Secret Access Can Read Them

```bash
# If a service account has secrets access...
kubectl auth can-i get secrets -n vulnerable-apps \
  --as=system:serviceaccount:vulnerable-apps:default
```

---

## Exercise 2.5: Secure Secret Usage

### Mount Secrets as Files (Preferred)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secret-file-pod
  namespace: vulnerable-apps
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-creds
      defaultMode: 0400  # Read-only for owner
EOF

# Verify
kubectl exec -n vulnerable-apps secret-file-pod -- ls -la /etc/secrets/
kubectl exec -n vulnerable-apps secret-file-pod -- cat /etc/secrets/password
```

### Use Environment Variables (Less Secure)

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-creds
      key: password
```

**Warning:** Env vars can leak in logs, crash dumps, and child processes!

---

## Exercise 2.6: Restrict Secret Access

### Create Secret-Reader Role

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: vulnerable-apps
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-creds"]  # Only specific secrets!
  verbs: ["get"]
EOF
```

### Disable Service Account Token Mounting

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx
```

---

## Exercise 2.7: Audit RBAC and Secrets

### Audit Script

```bash
#!/bin/bash
# rbac-audit.sh

echo "=== RBAC Audit Report ==="
echo ""

echo "1. Service Accounts with Secret Access:"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  for sa in $(kubectl get sa -n $ns -o jsonpath='{.items[*].metadata.name}'); do
    if kubectl auth can-i get secrets -n $ns --as=system:serviceaccount:$ns:$sa 2>/dev/null | grep -q "yes"; then
      echo "   - $ns/$sa"
    fi
  done
done

echo ""
echo "2. ClusterRoleBindings to cluster-admin:"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") | 
  "   - \(.metadata.name)"'

echo ""
echo "3. Roles with Wildcard Permissions:"
kubectl get roles,clusterroles --all-namespaces -o json | jq -r '
  .items[] | select(.rules[]?.verbs[]? == "*") | 
  "   - \(.metadata.namespace // "cluster")/\(.metadata.name)"'

echo ""
echo "4. Secrets Count by Namespace:"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  count=$(kubectl get secrets -n $ns --no-headers 2>/dev/null | wc -l)
  echo "   - $ns: $count"
done
```

---

## Knowledge Check

1. What's the principle of least privilege?
2. Why are ClusterRoles more dangerous than Roles?
3. How are Kubernetes secrets stored by default?
4. Why should you avoid wildcard permissions?

<details>
<summary>✅ Answers</summary>

1. Grant only the minimum permissions needed
2. ClusterRoles apply across all namespaces
3. Base64 encoded in etcd (not encrypted by default)
4. They grant access to all current AND future resources

</details>

---

## Best Practices

### RBAC

- Use Roles over ClusterRoles when possible
- Avoid wildcards (`*`) in permissions
- Audit permissions regularly
- Use service accounts per application
- Disable token auto-mounting

### Secrets

- Enable encryption at rest
- Use external secret managers (Vault)
- Rotate secrets regularly
- Limit secret access via RBAC
- Don't log secrets

---

## Summary

- ✅ RBAC roles and bindings
- ✅ Least privilege implementation
- ✅ Secret storage and access
- ✅ Security auditing
- ✅ Best practices

### Next Steps

Continue to: **Advanced Module 3: Container Security**
