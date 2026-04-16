# AWX Lab Playbooks

## Project Purpose

This repository contains simple Ansible playbooks for validating AWX or Ansible execution against Linux targets.

- `ping.yml`: verifies Ansible connectivity to target hosts.
- `deploy_test.yml`: performs a minimal deployment test by creating `/opt/myapp/version.txt`.
- `check_account_permissions.yml`: checks the execution account, groups, sudo capability, and selected path permissions without changing the target.

These playbooks are intended for lab validation, AWX job template testing, and basic Ansible target readiness checks.

## Run ping.yml

Create an inventory file:

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

Run the playbook:

```bash
ansible-playbook -i inventory.ini ping.yml
```

Expected result:

```text
ok: [localhost]
```

The `ping.yml` playbook uses the Ansible ping module. It checks whether Ansible can connect to the target and run modules successfully.

## Run deploy_test.yml

Create an inventory file:

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

Run the playbook with privilege escalation:

```bash
sudo ansible-playbook -i inventory.ini deploy_test.yml
```

For remote Linux targets, use:

```bash
ansible-playbook -i inventory.ini deploy_test.yml --become
```

Verify the deployment:

```bash
test -d /opt/myapp
test -f /opt/myapp/version.txt
cat /opt/myapp/version.txt
```

Expected output:

```text
deployed by AWX
```

## Run check_account_permissions.yml

Create an inventory file:

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

Run the playbook:

```bash
ansible-playbook -i inventory.ini check_account_permissions.yml
```

The playbook reports:

- Current execution user
- Account identity
- Account groups
- Passwordless sudo status
- `/tmp` and `/opt` metadata
- `/tmp` and `/opt` write permission for the current user

This playbook is read-only and does not create, update, or delete files.

## Troubleshooting

### ansible-playbook: command not found

Install Ansible.

Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get install -y ansible python3
```

RHEL, Rocky Linux, or AlmaLinux:

```bash
sudo dnf install -y ansible-core python3
```

### Missing sudo password

Run with become password prompt:

```bash
ansible-playbook -i inventory.ini deploy_test.yml --become --ask-become-pass
```

### Permission denied while creating /opt/myapp

The `deploy_test.yml` playbook writes to `/opt/myapp`, so the target user needs sudo privileges.

Check sudo access:

```bash
ansible all -i inventory.ini -m command -a 'whoami' --become
```

### Python interpreter not found

Set the Python interpreter in the inventory:

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

### Inventory does not match any hosts

Check inventory syntax:

```bash
ansible-inventory -i inventory.ini --list
```

For quick local testing without an inventory file:

```bash
ansible-playbook --inventory 'localhost,' --connection local ping.yml
```

### Syntax check

Run syntax checks before execution:

```bash
ansible-playbook -i inventory.ini ping.yml --syntax-check
ansible-playbook -i inventory.ini deploy_test.yml --syntax-check
ansible-playbook -i inventory.ini check_account_permissions.yml --syntax-check
```

For more details:

```bash
ansible-playbook -i inventory.ini ping.yml --syntax-check -vvv
ansible-playbook -i inventory.ini deploy_test.yml --syntax-check -vvv
ansible-playbook -i inventory.ini check_account_permissions.yml --syntax-check -vvv
```
