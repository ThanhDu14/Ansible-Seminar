# Jinja2 Template trong Ansible – Ứng dụng cấu hình Nginx

> Mục tiêu: nắm cú pháp Jinja2 (`{{ }}`, `{% if %}`, `{% for %}`, filter), phân biệt module `template` và `copy`, dùng Ansible facts trong template, dùng handler để reload nginx.
> Sản phẩm: ghi chú này + `templates/nginx.conf.j2` + `group_vars/web.yml` + `playbook.yml`.

```
jinja2-nginx/
├── jinja2-nginx.md          # ghi chú (file này)
├── playbook.yml             # playbook deploy nginx.conf
├── group_vars/
│   └── web.yml              # biến cho group [web]
└── templates/
    └── nginx.conf.j2        # template Jinja2
```

---

## 1. Jinja2 là gì?

Jinja2 là template engine của Python. Ansible dùng Jinja2 để:

- Thay biến trong playbook: `name: "{{ pkg_name }}"`
- Sinh file cấu hình động qua module `template` (file `.j2`)
- Tính toán điều kiện: `when: ansible_facts['os_family'] == "Debian"` (bản chất cũng là biểu thức Jinja2)

**Quan trọng:** template được render **trên máy control node** (máy chạy Ansible), sau đó file kết quả mới được đẩy sang máy đích. Máy đích không cần cài Jinja2.

---

## 2. Cú pháp cơ bản

| Cú pháp | Ý nghĩa | Ví dụ |
|---|---|---|
| `{{ ... }}` | In ra giá trị biến / biểu thức | `listen {{ nginx_port }};` |
| `{% ... %}` | Câu lệnh điều khiển (if, for, set…) | `{% if ssl_enabled %}` |
| `{# ... #}` | Comment – không xuất hiện trong file kết quả | `{# phần upstream #}` |

### 2.1. Biến `{{ biến }}`

```jinja
user {{ nginx_user }};
worker_connections {{ nginx_worker_connections }};

{# Truy cập dict / list #}
server {{ backend.host }}:{{ backend.port }};      {# dấu chấm #}
server {{ backend['host'] }}:{{ backend['port'] }}; {# ngoặc vuông – an toàn hơn #}
{{ nginx_gzip_types[0] }}                          {# phần tử đầu của list #}
```

> Dùng `['key']` khi tên key trùng với method của Python (`items`, `keys`, `values`…) hoặc có ký tự đặc biệt.

### 2.2. Điều kiện `{% if %}`

```jinja
{% if nginx_ssl_enabled %}
    listen 443 ssl;
    ssl_certificate     {{ nginx_ssl_cert }};
    ssl_certificate_key {{ nginx_ssl_key }};
{% elif nginx_port is defined %}
    listen {{ nginx_port }};
{% else %}
    listen 80;
{% endif %}
```

Các phép kiểm tra hay dùng:

| Biểu thức | Ý nghĩa |
|---|---|
| `x is defined` / `x is not defined` | Biến có tồn tại không |
| `x == 'abc'`, `x != 1`, `x > 2` | So sánh |
| `'gzip' in features` | Phần tử có trong list / chuỗi |
| `a and b`, `a or b`, `not a` | Logic |
| `x is string`, `x is number`, `x is iterable` | Kiểm tra kiểu |

If một dòng (inline / ternary):

```jinja
server_tokens {{ 'on' if nginx_server_tokens else 'off' }};
```

### 2.3. Vòng lặp `{% for %}`

```jinja
{% for srv in upstream.servers %}
    server {{ srv.host }}:{{ srv.port }};
{% endfor %}
```

Lặp qua dict:

```jinja
{% for key, value in nginx_headers.items() %}
    add_header {{ key }} "{{ value }}";
{% endfor %}
```

Biến đặc biệt `loop`:

| Biến | Ý nghĩa |
|---|---|
| `loop.index` | Thứ tự lặp, bắt đầu từ 1 |
| `loop.index0` | Thứ tự lặp, bắt đầu từ 0 |
| `loop.first` / `loop.last` | Có phải phần tử đầu / cuối không |
| `loop.length` | Tổng số phần tử |

```jinja
{% for vhost in nginx_vhosts %}
# vhost {{ loop.index }}/{{ loop.length }}: {{ vhost.server_name }}
{% else %}
# Không có vhost nào được khai báo   {# chạy khi list rỗng #}
{% endfor %}
```

### 2.4. Filter cơ bản

