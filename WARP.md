# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

This repository is a Kubernetes security training lab, not an application codebase. It provisions a full cluster environment with intentionally vulnerable web apps, an attacker workstation, and a monitoring stack. Most of the logic lives in Bash scripts that generate and apply Kubernetes manifests; the Markdown files describe the training path and hands-on exercises.

## Repository structure (high level)

- `README.md`: Primary entry point; quick-start, architecture diagram, and Kibana usage.
- `K8S-SECURITY-LAB-GUIDE.md`: Long-form 8‑week training guide with inline Kubernetes manifests, attack walkthroughs, and reference scripts.
- `setup/01-SETUP-GUIDE.md`: Detailed cluster prerequisites, setup steps, and manual deployment instructions.
- `beginner/`, `intermediate/`, `advanced/`: Week-by-week exercise content (SQLi/XSS, auth/CSRF/IDOR, Kubernetes/RBAC/network policies, container & supply-chain security).
- `scripts/`: Operational scripts that actually create, expose, reset, and tear down the lab.
- `fluent-bit.yaml`: Standalone Fluent Bit DaemonSet + ConfigMap + RBAC for shipping pod logs to Elasticsearch.

There is no application build system or test harness in this repo; interaction is through `kubectl` and the shell scripts.

## Common commands and workflows

All commands assume you are at the repo root: `k8s-sec-lab/`.

### Lab lifecycle

- **Deploy the full lab**
  ```bash
  chmod +x scripts/*.sh
  ./scripts/setup.sh
  ```
  - Checks `kubectl` connectivity.
  - Creates four namespaces: `vulnerable-apps`, `attacker`, `monitoring`, `secure-zone` (with restricted Pod Security labels).
  - Deploys:
    - DVWA (+ MariaDB sidecar) in `vulnerable-apps`.
    - OWASP Juice Shop and WebGoat in `vulnerable-apps`.
    - Kali attacker deployment in `attacker` (installs common tools on first start).
    - Elasticsearch + Kibana in `monitoring`.
    - Fluent Bit DaemonSet in `monitoring` to ship logs to Elasticsearch.

- **Start port forwarding for all UIs** (runs in foreground, spawns background port‑forward processes):
  ```bash
  ./scripts/port-forward.sh
  ```
  This maps to:
  - DVWA: `http://localhost:8080`
  - Juice Shop: `http://localhost:3000`
  - WebGoat: `http://localhost:8081/WebGoat`
  - Kibana: `http://localhost:5601`

- **Reset applications** (rollout restart deployments and wait for readiness):
  ```bash
  # Reset everything (default)
  ./scripts/reset.sh
  ./scripts/reset.sh all

  # Reset a single component
  ./scripts/reset.sh dvwa
  ./scripts/reset.sh juice      # or: juice-shop, juiceshop
  ./scripts/reset.sh webgoat
  ./scripts/reset.sh kali
  ```

- **Tear down the lab completely** (namespaces + cluster-scoped RBAC/policies):
  ```bash
  # Interactive confirmation
  ./scripts/teardown.sh

  # Non-interactive (CI or scripted usage)
  ./scripts/teardown.sh -y
  ```
  This stops port‑forwards, deletes resources in the four lab namespaces, deletes the namespaces themselves, and removes cluster-wide RBAC created for the lab (including Fluent Bit roles and sample "dangerous" roles used in exercises).

### Kubernetes inspection and interaction

These are commonly referenced throughout the docs and scripts.

- **Check pod readiness and status**
  ```bash
  kubectl get pods -n vulnerable-apps
  kubectl get pods -n attacker
  kubectl get pods -n monitoring
  ```

- **Watch vulnerable app pods during startup** (useful right after `setup.sh`):
  ```bash
  kubectl get pods -n vulnerable-apps -w
  ```

- **Connect to Kali attacker pod**
  ```bash
  kubectl exec -it -n attacker deploy/kali-attacker -- /bin/bash
  ```

- **Troubleshoot DVWA**
  ```bash
  # Check DVWA pod and MySQL sidecar
  kubectl get pods -n vulnerable-apps -l app=dvwa
  kubectl logs -n vulnerable-apps -l app=dvwa -c dvwa
  kubectl logs -n vulnerable-apps -l app=dvwa -c mysql
  ```

- **Troubleshoot logging / Elasticsearch**
  ```bash
  # Fluent Bit and Elasticsearch health
  kubectl get pods -n monitoring -l app=fluent-bit
  kubectl logs -n monitoring -l app=fluent-bit

  kubectl port-forward -n monitoring svc/elasticsearch 9200:9200 &
  curl http://localhost:9200/_cat/indices?v
  ```

- **Apply or tweak Fluent Bit stack separately** (if you are iterating only on logging):
  ```bash
  kubectl apply -f fluent-bit.yaml
  ```

