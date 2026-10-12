# Phần 2 — Role

> **Role** = cách đóng gói playbook thành **một thư mục có cấu trúc chuẩn**, để tái sử dụng.
> Nếu playbook giống một file code dài, thì role giống một **thư viện/package**.

## 1. Vì sao cần Role?

Playbook ở Phần 1 viết hết vào 1 file. Khi dự án lớn (web + db + monitoring + user…),
file đó dài hàng nghìn dòng, khó đọc, khó dùng lại cho dự án khác. Role giải quyết bằng cách
**tách theo chức năng** và **theo loại nội dung** (task, biến, template, file…).

Lợi ích:
- **Tái sử dụng**: viết role `webserver` một lần, dùng cho nhiều playbook/dự án.
- **Dễ bảo trì**: mỗi loại nội dung một chỗ, sửa template không phải đụng vào task.
- **Chia việc trong nhóm**: mỗi người phụ trách một role.
- **Chia sẻ cộng đồng**: đưa lên/tải về từ **Ansible Galaxy**.

## 2. Sơ đồ cây thư mục Role (có chú thích)

```
roles/
└── webserver/                    ← tên role (gọi trong playbook bằng tên này)
    ├── tasks/
    │   └── main.yml              ← BẮT BUỘC nếu role có việc làm. Danh sách task chính,
    │                                Ansible tự chạy file main.yml này
    ├── handlers/
    │   └── main.yml              ← Task "chờ gọi": chỉ chạy khi task khác notify
    │                                (vd: restart nginx khi file cấu hình thay đổi)
    ├── templates/
    │   └── index.html.j2         ← File mẫu Jinja2 có biến {{ ... }},
    │                                module `template` render rồi đẩy lên máy đích
    ├── files/
    │   └── nginx-security.conf   ← File tĩnh, copy nguyên vẹn bằng module `copy`
    ├── defaults/
    │   └── main.yml              ← Biến MẶC ĐỊNH, ưu tiên THẤP NHẤT → người dùng dễ ghi đè
    ├── vars/
    │   └── main.yml              ← Biến NỘI BỘ của role, ưu tiên CAO → không nên ghi đè
    └── meta/
        └── main.yml              ← Thông tin role: tác giả, mô tả, OS hỗ trợ,
                                     dependencies (role khác cần chạy trước)
```

Ngoài ra có thể có: `tests/` (playbook test role), `README.md`, `library/` (module tự viết).

Điểm hay: trong role, module `template`/`copy` **tự tìm** trong `templates/` và `files/`,
nên chỉ cần ghi `src: index.html.j2`, không cần đường dẫn đầy đủ.

👉 Role mẫu đầy đủ trong thư mục này: [roles/webserver/](roles/webserver/), được gọi bởi [site.yml](site.yml).

Tạo khung role tự động:

```bash
ansible-galaxy role init roles/webserver
```

## 3. Gọi role trong playbook

```yaml
- hosts: webservers
  become: true
  roles:
    - webserver                          # gọi đơn giản
    - role: webserver                    # hoặc gọi kèm tham số ghi đè biến
      vars:
        http_port: 8080
```

Thứ tự chạy trong một play: `pre_tasks` → **roles** → `tasks` → `post_tasks`
(handlers chạy cuối mỗi phần nếu được notify).

## 4. `defaults/` vs `vars/`

| | `defaults/main.yml` | `vars/main.yml` |
|---|---|---|
| Mục đích | Giá trị mặc định, **gợi ý cho người dùng chỉnh** | Hằng số nội bộ role, **không muốn bị chỉnh** |
| Độ ưu tiên | **Thấp nhất** trong mọi loại biến | Cao (cao hơn inventory, group_vars, host_vars, play vars) |
| Ví dụ | `http_port: 80`, `site_title: "Hello"` | `nginx_service: nginx`, đường dẫn config cố định |
| Ghi đè được bằng | gần như mọi thứ (group_vars, host_vars, vars của play…) | chỉ một số ít: `set_fact`, role params, `-e` |

Mẹo nhớ: **defaults = "đề xuất"**, **vars = "quy định"**.

## 5. Thứ tự ưu tiên biến (tổng quan)

Ansible có 22 mức ưu tiên; khi thuyết trình chỉ cần nhớ bản rút gọn
(từ **thấp → cao**, cái dưới ghi đè cái trên):

```
 1. role defaults           (roles/x/defaults/main.yml)      ← yếu nhất
 2. inventory group_vars/all
 3. inventory group_vars/<nhóm>
 4. inventory host_vars/<host>
 5. facts thu thập từ máy (ansible_os_family, …)
 6. play vars / vars_files
 7. role vars               (roles/x/vars/main.yml)
 8. task vars / block vars
 9. set_fact / register
10. role params (tham số khi gọi role)
11. extra vars  (-e "http_port=9090" trên dòng lệnh)          ← mạnh nhất, luôn thắng
```

Quy luật chung: **càng cụ thể, càng gần lúc chạy → càng ưu tiên**.

Demo nhanh với role mẫu:

```bash
ansible-playbook -i ../01-inventory-playbook/inventory/hosts.ini site.yml
# web2: port 80   (group_vars ghi đè defaults)
# web1: port 8080 (host_vars ghi đè group_vars)
ansible-playbook -i ../01-inventory-playbook/inventory/hosts.ini site.yml -e http_port=9090
# mọi máy: port 9090 (extra vars thắng tất cả)
```

## 6. Ansible Galaxy

**Galaxy** (galaxy.ansible.com) là kho chia sẻ role/collection của cộng đồng, giống npm/pip.

```bash
ansible-galaxy role install geerlingguy.nginx      # tải 1 role về ~/.ansible/roles
ansible-galaxy role list                            # xem role đã cài
ansible-galaxy install -r requirements.yml          # cài theo danh sách
ansible-galaxy collection install community.general # cài collection (gói nhiều module/role)
```

`requirements.yml` — ghi danh sách role cần cho dự án (giống `requirements.txt` của Python):

```yaml
roles:
  - name: geerlingguy.nginx
    version: 3.2.0
```

**Role vs Collection**: collection là đơn vị lớn hơn, có thể chứa nhiều role + module + plugin.
Các module như `ansible.builtin.copy` hay `community.general.ufw` đều thuộc một collection.

---

## Câu hỏi có thể bị hỏi

1. **Role khác playbook?** → Role không tự chạy được, phải được playbook gọi. Role là "linh kiện", playbook là "lắp ráp".
2. **Biến để ở `defaults` hay `vars`?** → Muốn người dùng chỉnh được → `defaults`. Cố định → `vars`.
3. **Handler chạy khi nào?** → Cuối play (hoặc khi gặp `meta: flush_handlers`), chỉ khi có task `notify` và task đó `changed`. Notify nhiều lần vẫn chỉ chạy 1 lần.
4. **`meta/main.yml` có `dependencies` để làm gì?** → Khai báo role khác phải chạy trước (vd role `webserver` cần role `common`).
