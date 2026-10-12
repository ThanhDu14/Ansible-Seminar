# 🚀 Ansible Configuration Management & Automated Nginx Deployment

![Ansible](https://img.shields.io/badge/Ansible-E00000?style=for-the-badge&logo=ansible&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)
![AWS](https://img.shields.io/badge/AWS_EC2-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

An end-to-end Infrastructure as Code (IaC) project demonstrating automated web server provisioning, Jinja2 templating, security encryption via Ansible Vault, and practical verification of **Ansible Idempotency** across AWS EC2 nodes.

---

## 📚 9. Ansible Configuration Management (Theoretical Foundations)

### 9.1 Concept of Idempotence
**Idempotence** is the foundational core principle of Configuration Management. An operation is defined as idempotent if executing it multiple times yields the exact same system state as executing it once:
$$f(f(x)) = f(x)$$

- **Why it matters:** In traditional script-based automation (e.g., raw bash scripts), executing a deployment script repeatedly can result in configuration drift, duplicate data, or system crashes (e.g., appending the same line multiple times to `/etc/hosts`).
- **In Ansible:** Ansible modules are designed to inspect the current state of the target system first. If the desired state is already satisfied, Ansible skips execution (`changed=0`), ensuring consistency, stability, and safety during re-runs.

---

### 9.2 Agentless Architecture via SSH vs. Agent-Based Tools
Ansible operates on an **Agentless Architecture**, setting it apart from traditional configuration management frameworks:

| Feature | Ansible (Agentless) | Agent-Based (Chef, Puppet, SaltStack) |
| :--- | :--- | :--- |
| **Architecture** | Direct control over standard **SSH** / WinRM | Requires background daemons/agents installed on target nodes |
| **Overhead** | Zero memory/CPU footprint on target nodes | Continuous RAM/CPU consumption by background agents |
| **Security** | Leverages existing SSH security, keys, and firewalls | Requires custom port openings and master-agent PKI setup |
| **Deployment** | Instant setup; only requires Python on target nodes | Complex bootstrapping process to install and register agents |

---

### 9.3 Core Ansible Components
- **Inventory:** A configuration file (`INI` or `YAML`) listing managed node IP addresses, host groups, and connection variables.
- **Playbook:** The entry-point YAML file mapping managed hosts to specific roles and execution policies.
- **Task:** The smallest unit of execution in Ansible, calling a specific module with designated parameters.
- **Role:** A structured directory standard used to modularize tasks, variables, templates, and handlers into reusable units.
- **Handler:** Special conditional tasks triggered by a `notify` signal, executing once at the end of a play only when a task induces a state change (`changed=1`).
- **Template (Jinja2):** Dynamic file templates (`.j2`) embedded with Jinja2 expressions (`{{ variable }}`) to generate node-specific configurations on the fly.

---

### 9.4 Dedicated Modules vs. Raw Shell/Command
Using dedicated Ansible modules (`ansible.builtin.copy`, `ansible.builtin.lineinfile`, `ansible.builtin.service`) is vastly superior to invoking raw `shell` or `command` execution:

1. **Guaranteed Idempotency:** Modules check the target state before modifying files or services. `shell` commands execute blindly every time, returning `changed=1`.
2. **Built-in Error Handling & Sanitization:** Dedicated modules handle permissions, ownership, symlinks, and OS differences automatically.
3. **Declarative Syntax:** Modules define *what* the system state should be (`state: present`, `state: started`) rather than *how* to imperatively execute shell commands.

---

## 🏗️ Nginx Architecture & Configuration Structure

Nginx (*Engine-X*) uses an event-driven, non-blocking master-worker process architecture:

```text
               ┌───────────────────────────┐
               │    Nginx Master Process   │
               │   (Reads Config / Root)   │
               └─────────────┬─────────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ Worker Proc  │      │ Worker Proc  │      │ Worker Proc  │
│ (www-data)   │      │ (www-data)   │      │ (www-data)   │
└──────────────┘      └──────────────┘      └──────────────┘
```

- **Master Process:** Runs under `root` privileges to read configurations, bind to network ports (e.g., 80/443), and manage worker processes.
- **Worker Processes:** Run under non-privileged users (`www-data`) to process incoming client HTTP requests.
- **Sites-Available vs. Sites-Enabled:**
  - `/etc/nginx/sites-available/`: Stores all virtual host configuration files.
  - `/etc/nginx/sites-enabled/`: Contains symbolic links (symlinks) pointing to files in `sites-available` to actively enable web domains.

---

## 📁 Repository & Ansible Role Architecture

This repository follows Ansible's official role directory structure:

```text
ansible_lab/
├── inventory                    # Managed node IP definitions and connection parameters
├── site.yml                     # Root Playbook binding target hosts to the Nginx role
├── README.md                    # Detailed documentation and architectural breakdown
└── roles/
    └── nginx/                   # Modular Nginx Role
        ├── defaults/
        │   └── main.yml         # Default variables (http_port: 80, server_name)
        ├── handlers/
        │   └── main.yml         # Conditional handler to restart Nginx on change
        ├── tasks/
        │   └── main.yml         # Sequential workflow (Install, Template, Service, Idempotency)
        ├── templates/
        │   └── nginx.conf.j2    # Dynamic Jinja2 configuration template
        └── vars/
            └── vault.yml        # AES-256 encrypted secrets via Ansible Vault
```

---

## 🧪 Practical Required Demos

### Demo 1: Basic Role & Service Provisioning
- Configured SSH Key-based authentication across control and managed nodes.
- Automated `nginx` installation and service persistence using structured roles.

### Demo 2: Jinja2 Templates & Smart Handlers
- Created dynamic virtual host configurations using `nginx.conf.j2`.
- Attached `notify: Restart Nginx` handler to execute service restarts *only* when the configuration template changes.

### Demo 3: Security & Ansible Vault Encryption
- Encrypted sensitive variables (e.g., API keys, database credentials) inside `roles/nginx/vars/vault.yml` using `ansible-vault create`.
- Executed playbooks safely with runtime password decryption via `--ask-vault-pass`.

### Demo 4: Idempotency & Fault Demonstration
- **Non-Idempotent Fault Demo:** Executed `ansible.builtin.shell: echo "data" >> /file.txt` 3 times, causing duplicate entries and permanent `changed=1` state drift.
- **Idempotent Solution:** Replaced with `ansible.builtin.lineinfile`, ensuring exact single-line matching and returning `changed=0` on repeated runs.

---

## 🚀 Execution & Verification

### Run Playbook
```bash
ansible-playbook -i inventory site.yml --ask-vault-pass
```

### Idempotency Re-run Verification
```bash
ansible-playbook -i inventory site.yml --ask-vault-pass
```
*Expected Output:* `changed=0` (confirming target system remains in desired state without unnecessary modifications).

---

## 🛡️ License & Author

Distributed under the MIT License.

- **Author:** Nguyen Thanh Du
- **MSSV:** 24120288
- **Course:** Linux OS & Application