There is no test harness or linter defined in this repo; validation is done by checking Kubernetes object health (`kubectl get/describe/logs`) and by running the exercises in the guides.

## Architecture and design

### Namespace and component layout

The lab models a realistic multi-zone cluster:

- **`vulnerable-apps` namespace**
  - DVWA deployment with a MariaDB sidecar (configured via the `dvwa-config` ConfigMap in `scripts/setup.sh`).
  - OWASP Juice Shop deployment and service.
  - WebGoat deployment and service exposing both WebGoat and WebWolf ports.
  - All are labeled `purpose: security-training` and targeted by Fluent Bit log collection.

- **`attacker` namespace**
  - `kali-attacker` deployment runs a Kali-based container that installs tooling (`sqlmap`, `nikto`, `nmap`, `hydra`, `gobuster`, etc.) on startup, signalling readiness by writing `READY` to `/tmp/ready`.
  - Used as the primary vantage point for automated attacks against the in-cluster services.

- **`monitoring` namespace**
  - Elasticsearch single-node deployment and service on port 9200 (security disabled for simplicity).
  - Kibana deployment and service on port 5601, configured to point at the in-cluster Elasticsearch service.
  - Fluent Bit DaemonSet that tails container logs on each node and forwards them to Elasticsearch with index prefix `k8s-logs`.

- **`secure-zone` namespace**
  - Hardened namespace used in later exercises to contrast secure vs. vulnerable configurations.
  - Labeled with `pod-security.kubernetes.io/enforce/warn=restricted` by `scripts/setup.sh` to enforce Kubernetes Pod Security Standards at the `restricted` level.

The ASCII architecture diagrams in `README.md` and `K8S-SECURITY-LAB-GUIDE.md` are authoritative for how these pieces relate; changes to topology should be reflected there as well as in the scripts.

### Script-driven deployment model

Instead of storing manifests as separate files, most Kubernetes resources are defined inline inside `scripts/setup.sh` as here‑documents passed to `kubectl apply -f -`. Key functions in that script:

- `create_namespaces()`: defines all four namespaces and their labels.
- `deploy_dvwa()`: creates `dvwa-config` ConfigMap, DVWA + MariaDB deployment, and `dvwa-service` service.
- `deploy_juice_shop()`: deployment and service for Juice Shop.
- `deploy_webgoat()`: deployment and multi-port service for WebGoat/WebWolf.
- `deploy_kali()`: attacker deployment with tool installation and readiness probe.
- `deploy_monitoring()`: deployments and services for Elasticsearch and Kibana.
- `deploy_fluent_bit()`: ServiceAccount, ClusterRole/Binding, Fluent Bit ConfigMap, and DaemonSet.
- `wait_for_pods()` and `print_summary()`: orchestrate readiness waits and print consolidated status and port-forward hints.

When modifying or extending the environment, prefer editing these functions so that `setup.sh` remains the single source of truth for the lab topology. For example:

- To add a new vulnerable app, mirror the pattern in `deploy_juice_shop()` or `deploy_webgoat()` (deployment + service, labels, probes), and add corresponding port-forwarding lines to `scripts/port-forward.sh`.
- To change DVWA database credentials or security-level defaults, update the `dvwa-config` ConfigMap block in `deploy_dvwa()` and keep the documentation in `README.md` / `setup/01-SETUP-GUIDE.md` consistent.
- To adjust logging behavior, either modify the Fluent Bit sections in `deploy_fluent_bit()` or edit `fluent-bit.yaml` if you prefer a manifest‑driven workflow.

### Documentation-driven exercises

The Markdown files are structured as a progressive curriculum and often contain inline code and manifests that mirror or extend what `scripts/setup.sh` deploys:

- `K8S-SECURITY-LAB-GUIDE.md` includes full example manifests (Deployments, Services, NetworkPolicies, RBAC, Secrets, PodSecurity configurations, Falco rules, Kyverno policies, etc.) used in later stages of the course.
- `beginner/*`, `intermediate/*`, and `advanced/*` reference the running lab services (e.g., `dvwa-service.vulnerable-apps.svc.cluster.local`, `juice-shop-service`, `webgoat-service`) and demonstrate both attack and defense techniques.

When updating the lab behavior (e.g., changing service names, ports, or namespace labels), search across these guides and update the referenced hostnames, ports, or YAML snippets to keep the exercises accurate.

## How future agents should approach changes

- Use `scripts/setup.sh` and `scripts/reset.sh` as the main entry points for changing how the environment is created, exposed, or reset. Treat them as the “orchestration layer” for all lab components.
- Use `fluent-bit.yaml` when you want to iterate on logging configuration without touching the rest of the lab lifecycle.
- Use the Markdown guides as specifications: if you modify lab behavior, cross‑check and update affected examples, commands, and diagrams so that learners following the docs still get the expected results.