Filter dùng dấu `|` để biến đổi giá trị: `{{ biến | filter(tham_số) }}`. Có thể nối nhiều filter.

| Filter | Ví dụ | Kết quả |
|---|---|---|
| `default(x)` | `{{ port \| default(80) }}` | `80` nếu `port` chưa định nghĩa |
| `upper` / `lower` | `{{ 'warn' \| upper }}` | `WARN` |
| `join(sep)` | `{{ ['a','b'] \| join(' ') }}` | `a b` |
| `length` | `{{ servers \| length }}` | số phần tử |
| `int` / `string` / `bool` | `{{ '8080' \| int + 1 }}` | `8081` |
| `replace(a, b)` | `{{ 'a.b.c' \| replace('.', '_') }}` | `a_b_c` |
| `trim` | `{{ '  x  ' \| trim }}` | `x` |
| `first` / `last` | `{{ servers \| first }}` | phần tử đầu |
| `sort` / `unique` | `{{ [3,1,1] \| unique \| sort }}` | `[1, 3]` |
| `mandatory` | `{{ domain \| mandatory }}` | báo lỗi nếu biến chưa định nghĩa |
| `ternary(a, b)` | `{{ ssl \| ternary('https', 'http') }}` | chọn giá trị theo true/false |
| `to_nice_yaml` / `to_nice_json` | `{{ cfg \| to_nice_json }}` | in dict ra dạng YAML/JSON đẹp |
| `ipaddr` *(cần `ansible.utils`)* | `{{ ip \| ansible.utils.ipaddr }}` | kiểm tra/định dạng IP |

Ví dụ nối filter:

```jinja
gzip_types {{ nginx_gzip_types | default(['text/plain']) | unique | join(' ') }};
```

### 2.5. Kiểm soát khoảng trắng (whitespace)

Các thẻ `{% %}` để lại dòng trống trong file kết quả – với nginx thì vô hại nhưng file sẽ xấu.

- Module `template` mặc định: `trim_blocks: true` (xóa xuống dòng sau thẻ), `lstrip_blocks: false`.
- Muốn **thụt lề thẻ `{% %}`** cho dễ đọc mà không bị dư khoảng trắng → bật `lstrip_blocks`:
  - Đặt ở **dòng đầu tiên** của file `.j2`: `#jinja2: trim_blocks: True, lstrip_blocks: True`
  - Hoặc trong task: `lstrip_blocks: true`
- Hoặc dùng dấu `-` để xóa khoảng trắng thủ công: `{%- if x -%}`, `{{- var -}}`

---

## 3. Module `template` vs `copy`

| Tiêu chí | `copy` | `template` |
|---|---|---|
| Nội dung file | Copy **nguyên văn** | **Render Jinja2** rồi mới copy |
| Thư mục chứa file (trong role) | `files/` | `templates/` |
| Đuôi file quen dùng | giữ nguyên (`.conf`, `.html`…) | `.j2` |
| Dùng biến / facts trong file | ❌ (`{{ }}` giữ nguyên) | ✅ |
| Copy file có sẵn trên máy đích (`remote_src`) | ✅ | ❌ (src luôn ở control node) |
| Ghi nội dung inline (`content:`) | ✅ | ❌ |
| Copy cả thư mục | ✅ | ❌ (từng file; dùng kèm `loop` / `with_fileglob`) |
| `owner`, `group`, `mode`, `backup`, `validate` | ✅ | ✅ |

**Khi nào dùng cái nào?**

- File **tĩnh, giống hệt nhau** trên mọi server (logo, `mime.types`, chứng chỉ, file HTML tĩnh) → `copy`.
- File **thay đổi theo môi trường / host** (`nginx.conf`, vhost, upstream, port, số worker…) → `template`.

```yaml
# copy: nội dung y nguyên
- name: Copy trang index tĩnh
  ansible.builtin.copy:
    src: files/index.html
    dest: /var/www/example/index.html
    mode: "0644"

# template: render biến rồi mới đẩy lên
- name: Render nginx.conf
  ansible.builtin.template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    mode: "0644"
    backup: true                 # giữ bản cũ có timestamp
    validate: nginx -t -c %s     # kiểm tra cú pháp TRƯỚC khi ghi đè
  notify: Reload nginx
```

> **Lưu ý `validate`:** `%s` là file tạm đã render. `nginx -t -c %s` chỉ hợp lệ với **file nginx.conf đầy đủ** (có `events {}`, `http {}`). Với file vhost con trong `conf.d/` / `sites-available/` thì không validate trực tiếp được – nên chạy `nginx -t` trong handler hoặc task riêng sau khi deploy.

