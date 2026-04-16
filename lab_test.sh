#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="${LOG_FILE:-./lab_test.log}"
ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-quay.io/ansible/awx-ee:24.6.1}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  local level="$1"
  shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR" "$*"
  exit 1
}

run_ansible_playbook() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    ansible-playbook "$@"
    return
  fi

  if command -v docker >/dev/null 2>&1; then
    docker run --rm \
      -v "${REPO_DIR}:/work" \
      -w /work \
      "${ANSIBLE_IMAGE}" \
      ansible-playbook "$@"
    return
  fi

  fail "ansible-playbook not found and docker is not available"
}

show_usage() {
  cat <<'EOF'

Safe lab execution examples
===========================

1. Create a lab-only inventory file:

cat > inventory.lab.ini <<'INVENTORY'
[lab]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
INVENTORY

2. Test Ansible connectivity against lab hosts:

ansible-playbook -i inventory.lab.ini ping.yml --limit lab

3. Dry-run the deployment playbook against lab hosts only:

ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become --check --diff

4. Run the deployment playbook only after confirming the inventory contains lab hosts:

ansible-playbook -i inventory.lab.ini deploy_test.yml --limit lab --become

Safety rules:

- Do not use production inventory files with this lab flow.
- Always use --limit lab.
- Run --check --diff before any real lab deployment.
- This script does not deploy anything automatically.

EOF
}

trap 'fail "Command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

cd "$REPO_DIR"

log "INFO" "Starting safe lab test flow"
log "INFO" "Repository: ${REPO_DIR}"

[[ -f "ping.yml" ]] || fail "Missing ping.yml"
[[ -f "deploy_test.yml" ]] || fail "Missing deploy_test.yml"
[[ -f "check_account_permissions.yml" ]] || fail "Missing check_account_permissions.yml"

log "INFO" "Pulling latest changes with fast-forward only"
git pull --ff-only

log "INFO" "Running syntax check for ping.yml"
run_ansible_playbook --inventory 'localhost,' --connection local ping.yml --syntax-check

log "INFO" "Running syntax check for deploy_test.yml"
run_ansible_playbook --inventory 'localhost,' --connection local deploy_test.yml --syntax-check

log "INFO" "Running syntax check for check_account_permissions.yml"
run_ansible_playbook --inventory 'localhost,' --connection local check_account_permissions.yml --syntax-check

log "INFO" "Syntax checks completed successfully"
show_usage
