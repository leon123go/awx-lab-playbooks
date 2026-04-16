# Testing Guide

## Architecture

This repository is an Ansible lab repository for validating AWX and Ansible execution safely.

Test scope:

- `ping.yml`: validates Ansible connectivity.
- `deploy_test.yml`: validates a minimal deployment to `/opt/myapp/version.txt`.
- `check_account_permissions.yml`: validates execution account permissions without changing target files.
- `lab_test.sh`: runs a safe local lab flow with `git pull --ff-only`, syntax checks, and usage output.

Safety rules:

- Use lab inventory only.
- Always apply `--limit lab`.
- Run `--check --diff` before any deployment test.
- Do not run deployment playbooks against production inventory.
- Review account permission results before running any playbook that requires `become`.

## Step-by-step

### 1. Install dependencies on Linux

Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get install -y git ansible python3
```

RHEL, Rocky Linux, or AlmaLinux:

```bash
sudo dnf install -y git ansible-core python3
```

Optional Docker-based execution:

```bash
docker pull quay.io/ansible/awx-ee:24.6.1
```

### 2. Clone or update the repository

```bash
git clone https://github.com/leon123go/awx-lab-playbooks.git
cd awx-lab-playbooks
git pull --ff-only
```

### 3. Create a lab inventory

```bash
cat > inventory.lab.ini <<'EOF'
[lab]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
EOF
```

### 4. Run syntax checks

```bash
ansible-playbook -i inventory.lab.ini ping.yml --syntax-check
ansible-playbook -i inventory.lab.ini deploy_test.yml --syntax-check
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --syntax-check
```

### 5. Run safe lab tests

Connectivity test:

```bash
ansible-playbook -i inventory.lab.ini ping.yml --limit lab
```

Account permission test:

```bash
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --limit lab
```

Deployment dry-run:

```bash
ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become --check --diff
```

Deployment lab run after dry-run review:

```bash
ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become
```

Verify lab deployment:

```bash
test -d /opt/myapp
test -f /opt/myapp/version.txt
cat /opt/myapp/version.txt
```

Expected output:

```text
deployed by AWX
```

### 6. Run the safe test script

```bash
chmod +x lab_test.sh
./lab_test.sh
```

The script does not deploy. It only pulls the latest code, runs syntax checks, and prints safe execution examples.

## Code

Use this complete Linux test runner when you want one command to validate the repository safely.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="${LOG_FILE:-./testing_guide_run.log}"

log() {
  local level="$1"
  shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR" "$*"
  exit 1
}

trap 'fail "Command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

log "INFO" "Starting safe Ansible lab tests"

command -v git >/dev/null 2>&1 || fail "git not found"
command -v ansible-playbook >/dev/null 2>&1 || fail "ansible-playbook not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

[[ -f ping.yml ]] || fail "Missing ping.yml"
[[ -f deploy_test.yml ]] || fail "Missing deploy_test.yml"
[[ -f check_account_permissions.yml ]] || fail "Missing check_account_permissions.yml"

git pull --ff-only

cat > inventory.lab.ini <<'INVENTORY'
[lab]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
INVENTORY

log "INFO" "Running syntax checks"
ansible-playbook -i inventory.lab.ini ping.yml --syntax-check
ansible-playbook -i inventory.lab.ini deploy_test.yml --syntax-check
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --syntax-check

log "INFO" "Running connectivity check"
ansible-playbook -i inventory.lab.ini ping.yml --limit lab

log "INFO" "Running account permission check"
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --limit lab

log "INFO" "Running deployment dry-run only"
ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become --check --diff

log "INFO" "Safe lab tests completed"
log "INFO" "Real deployment was not executed by this runner"
```

## Deploy

### Docker-based test execution

Run syntax checks without installing Ansible on the host:

```bash
docker run --rm -v "$PWD:/work" -w /work quay.io/ansible/awx-ee:24.6.1 ansible-playbook --inventory 'localhost,' --connection local ping.yml --syntax-check
docker run --rm -v "$PWD:/work" -w /work quay.io/ansible/awx-ee:24.6.1 ansible-playbook --inventory 'localhost,' --connection local deploy_test.yml --syntax-check
docker run --rm -v "$PWD:/work" -w /work quay.io/ansible/awx-ee:24.6.1 ansible-playbook --inventory 'localhost,' --connection local check_account_permissions.yml --syntax-check
```

Run the account permission check in the container:

```bash
docker run --rm -v "$PWD:/work" -w /work quay.io/ansible/awx-ee:24.6.1 ansible-playbook --inventory 'localhost,' --connection local check_account_permissions.yml
```

### GitHub Actions CI

```yaml
name: ansible-test

on:
  push:
  pull_request:

jobs:
  syntax-check:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Ansible
        run: |
          sudo apt-get update
          sudo apt-get install -y ansible python3

      - name: Create lab inventory
        run: |
          cat > inventory.lab.ini <<'EOF'
          [lab]
          localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
          EOF

      - name: Syntax check
        run: |
          ansible-playbook -i inventory.lab.ini ping.yml --syntax-check
          ansible-playbook -i inventory.lab.ini deploy_test.yml --syntax-check
          ansible-playbook -i inventory.lab.ini check_account_permissions.yml --syntax-check

      - name: Runtime checks
        run: |
          ansible-playbook -i inventory.lab.ini ping.yml --limit lab
          ansible-playbook -i inventory.lab.ini check_account_permissions.yml --limit lab
          ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become --check --diff
```

Terraform and Kubernetes are not required for this repository because the current scope is Ansible playbook validation.

## Debug

Check Ansible version:

```bash
ansible-playbook --version
```

Check inventory parsing:

```bash
ansible-inventory -i inventory.lab.ini --list
```

Run verbose syntax checks:

```bash
ansible-playbook -i inventory.lab.ini ping.yml --syntax-check -vvv
ansible-playbook -i inventory.lab.ini deploy_test.yml --syntax-check -vvv
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --syntax-check -vvv
```

Run verbose lab tests:

```bash
ansible-playbook -i inventory.lab.ini ping.yml --limit lab -vvv
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --limit lab -vvv
ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become --check --diff -vvv
```

Common errors:

- `ansible-playbook: command not found`: install Ansible or use the Docker commands.
- `Inventory does not match any hosts`: confirm `inventory.lab.ini` contains the `[lab]` group and use `--limit lab`.
- `Missing sudo password`: add `--ask-become-pass` for lab hosts that require a sudo password.
- `Permission denied`: run `check_account_permissions.yml` to verify the target account before deployment tests.
- `/opt/myapp` is not created during dry-run: this is expected when using `--check`.

Health checks:

```bash
ansible-playbook -i inventory.lab.ini ping.yml --limit lab
ansible-playbook -i inventory.lab.ini check_account_permissions.yml --limit lab
test -f /opt/myapp/version.txt && cat /opt/myapp/version.txt
```