Cả hai module đều **idempotent**: nếu nội dung không đổi → trạng thái `ok`, không trigger handler.

---

## 4. Ansible facts trong template

### 4.1. Facts là gì?

Facts là thông tin về máy đích (OS, CPU, RAM, IP, hostname…) do module `setup` thu thập. Mặc định chạy ở đầu mỗi play:

```yaml
- hosts: web
  gather_facts: true     # mặc định là true; đặt false để chạy nhanh hơn nếu không cần facts
```

Xem facts của một host:

```bash
ansible web01 -m setup                                   # tất cả facts
ansible web01 -m setup -a "filter=ansible_default_ipv4"  # lọc theo tên
ansible web01 -m setup -a "filter=ansible_processor*"
```

### 4.2. Cách truy cập

```jinja
{{ ansible_facts['hostname'] }}            {# cách khuyến nghị #}
{{ ansible_hostname }}                     {# cách cũ: biến inject với tiền tố ansible_ #}
```

Nên dùng `ansible_facts['...']`: rõ ràng, không đụng tên biến khác, và kiểu inject `ansible_*` (cấu hình `INJECT_FACTS_AS_VARS`) có thể bị tắt.

> Trong `ansible_facts` **không có** tiền tố `ansible_`: `ansible_facts['default_ipv4']` ⇔ `ansible_default_ipv4`.

### 4.3. Các facts hay dùng cho nginx

| Fact | Ví dụ giá trị | Dùng cho |
|---|---|---|
| `ansible_facts['hostname']` | `web01` | comment, `server_name`, header |
| `ansible_facts['fqdn']` | `web01.example.com` | `server_name` |
| `ansible_facts['default_ipv4']['address']` | `10.0.0.10` | `listen IP:port` |
| `ansible_facts['processor_vcpus']` | `4` | `worker_processes` |
| `ansible_facts['memtotal_mb']` | `7953` | tính cache / buffer |
| `ansible_facts['os_family']` | `Debian` / `RedHat` | chọn user `www-data` / `nginx` |
| `ansible_facts['distribution']`, `['distribution_version']` | `Ubuntu`, `24.04` | comment, điều kiện |

Ví dụ:

```jinja
worker_processes {{ ansible_facts['processor_vcpus'] }};

user {{ 'www-data' if ansible_facts['os_family'] == 'Debian' else 'nginx' }};

{# Lấy IP của tất cả host trong group "app" làm upstream (cần gather facts cho group app) #}
upstream app_backend {
{% for host in groups['app'] %}
    server {{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }}:8080;
{% endfor %}
}
```

> `hostvars[host]['ansible_facts']` chỉ có dữ liệu nếu play đã thu thập facts cho host đó (ví dụ một play trước `hosts: app` với `gather_facts: true`, hoặc dùng fact cache).

### 4.4. Biến `ansible_managed`

Đặt `# {{ ansible_managed }}` ở đầu file để cảnh báo người khác "file này do Ansible quản lý, sửa tay sẽ bị ghi đè". Nội dung chuỗi cấu hình trong `ansible.cfg` (`ansible_managed = ...`).

---

## 5. Ví dụ hoàn chỉnh

### 5.1. Template – `templates/nginx.conf.j2`

