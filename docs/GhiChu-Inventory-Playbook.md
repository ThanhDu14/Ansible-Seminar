# Phần 1 — Inventory, Module, Playbook, Task

> Một câu tóm tắt: **Inventory** cho biết *làm trên máy nào*, **Module** là *công cụ để làm*,
> **Task** là *một bước cụ thể*, **Playbook** là *kịch bản gồm nhiều bước*.

```
Inventory (máy nào?)  ──►  Playbook  ──►  Play (nhóm máy + danh sách việc)
                                          └── Task 1 ──► gọi Module apt
                                          └── Task 2 ──► gọi Module copy
                                          └── Task 3 ──► gọi Module service
```

Ansible chạy theo mô hình **agentless**: máy điều khiển (control node) SSH vào các máy đích
(managed node), đẩy module (Python) sang, chạy, lấy kết quả JSON về rồi xoá. Máy đích không
cần cài agent, chỉ cần SSH + Python.

---

## 1. Inventory

Inventory là **danh sách các máy** Ansible quản lý, được chia thành **nhóm (group)**.

### 1.1 Định dạng INI — xem [inventory/hosts.ini](inventory/hosts.ini)

```ini
[webservers]                       ; tên nhóm
web1 ansible_host=192.168.56.11    ; alias + biến ngay trên dòng
web2 ansible_host=192.168.56.12

[dbservers]
db1  ansible_host=192.168.56.21

[production:children]              ; nhóm cha chứa các nhóm con
webservers
dbservers
```

### 1.2 Định dạng YAML — xem [inventory/hosts.yml](inventory/hosts.yml)

Cùng nội dung như trên nhưng viết dạng cây. YAML rõ cấu trúc hơn khi inventory lớn.

```yaml
all:
  children:
    webservers:
      hosts:
        web1: { ansible_host: 192.168.56.11 }
        web2: { ansible_host: 192.168.56.12 }
    dbservers:
      hosts:
        db1: { ansible_host: 192.168.56.21 }
```

| | INI | YAML |
|---|---|---|
| Ưu điểm | Ngắn, dễ viết nhanh | Rõ ràng phân cấp, cùng cú pháp với playbook |
| Nhược điểm | Khó đọc khi lồng nhiều nhóm | Dài hơn, phải cẩn thận thụt lề |

### 1.3 Group mặc định

- **`all`**: chứa mọi host.
- **`ungrouped`**: host không thuộc nhóm nào (ngoài `all`).
- Một host có thể thuộc **nhiều nhóm** (vd `web1` vừa trong `webservers` vừa trong `production`).

### 1.4 `group_vars/` và `host_vars/`

Thay vì nhồi biến vào file inventory, ta tách ra thư mục, **đặt cạnh file inventory**
(hoặc cạnh playbook). Tên file = tên nhóm / tên host:

```
inventory/
├── hosts.ini
├── group_vars/
│   ├── all.yml          # biến cho MỌI host
│   └── webservers.yml   # biến cho nhóm webservers
└── host_vars/
    └── web1.yml         # biến riêng cho host web1
```

Quy tắc ưu tiên: **cụ thể hơn thắng** → `host_vars` > `group_vars/<nhóm>` > `group_vars/all`.
Ví dụ trong thư mục này: `http_port` = 80 cho cả nhóm, nhưng riêng `web1` = 8080.

### 1.5 Static vs Dynamic inventory

| | Static | Dynamic |
|---|---|---|
| Là gì | File INI/YAML viết tay | Plugin/script **tự hỏi** nguồn bên ngoài (AWS, Azure, VMware, Docker…) để lấy danh sách máy |
| Khi nào dùng | Ít máy, IP cố định (lab, server nội bộ) | Hạ tầng cloud, máy tạo/xoá liên tục, IP thay đổi |
| Ví dụ | `hosts.ini` | file `aws_ec2.yml` với `plugin: amazon.aws.aws_ec2` |

Ví dụ dynamic (chỉ để minh hoạ, cần tài khoản AWS):

```yaml
# aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions: [ap-southeast-1]
keyed_groups:
  - key: tags.Role        # máy có tag Role=web sẽ tự vào nhóm "role_web"
    prefix: role
```

Lệnh kiểm tra inventory:

```bash
ansible-inventory -i inventory/hosts.ini --graph        # xem cây nhóm
ansible-inventory -i inventory/hosts.ini --host web1    # xem biến cuối cùng của web1
```

---

## 2. Module

**Module** là một đơn vị code (thường là Python) làm **một việc cụ thể** trên máy đích:
cài gói, copy file, tạo user, khởi động service…

