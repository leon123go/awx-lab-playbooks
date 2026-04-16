# AWX Lab Playbooks

## 專案目的

這個 repository 提供簡單的 Ansible playbook，用來驗證 AWX 或 Ansible 是否能正確對 Linux 目標主機執行任務。

- `ping.yml`：驗證 Ansible 是否能連線到目標主機。
- `deploy_test.yml`：建立 `/opt/myapp/version.txt`，執行最小化部署測試。
- `check_account_permissions.yml`：檢查執行帳號、群組、sudo 能力，以及指定路徑權限，不會修改目標主機。

這些 playbook 適合用於 lab 驗證、AWX Job Template 測試，以及基本的 Ansible 目標主機就緒檢查。

## 執行 ping.yml

建立 inventory 檔案：

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

執行 playbook：

```bash
ansible-playbook -i inventory.ini ping.yml
```

預期結果：

```text
ok: [localhost]
```

`ping.yml` playbook 使用 Ansible ping module，會檢查 Ansible 是否能連線到目標主機，並成功執行 module。

## 執行 deploy_test.yml

建立 inventory 檔案：

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

使用權限提升執行 playbook：

```bash
sudo ansible-playbook -i inventory.ini deploy_test.yml
```

如果是遠端 Linux 目標主機，使用：

```bash
ansible-playbook -i inventory.ini deploy_test.yml --become
```

驗證部署結果：

```bash
test -d /opt/myapp
test -f /opt/myapp/version.txt
cat /opt/myapp/version.txt
```

預期輸出：

```text
deployed by AWX
```

## 執行 check_account_permissions.yml

建立 inventory 檔案：

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

執行 playbook：

```bash
ansible-playbook -i inventory.ini check_account_permissions.yml
```

這個 playbook 會回報：

- 目前執行使用者
- 帳號身分資訊
- 帳號所屬群組
- 免密碼 sudo 狀態
- `/tmp` 和 `/opt` metadata
- 目前使用者對 `/tmp` 和 `/opt` 的寫入權限

這個 playbook 是唯讀檢查，不會建立、更新或刪除任何檔案。

## 排錯方式

### ansible-playbook: command not found

安裝 Ansible。

Ubuntu 或 Debian：

```bash
sudo apt-get update
sudo apt-get install -y ansible python3
```

RHEL、Rocky Linux 或 AlmaLinux：

```bash
sudo dnf install -y ansible-core python3
```

### 缺少 sudo 密碼

使用 become password prompt 執行：

```bash
ansible-playbook -i inventory.ini deploy_test.yml --become --ask-become-pass
```

### 建立 /opt/myapp 時出現 Permission denied

`deploy_test.yml` playbook 會寫入 `/opt/myapp`，因此目標使用者需要 sudo 權限。

檢查 sudo 存取權：

```bash
ansible all -i inventory.ini -m command -a 'whoami' --become
```

### 找不到 Python interpreter

在 inventory 中指定 Python interpreter：

```ini
[target]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

### Inventory does not match any hosts

檢查 inventory 語法：

```bash
ansible-inventory -i inventory.ini --list
```

如果要快速在本機測試且不建立 inventory 檔案：

```bash
ansible-playbook --inventory 'localhost,' --connection local ping.yml
```

### 語法檢查

執行前先做 syntax check：

```bash
ansible-playbook -i inventory.ini ping.yml --syntax-check
ansible-playbook -i inventory.ini deploy_test.yml --syntax-check
ansible-playbook -i inventory.ini check_account_permissions.yml --syntax-check
```

需要更多排錯資訊時：

```bash
ansible-playbook -i inventory.ini ping.yml --syntax-check -vvv
ansible-playbook -i inventory.ini deploy_test.yml --syntax-check -vvv
ansible-playbook -i inventory.ini check_account_permissions.yml --syntax-check -vvv
```