```jinja
#jinja2: trim_blocks: True, lstrip_blocks: True
# {{ ansible_managed }}
# Host: {{ ansible_facts['hostname'] }} ({{ ansible_facts['default_ipv4']['address'] | default('n/a') }})
# OS  : {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
# CPU : {{ ansible_facts['processor_vcpus'] }} vCPU - RAM: {{ ansible_facts['memtotal_mb'] }} MB

user {{ nginx_user }};
worker_processes {{ nginx_worker_processes | default(ansible_facts['processor_vcpus']) }};
pid /run/nginx.pid;

events {
    worker_connections {{ nginx_worker_connections | default(1024) }};
}

http {
    sendfile on;
    tcp_nopush on;
    keepalive_timeout {{ nginx_keepalive_timeout | default(65) }};
    server_tokens {{ 'on' if nginx_server_tokens | default(false) else 'off' }};
    client_max_body_size {{ nginx_client_max_body_size | default('1m') }};

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log {{ nginx_error_log_level | default('warn') }};

    {% if nginx_gzip_enabled | default(true) %}
    gzip on;
    gzip_comp_level {{ nginx_gzip_comp_level | default(5) }};
    gzip_types {{ nginx_gzip_types | join(' ') }};
    {% endif %}

    {# ---------- Upstreams ---------- #}
    {% for upstream in nginx_upstreams | default([]) %}
    upstream {{ upstream.name }} {
        {% if upstream.lb_method is defined %}
        {{ upstream.lb_method }};
        {% endif %}
        {% for srv in upstream.servers %}
        server {{ srv.host }}:{{ srv.port }}{% if srv.weight is defined %} weight={{ srv.weight }}{% endif %};
        {% endfor %}
    }

    {% endfor %}
    {# ---------- Virtual hosts ---------- #}
    {% for vhost in nginx_vhosts %}
    server {
        listen {{ vhost.listen | default(80) }};
        server_name {{ vhost.server_name | join(' ') if vhost.server_name is not string else vhost.server_name }};
        {% if vhost.root is defined %}
        root {{ vhost.root }};
        index index.html index.htm;
        {% endif %}

        {% for loc in vhost.locations | default([]) %}
        location {{ loc.path }} {
            {% if loc.proxy_pass is defined %}
            proxy_pass {{ loc.proxy_pass }};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            {% else %}
            try_files $uri $uri/ =404;
            {% endif %}
        }
        {% endfor %}
    }

    {% endfor %}
}
```

Các kỹ thuật đã dùng trong template:

| Kỹ thuật | Vị trí |
|---|---|
| `{{ biến }}` | `nginx_user`, `nginx_worker_connections`… |
| Facts | `ansible_facts['processor_vcpus']`, `hostname`, `default_ipv4`… |
| `{% if %}` | bật/tắt gzip, `lb_method`, `root`, `proxy_pass` hay `try_files` |
| `{% for %}` lồng nhau | upstream → servers, vhost → locations |
| Filter | `default`, `join`, inline-if (`'on' if ... else 'off'`) |
| Kiểm tra kiểu | `is defined`, `is not string` (server_name nhận cả chuỗi lẫn list) |
| Comment Jinja | `{# ---------- Upstreams ---------- #}` |
| Whitespace control | dòng `#jinja2: trim_blocks: True, lstrip_blocks: True` |

### 5.2. Biến – `group_vars/web.yml`

```yaml
---
nginx_user: www-data
# Bỏ comment để ghi đè; mặc định lấy theo fact processor_vcpus
# nginx_worker_processes: 2
nginx_worker_connections: 2048
nginx_keepalive_timeout: 65
nginx_server_tokens: false
nginx_client_max_body_size: 20m
nginx_error_log_level: warn

nginx_gzip_enabled: true
nginx_gzip_comp_level: 5
nginx_gzip_types:
  - text/plain
  - text/css
  - application/json
  - application/javascript

nginx_upstreams:
  - name: app_backend
    lb_method: least_conn
    servers:
      - { host: 10.0.0.11, port: 8080, weight: 3 }
      - { host: 10.0.0.12, port: 8080 }

nginx_vhosts:
  - server_name: [example.com, www.example.com]
    listen: 80
    root: /var/www/example
    locations:
      - path: /
      - path: /api/
        proxy_pass: http://app_backend
```

### 5.3. Playbook – `playbook.yml`

```yaml
---
- name: Deploy nginx.conf bằng Jinja2 template
  hosts: web
  become: true
  gather_facts: true

  tasks:
    - name: Cài nginx
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Render nginx.conf từ template
      ansible.builtin.template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: "0644"
        backup: true
        validate: nginx -t -c %s
      notify: Reload nginx

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

Inventory mẫu (`inventory.ini`):

```ini
[web]
web01 ansible_host=10.0.0.10
```

Chạy:

```bash
ansible-playbook -i inventory.ini playbook.yml --check --diff   # xem trước thay đổi
ansible-playbook -i inventory.ini playbook.yml                  # áp dụng thật
```

### 5.4. Kết quả render

Với host `web01` (Ubuntu 24.04, 4 vCPU, IP `10.0.0.10`), file `/etc/nginx/nginx.conf` sinh ra:

```nginx
# Ansible managed
# Host: web01 (10.0.0.10)
# OS  : Ubuntu 24.04
# CPU : 4 vCPU - RAM: 7953 MB

user www-data;
worker_processes 4;
pid /run/nginx.pid;

events {
    worker_connections 2048;
}