| Module | Việc làm |
|---|---|
| `ansible.builtin.ping` | Kiểm tra kết nối (không phải ICMP ping, mà là SSH + Python) |
| `ansible.builtin.apt` / `dnf` / `package` | Cài/gỡ gói |
| `ansible.builtin.copy` | Copy file từ control node sang máy đích |
| `ansible.builtin.template` | Như copy nhưng render biến Jinja2 (`.j2`) |
| `ansible.builtin.service` | Start/stop/enable service |
| `ansible.builtin.user` | Quản lý user |
| `ansible.builtin.command` / `shell` | Chạy lệnh tuỳ ý (dùng khi không có module phù hợp) |

**Tính idempotent** (quan trọng, hay bị hỏi): chạy 1 lần hay 10 lần kết quả như nhau.
Module mô tả *trạng thái mong muốn* (`state: present`) chứ không phải *hành động*
("cài đi"). Nếu nginx đã cài → module báo `ok` và không làm gì; chưa cài → cài và báo `changed`.
`command`/`shell` **không** tự idempotent → hạn chế dùng.

Tra cứu module: `ansible-doc ansible.builtin.apt`

---

## 3. Ad-hoc command vs Playbook

**Ad-hoc** = gọi **một module** ngay trên dòng lệnh, dùng một lần:

```bash
#       nhóm máy     inventory              module   tham số
ansible webservers -i inventory/hosts.ini -m ping
ansible webservers -i inventory/hosts.ini -m apt -a "name=nginx state=present" --become
ansible all        -i inventory/hosts.ini -m command -a "uptime"
```

**Playbook** = file YAML chứa **nhiều task theo thứ tự**, lưu lại được, chạy lại được:

```bash
ansible-playbook -i inventory/hosts.ini playbook-mau.yml
```

| | Ad-hoc | Playbook |
|---|---|---|
| Hình thức | 1 dòng lệnh | File YAML |
| Số việc | 1 module | Nhiều task, có thứ tự |
| Tái sử dụng / lưu Git | Không | Có |
| Biến, điều kiện, vòng lặp, handler | Không | Có |
| Dùng khi | Kiểm tra nhanh, việc lặt vặt (reboot, xem uptime) | Cấu hình hệ thống thật, triển khai ứng dụng |

Ví von: ad-hoc giống gõ 1 lệnh trong terminal, playbook giống viết hẳn một shell script.

---

## 4. Cấu trúc Playbook

Playbook là danh sách các **play**. Mỗi play gồm các khoá chính:

| Khoá | Ý nghĩa |
|---|---|
| `name` | Mô tả play (in ra khi chạy) |
| `hosts` | Chạy trên nhóm/host nào trong inventory (`webservers`, `all`, `web1`, `web*`…) |
| `become` | `true` = chạy với quyền root (sudo). Kèm `become_user` nếu muốn user khác |
| `vars` | Khai báo biến dùng trong play |
| `tasks` | Danh sách task chạy **từ trên xuống** |
| `handlers` | Task chỉ chạy khi được `notify` (vd restart service khi config đổi) |

## 5. Cấu trúc Task

Mỗi task = **name + module + tham số** (+ tuỳ chọn):

```yaml
- name: Cài nginx              # 1. tên — mô tả việc làm
  ansible.builtin.apt:         # 2. module được gọi
    name: nginx                # 3. tham số của module
    state: present
  when: ansible_os_family == "Debian"   # (tuỳ chọn) điều kiện
```

Các từ khoá tuỳ chọn hay gặp: `when` (điều kiện), `loop` (lặp), `register` (lưu kết quả),
`notify` (gọi handler), `become` (sudo cho riêng task), `tags`.

👉 Xem playbook mẫu chú thích từng dòng: [playbook-mau.yml](playbook-mau.yml)

Chạy thử:

```bash
ansible-playbook -i inventory/hosts.ini playbook-mau.yml --check   # chạy thử, không thay đổi gì
ansible-playbook -i inventory/hosts.ini playbook-mau.yml           # chạy thật
```

Kết quả mỗi task: `ok` (đã đúng sẵn), `changed` (vừa thay đổi), `failed`, `skipping` (`when` sai).
Chạy lần 2 → toàn `ok` → đó chính là idempotent.

---

## Câu hỏi có thể bị hỏi khi thuyết trình

1. **Ansible khác shell script thế nào?** → Idempotent, khai báo trạng thái, chạy song song nhiều máy, không cần agent.
2. **Control node chạy được trên Windows không?** → Không trực tiếp; dùng WSL hoặc máy ảo Linux. Máy đích Windows thì được (qua WinRM).
3. **`copy` khác `template`?** → `template` render biến Jinja2 trước khi copy.
4. **`command` khác `shell`?** → `shell` chạy qua `/bin/sh` nên dùng được pipe `|`, `>`, biến môi trường; `command` thì không (an toàn hơn).
5. **Biến trùng tên ở group_vars và host_vars thì lấy cái nào?** → host_vars (cụ thể hơn thắng).