http {
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    server_tokens off;
    client_max_body_size 20m;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log warn;

    gzip on;
    gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/javascript;

    upstream app_backend {
        least_conn;
        server 10.0.0.11:8080 weight=3;
        server 10.0.0.12:8080;
    }

    server {
        listen 80;
        server_name example.com www.example.com;
        root /var/www/example;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }
        location /api/ {
            proxy_pass http://app_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }

}
```

Để ý: `worker_processes 4` lấy từ fact `processor_vcpus` vì `nginx_worker_processes` chưa được khai báo → filter `default()` phát huy tác dụng.

---

## 6. Handler trong Ansible

### 6.1. Handler là gì?

Handler là một task đặc biệt, **chỉ chạy khi được gọi (`notify`)** từ một task khác **và** task đó có trạng thái `changed`.

Bài toán điển hình với nginx: chỉ reload nginx khi file cấu hình thực sự thay đổi. Nếu nội dung không đổi (`ok`) thì không reload, tránh làm gián đoạn dịch vụ vô ích.

```yaml
tasks:
  - name: Render nginx.conf
    ansible.builtin.template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Reload nginx            # gọi handler theo đúng tên

handlers:
  - name: Reload nginx              # tên phải khớp chính xác với notify
    ansible.builtin.service:
      name: nginx
      state: reloaded
```

| Trạng thái task `template` | Handler `Reload nginx` |
|---|---|
| `changed` (file mới hoặc nội dung khác) | ✅ được gọi |
| `ok` (nội dung y hệt) | ❌ không chạy |
| `failed` (ví dụ `validate` lỗi) | ❌ không chạy |

### 6.2. Các quy tắc quan trọng

1. **Chạy ở cuối, không chạy ngay.** Handler được gom lại và chạy sau khi **hết phần tasks** của play (cụ thể: sau mỗi phần `pre_tasks`, `roles`/`tasks`, `post_tasks`).
2. **Chỉ chạy 1 lần mỗi host.** Dù 5 task cùng notify `Reload nginx`, nginx chỉ reload **một lần**.
3. **Thứ tự chạy theo thứ tự khai báo** trong phần `handlers:`, **không** theo thứ tự notify.
4. **Notify bằng tên.** Sai một ký tự là lỗi `The requested handler 'xxx' was not found`. Không nên dùng biến trong tên handler.
5. **Một task có thể notify nhiều handler:**
   ```yaml
   notify:
     - Validate nginx config
     - Reload nginx
   ```
6. **Handler có thể notify handler khác** (chuỗi handler).

### 6.3. Ví dụ: notify nhiều lần → chỉ chạy 1 lần

```yaml
tasks:
  - name: Render nginx.conf
    ansible.builtin.template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Reload nginx

  - name: Render các vhost
    ansible.builtin.template:
      src: "templates/vhost.conf.j2"
      dest: "/etc/nginx/conf.d/{{ item.server_name | first }}.conf"
    loop: "{{ nginx_vhosts }}"
    notify: Reload nginx           # 3 vhost thay đổi vẫn chỉ reload 1 lần
```

Output khi chạy:

```
TASK [Render nginx.conf] ***********************
changed: [web01]

TASK [Render các vhost] ************************
changed: [web01] => (item=...)
changed: [web01] => (item=...)

RUNNING HANDLER [Reload nginx] *****************
changed: [web01]
```

### 6.4. `listen` – gọi nhiều handler bằng một "topic"

Thay vì notify từng tên, các handler cùng `listen` một topic; task chỉ cần notify topic đó.

```yaml
tasks:
  - name: Render nginx.conf
    ansible.builtin.template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: nginx config changed

handlers:
  # Thứ tự khai báo = thứ tự chạy: kiểm tra trước, reload sau
  - name: Validate nginx config
    ansible.builtin.command: nginx -t
    changed_when: false
    listen: nginx config changed

  - name: Reload nginx
    ansible.builtin.service:
      name: nginx
      state: reloaded
    listen: nginx config changed
```

Nếu `nginx -t` lỗi → handler kiểm tra fail → host đó dừng → **không reload**, nginx vẫn chạy với cấu hình cũ đang có trong bộ nhớ. Cách này hữu ích cho file vhost con, vì loại file này không dùng được `validate:` (xem mục 3).

### 6.5. `meta: flush_handlers` – chạy handler ngay giữa chừng

Đôi khi cần nginx reload **trước** các task phía sau (ví dụ kiểm tra website bằng `uri`):

```yaml
tasks:
  - name: Render nginx.conf
    ansible.builtin.template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Reload nginx

  - name: Chạy ngay các handler đang chờ
    ansible.builtin.meta: flush_handlers

  - name: Kiểm tra website trả về 200
    ansible.builtin.uri:
      url: "http://{{ ansible_facts['default_ipv4']['address'] }}/"
      status_code: 200
```

### 6.6. Khi play bị lỗi giữa chừng – `force_handlers`

Mặc định nếu **một task phía sau bị fail**, các handler đã được notify trên host đó sẽ **không chạy**. Hậu quả là file config đã đổi nhưng nginx chưa reload.

Cách xử lý:

```yaml
- hosts: web
  force_handlers: true     # vẫn chạy handler dù có task fail
```

Hoặc dùng cờ dòng lệnh `ansible-playbook playbook.yml --force-handlers`.

### 6.7. `reload` hay `restart`?

| | `state: reloaded` | `state: restarted` |
|---|---|---|
| Cách hoạt động | Gửi tín hiệu HUP: master đọc lại config, worker cũ xử lý nốt request rồi thoát | Dừng hẳn rồi khởi động lại |
| Downtime | Không | Có, trong vài giây ngắn |
| Dùng khi | Đổi `nginx.conf`, vhost, upstream, SSL cert | Nâng cấp nginx, thêm/bớt module động, đổi `user`/`pid` |

Với thay đổi cấu hình thông thường, **luôn ưu tiên `reloaded`**.

### 6.8. Handler trong role

Trong role, handler đặt ở `handlers/main.yml` và tự động được nạp:

```
roles/nginx/
├── tasks/main.yml        # notify: Reload nginx
├── handlers/main.yml     # định nghĩa handler Reload nginx
├── templates/nginx.conf.j2
└── defaults/main.yml
```

```yaml
# roles/nginx/handlers/main.yml
---
- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded

- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

---

## 7. Debug & lỗi thường gặp

**Thử biểu thức nhanh:**

```bash
ansible web01 -m debug -a "msg={{ ansible_facts['processor_vcpus'] }}"
ansible web01 -m debug -a "msg={{ nginx_gzip_types | join(' ') }}" -e @group_vars/web.yml
```

**Xem diff trước khi ghi đè:** `ansible-playbook playbook.yml --check --diff`

| Lỗi | Nguyên nhân | Cách xử lý |
|---|---|---|
| `'xxx' is undefined` | Biến chưa khai báo | Khai báo biến, hoặc dùng `default()` |
| `'dict object' has no attribute 'ansible_facts'` | Không thu thập facts (`gather_facts: false`) hoặc host trong `hostvars` chưa được gather | Bật `gather_facts`, hoặc chạy `setup` cho host đó |
| `template error while templating string` | Sai cú pháp: thiếu `{% endif %}` / `{% endfor %}`, sai dấu ngoặc | Kiểm tra mỗi `if`/`for` đều có thẻ đóng |
| `validate` thất bại → task `failed` | Config nginx render ra không hợp lệ | Đọc output `nginx -t`; file cũ **không** bị ghi đè |
| File có nhiều dòng trống / thụt lề lệch | Khoảng trắng do thẻ `{% %}` | Bật `lstrip_blocks`, hoặc dùng `{%-` `-%}` |
| `{{ }}` trong nginx bị Ansible hiểu nhầm | Nội dung thật sự có `{{` (hiếm với nginx) | Bọc bằng `{% raw %} ... {% endraw %}` |

---

| `The requested handler 'xxx' was not found` | Tên trong `notify` không khớp tên handler | Sửa cho khớp chính xác (phân biệt hoa/thường) |
| Đổi config nhưng nginx không reload | Task sau bị fail nên handler bị bỏ qua | `force_handlers: true` hoặc `--force-handlers` |

---

## 8. Tóm tắt

- `{{ }}` in giá trị, `{% %}` điều khiển (if/for), `{# #}` comment.
- Filter `|` để biến đổi dữ liệu: `default`, `join`, `upper`, `length`, `int`, `ternary`…
- `copy` = copy nguyên văn; `template` = render Jinja2 trên control node rồi copy. File cấu hình động → luôn dùng `template` + `validate` + `notify` handler.
- Facts (`ansible_facts['...']`) cho phép template tự điều chỉnh theo từng máy: số CPU, IP, OS…
- Handler chỉ chạy khi task notify có trạng thái `changed`. Handler chạy ở cuối play, mỗi host 1 lần, theo thứ tự khai báo. Dùng `listen` để gom nhóm, `meta: flush_handlers` để chạy sớm, `force_handlers` để không bị bỏ sót khi có task lỗi.
