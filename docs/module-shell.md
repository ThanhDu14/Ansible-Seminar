# Module Chuyên Dụng vs Shell/Command Trong Ansible

---

## 1. Phân biệt các lệnh `command`, `shell`, `raw`, `script`

Trong Ansible, có 4 module chính cho phép thực thi câu lệnh hoặc script. Việc hiểu rõ ranh giới kỹ thuật giữa chúng là nền tảng để viết playbook an toàn và hiệu quả.

```text
                        Các module thực thi lệnh trong Ansible
                                          │
            ┌─────────────────────────────┴─────────────────────────────┐
            ▼                                                           ▼
    CẦN Python trên máy đích                                KHÔNG CẦN Python trên máy đích
    ┌──────────────────────┐                                ┌──────────────────────┐
    │  ansible.builtin.    │                                │  ansible.builtin.    │
    │  command             │                                │  raw                 │
    │  (Chạy binary trực   │                                │  (Chạy qua SSH stream│
    │   tiếp, không shell) │                                │   dùng bootstrap)    │
    ├──────────────────────┤                                ├──────────────────────┤
    │  ansible.builtin.    │                                │  ansible.builtin.    │
    │  shell               │                                │  script              │
    │  (Chạy qua /bin/sh,  │                                │  (Copy script từ máy │
    │   hỗ trợ pipe, env)  │                                │   điều khiển sang)   │
    └──────────────────────┘                                └──────────────────────┘
```

### 1.1 Chi tiết từng module

#### A. `ansible.builtin.command` 
- **Cơ chế:** Gọi trực tiếp binary thực thi thông qua Python subsystem trên máy đích (tương đương `subprocess.Popen(..., shell=False)`).
- **Yêu cầu:** **CẦN Python** trên máy đích.
- **Đặc điểm:** Không chạy qua trình thông dịch shell (`/bin/sh`). Vì vậy **KHÔNG hỗ trợ** các tính năng của shell như: pipe `|`, redirect `>`, `>>`, `<`, gom lệnh `;`, `&&`, wildcard `*`, biến môi trường dạng `$VAR`.
- **Ưu điểm:** An toàn cao, loại bỏ hoàn toàn nguy cơ **Shell Injection** khi truyền biến người dùng.
- **Bẫy kinh điển (Gotcha):**
  ```yaml
  - name: Ghi log
    ansible.builtin.command: echo "data" >> /tmp/test.log
  ```
  *Hệ quả:* Ký tự `>>` và chuỗi `/tmp/test.log` bị xem là 2 đối số văn bản bình thường của lệnh `echo`. Lệnh in ra chữ `data >> /tmp/test.log` lên màn hình, **không có file nào được tạo**, nhưng Ansible vẫn báo `changed`!

#### B. `ansible.builtin.shell`
- **Cơ chế:** Đóng gói câu lệnh và truyền vào trình thông dịch shell trên máy đích (mặc định là `/bin/sh -c`).
- **Yêu cầu:** **CẦN Python** trên máy đích.
- **Đặc điểm:** Hỗ trợ đầy đủ cú pháp shell (pipe `|`, redirect `>`, toán tử `&&`, `||`, wildcard `*.conf`, biến môi trường `$HOME`).
- **Rủi ro:** Tiềm ẩn lỗ hổng bảo mật nếu nối chuỗi biến chưa qua lọc (`shell injection`); khó kiểm soát trạng thái.

#### C. `ansible.builtin.raw`
- **Cơ chế:** Gửi chuỗi lệnh thô trực tiếp qua phiên SSH hoặc WinRM, tương tự như khi bạn gõ trực tiếp `ssh user@host "command"`.
- **Yêu cầu:** **KHÔNG CẦN Python** trên máy đích.
- **Tình huống sử dụng:**
  - Bootstrap máy chủ mới chưa có Python:
    ```yaml
    - name: Cài đặt Python ban đầu
      ansible.builtin.raw: test -e /usr/bin/python3 || (apt update && apt install -y python3)
    ```
  - Quản lý các thiết bị mạng nhúng (Router, Switch Cisco, thiết bị IoT không có môi trường Python).

#### D. `ansible.builtin.script`
- **Cơ chế:** Tự động copy một file script (Bash, Python, Perl...) nằm trên **máy điều khiển (Control Node)** sang một thư mục tạm trên **máy đích (Managed Node)**, cấp quyền thực thi `chmod +x`, chạy script đó, rồi tự dọn dẹp file tạm.
- **Yêu cầu:** **KHÔNG CẦN Python** trên máy đích (chỉ cần môi trường chạy được script đó, ví dụ `/bin/bash` hoặc `/bin/sh`).
- **Tình huống sử dụng:** Khi bạn đã có sẵn các script Bash phức tạp dài hàng trăm dòng của hệ thống cũ và muốn tái sử dụng mà không cần viết lại toàn bộ thành task Ansible.

### 1.2 Bảng so sánh 4 module thực thi

| Tiêu chí | `command` | `shell` | `raw` | `script` |
| :--- | :---: | :---: | :---: | :---: |
| **Cần Python trên máy đích?** | **CÓ** | **CÓ** | **KHÔNG** | **KHÔNG** |
| **Hỗ trợ Pipe (`\|`), Redirect (`>`)?** | KHÔNG | **CÓ** | **CÓ** | **CÓ** (trong nội dung script) |
| **Nơi lưu trữ file script ban đầu** | Không có (chạy lệnh đơn) | Không có (chạy lệnh đơn) | Không có | **Trên Control Node** (máy chạy Ansible) |
| **Nguy cơ Shell Injection** | Thấp / An toàn | Cao | Rất cao | Phụ thuộc code script |
| **Trường hợp sử dụng tối ưu** | Chạy binary có sẵn (`ls`, `tar`, `systemctl`) | Lệnh cần pipe, lọc grep, redirect | Bootstrap Python trên OS mới | Chạy script bash dài có sẵn từ trước |

---

## 2. Vì Sao Shell/Command Không Idempotent và luôn Báo `changed: true`?

Khi bạn chạy một module như `ansible.builtin.shell` hoặc `command`:
```yaml
- name: Tạo thư mục bằng shell
  ansible.builtin.shell: mkdir -p /opt/myapp
```
Dù bạn chạy 10 lần, cả 10 lần Ansible đều hiển thị:
```text
changed: [localhost]
```

### Bản chất "Hộp Đen"
1. **Ansible không thể nhìn vào bên trong lệnh shell:** Ansible chỉ là người đứng ngoài gọi trình thông dịch shell, chờ đợi và nhận về 3 thông số:
   - `rc` (Return Code / Exit Code): `0` (thành công) hoặc khác 0 (lỗi).
   - `stdout`: Dữ liệu in ra luồng chuẩn.
   - `stderr`: Dữ liệu in ra luồng lỗi.
2. **Không có cơ chế tự kiểm tra trạng thái trước/sau:** Ansible không thể biết câu lệnh shell vừa rồi đã ghi thêm file, sửa quyền, cài phần mềm hay chỉ là một lệnh đọc vô hại (`cat`, `ls`).
3. **Quy tắc an toàn của Ansible:** Để tránh trường hợp quản trị viên lầm tưởng hệ thống không bị can thiệp, Ansible **mặc định gán `changed: true`** cho mọi lệnh `command`/`shell` thành công (`rc = 0`).

---

## 3. Khám Phá Cơ Chế Các Module Chuyên Dụng

Ngược lại với Shell, các **Module Chuyên Dụng ** được thiết kế theo tư duy **Desired State** và luôn có 2 bước: **Kiểm tra hiện trạng ** trước rồi mới **Hành động** nếu cần.

### 3.1 Module `ansible.builtin.copy`
- **Cơ chế:** Trước khi copy file từ máy điều khiển sang máy đích, Ansible tính toán mã băm (checksum SHA1 / MD5) của cả 2 file.
- **Xử lý:**
  - Nếu mã băm giống nhau 100% $\rightarrow$ Không copy gì cả, báo `ok`.
  - Nếu mã băm khác nhau hoặc file đích chưa tồn tại $\rightarrow$ Copy đè file mới, cập nhật quyền và báo `changed`.

### 3.2 Module `ansible.builtin.lineinfile`
- **Cơ chế:** Đọc file đích và dùng biểu thức chính quy (Regex) quét từng dòng.
- **Xử lý:**
  - Nếu dòng khai báo trong `line:` đã tồn tại đúng vị trí $\rightarrow$ Bỏ qua, báo `ok`.
  - Nếu dòng chưa có hoặc nội dung sai lệch $\rightarrow$ Chèn mới hoặc thay thế đúng dòng đó, báo `changed`.
  - Hỗ trợ xem trực tiếp các dòng thay đổi qua cờ `--diff`.

### 3.3 Module `ansible.builtin.systemd_service` / `service`
> **LƯU Ý QUAN TRỌNG:**
> - Chỉ có `state: started` và `state: stopped` là **Lũy đẳng (Idempotent)**:
>   - Nếu service đang chạy mà gọi `state: started` $\rightarrow$ Ansible kiểm tra thấy đang active nên giữ nguyên (`ok`).
> - Ngược lại: `state: restarted` và `state: reloaded` **LUÔN LUÔN BÁO `changed`**! Bởi vì hành vi restart là ngắt tiến trình và khởi động lại, luôn tạo ra tác động lên hệ thống.

#### Mô hình chuẩn IaC: Kết hợp `state: started` với Handlers (`notify`)
Trong thực tế, bạn không bao giờ nên đặt `state: restarted` trong task thông thường vì nó sẽ làm gián đoạn dịch vụ ở mỗi lần chạy playbook. Cách làm chuẩn:
1. Đặt task quản lý dịch vụ ở trạng thái `state: started` (luôn `ok` nếu đang chạy).
2. Khi sửa file cấu hình (bằng `copy`, `template`, hoặc `lineinfile`), thêm chỉ thị `notify: Restart Nginx`.
3. Chỉ khi file cấu hình **thực sự thay đổi** (task báo `changed`), Handler mới được kích hoạt để khởi động lại dịch vụ một lần duy nhất vào cuối Playbook.

```yaml
- name: Cập nhật file cấu hình Nginx
  ansible.builtin.copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
  notify: Restart Nginx   # Chỉ kích hoạt nếu task này báo 'changed'

- name: Đảm bảo service Nginx luôn chạy
  ansible.builtin.systemd_service:
    name: nginx
    state: started        # Lũy đẳng: nếu đang chạy rồi thì báo 'ok'

handlers:
  - name: Restart Nginx
    ansible.builtin.systemd_service:
      name: nginx
      state: restarted    # Chỉ chạy khi nhận tín hiệu notify
```

### 3.4 Module `ansible.builtin.apt` / `package`
- **Cơ chế:** Kiểm tra cơ sở dữ liệu quản lý gói cục bộ (`dpkg-query -W` trên Debian/Ubuntu hoặc `rpm -q` trên RHEL).
- **Xử lý:**
  - Nếu gói đã được cài đặt và khớp phiên bản yêu cầu $\rightarrow$ Báo `ok`, không tải lại từ Internet.
  - Nếu gói chưa có $\rightarrow$ Gọi apt-get cài đặt và báo `changed`.

---

## 4. Kỹ Thuật bieesn Shell/Command Thành Lũy Đẳng

Khi bắt buộc phải sử dụng shell, bạn có thể dùng các thuộc tính sau để biến lệnh shell thành lũy đẳng.

### 4.1 Tham số `creates` và `removes`
- **`creates: /path/to/file`:** Chỉ thực thi lệnh nếu file/thư mục này **CHƯA** tồn tại. Nếu đã có file, Ansible tự động bỏ qua và đánh dấu `ok`.
  > **Lưu ý then chốt khi dùng `creates`:** File được chỉ định trong `creates:` **bắt buộc phải là file thực sự được sinh ra** từ câu lệnh đó!
  > - *Trường hợp 1 (Dùng file có sẵn trong gói nén):* Nếu file nén giải nén ra file `sample.txt`, ta chỉ định trực tiếp file đó:
  >   ```yaml
  >   - name: Giải nén file mẫu (Lũy đẳng nhờ file trích xuất có thật)
  >     ansible.builtin.shell: tar -xzf files/sample.tar.gz -C /opt/app
  >     args:
  >       creates: /opt/app/sample.txt
  >   ```
  > - *Trường hợp 2 (Dùng file cờ đánh dấu riêng):* Nếu muốn dùng một file cờ tùy ý như `installed.flag` (vốn không nằm trong gói nén), câu lệnh shell **bắt buộc phải chủ động tạo cờ** (bằng lệnh `touch`) sau khi hoàn thành:
  >   ```yaml
  >   - name: Giải nén gói cài đặt và tự tạo cờ (Đã lũy đẳng)
  >     ansible.builtin.shell: |
  >       tar -xzf app.tar.gz -C /opt/app && touch /opt/app/installed.flag
  >     args:
  >       creates: /opt/app/installed.flag
  >   ```
  >   *Nếu không có `touch`, file cờ sẽ không bao giờ xuất hiện $\rightarrow$ điều kiện `creates` vĩnh viễn không thỏa mãn $\rightarrow$ task sẽ luôn luôn bị chạy lại và luôn báo `changed`!*
- **`removes: /path/to/file`:** Ngược lại, chỉ thực thi lệnh nếu file này **ĐANG** tồn tại. Thường dùng cho các lệnh dọn dẹp, uninstall.

### 4.2 Mẹo `changed_when: false` cho lệnh chỉ đọc
Nhiều khi bạn chạy lệnh shell chỉ để kiểm tra thông tin (`uname`, `cat`, `id`, `docker ps`). Mặc định Ansible sẽ báo `changed: true` (rất vô lý). Giải pháp:
```yaml
- name: Lấy thông tin kernel
  ansible.builtin.command: uname -r
  register: kernel_version
  changed_when: false   # Luôn báo ok, không bao giờ báo changed!
```

### 4.3 Tự định nghĩa điều kiện thay đổi với `changed_when`
Bạn có thể bắt chuỗi kết quả in ra từ câu lệnh để quyết định xem có thay đổi thật hay không:
```yaml
- name: Chạy script cập nhật dữ liệu
  ansible.builtin.shell: /usr/local/bin/sync_data.sh
  register: sync_result
  changed_when: "'Data updated' in sync_result.stdout"
  failed_when: sync_result.rc != 0 and sync_result.rc != 42
```

### 4.4 Pattern chuẩn: `stat` + `register` + `when`
Bản thân điều kiện `when` không thể tự biết hệ thống có gì nếu không có dữ liệu đầu vào. Vì vậy, pattern kinh điển trong Ansible là: **Dùng module `stat` để kiểm tra trước $\rightarrow$ Lưu vào `register` $\rightarrow$ Điều kiện hóa lệnh `shell` bằng `when`**.

```yaml
- name: Kiểm tra trạng thái khởi tạo database
  ansible.builtin.stat:
    path: /var/lib/mysql/.initialized
  register: db_init_status

- name: Khởi tạo database lần đầu (Chỉ chạy khi chưa có cờ)
  ansible.builtin.shell: |
    mysql_install_db
    touch /var/lib/mysql/.initialized
  when: not db_init_status.stat.exists
```

---

## 5. Bảng So Sánh Toàn Diện: Module Chuyên Dụng vs Shell/Command

| Tiêu chí | Module Chuyên Dụng | Module `shell` / `command` |
| :--- | :--- | :--- |
| **Tính Lũy Đẳng** | **Mặc định có sẵn** (Tự kiểm tra trạng thái trước khi thay đổi). | **Mặc định KHÔNG** (luôn báo `changed`). Phải cấu hình thủ công (`creates`, `changed_when`). |
| **Hỗ trợ Check mode (`--check`)** | **Hỗ trợ tốt** (Mô phỏng thay đổi mà không làm thay đổi hệ thống thật). | **Bị BỎ QUA (`skipped`)** mặc định vì Ansible không đoán trước được lệnh shell. |
| **Hỗ trợ Diff mode (`--diff`)** | **Hỗ trợ chi tiết** (Hiển thị từng dòng cấu hình bị xóa/thêm với file text). | **KHÔNG hỗ trợ** (không thể diff được câu lệnh shell). |
| **Bắt & Xử lý lỗi** | Báo lỗi chi tiết, có mã lỗi và thông điệp chuẩn hóa của Ansible. | Chỉ dựa vào exit code (`rc != 0`) và in chuỗi `stderr` thô. |
| **Dữ liệu trả về (Data output)** | Trả về cấu trúc JSON / Python Dictionary phong phú (ví dụ: kích thước file, quyền, trạng thái service). | Chỉ trả về chuỗi text thô (`stdout`, `stderr`). |
| **Bảo mật (Security)** | Rất cao. Tham số được kiểm tra kiểu dữ liệu (type validation). | Tiềm ẩn nguy cơ **Shell Injection** nếu truyền biến người dùng vào chuỗi lệnh. |
| **Độ dễ đọc & Bảo trì** | Cú pháp YAML rõ ràng, chuẩn mực, dễ đọc và tự tài liệu hóa (self-documenting). | Khó đọc nếu chuỗi lệnh bash quá dài; phụ thuộc vào phiên bản bash của OS đích. |

### Khi nào VẪN NÊN dùng Shell?
Không nên cực đoan cho rằng *"dùng shell luôn luôn là xấu"*. Trong thực tế vận hành, Shell vẫn là công cụ cần thiết trong các trường hợp sau:
1. **Chưa có module hỗ trợ:** Khi phần mềm hoặc dịch vụ quá mới, chưa có Ansible Collection chính thức hỗ trợ.
2. **Chạy công cụ CLI nội bộ:** Hệ thống của công ty có script build/deploy riêng dạng binary/CLI đặc thù (`mycompany-cli build ...`).
3. **Bootstrap hạ tầng bằng `raw`:** Cài đặt gói `python3` ban đầu cho server Ubuntu/CentOS hoàn toàn mới.
4. **Gỡ rối và xử lý sự cố khẩn cấp:** Dùng lệnh ad-hoc (`ansible -m shell -a "killall ..."`) để xử lý sự cố tức thời.

---

## 6. Thực Hành Phân Tích Kết Quả Terminal

Cấu hình demo_shell_vs_module
```yaml
---
- name: "Playbook So Sánh: Module Chuyên Dụng vs Shell/Command & Kỹ Thuật Thuần Hóa"
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    base_dir: "/tmp/ansible_demo_task2"

  tasks:
    # -------------------------------------------------------------
    # PHẦN 1: Chuẩn bị thư mục thử nghiệm
    # -------------------------------------------------------------
    - name: "0. Chuẩn bị các thư mục làm việc"
      ansible.builtin.file:
        path: "{{ item }}"
        state: directory
        mode: "0755"
      loop:
        - "{{ base_dir }}/naive"
        - "{{ base_dir }}/guarded"
        - "{{ base_dir }}/module"
        - "{{ base_dir }}/conf"

    # -------------------------------------------------------------
    # PHẦN 2: "Cái bẫy" Redirect: command vs shell
    # -------------------------------------------------------------
    - name: "1A. [BẪY DEMO] Command với redirect >> (Không tạo được file!)"
      ansible.builtin.command:
        cmd: "echo 'Dòng này không vào file' >> {{ base_dir }}/command_trap.txt"
      register: cmd_trap_output

    - name: "1B. [SHELL ĐÚNG] Shell với redirect >> (Chạy qua /bin/sh thành công)"
      ansible.builtin.shell:
        cmd: "echo 'Dòng này vào file thật' >> {{ base_dir }}/shell_success.txt"

    # -------------------------------------------------------------
    # PHẦN 3: So sánh 3 cách giải nén file archive
    # -------------------------------------------------------------
    - name: "2A. [NAIVE SHELL] Bung file tar.gz (Không lũy đẳng - Luôn changed)"
      ansible.builtin.shell:
        cmd: "tar -xzf files/sample.tar.gz -C {{ base_dir }}/naive"

    - name: "2B. [GUARDED SHELL] Bung file dùng tham số 'creates' (Đã lũy đẳng)"
      ansible.builtin.shell:
        cmd: "tar -xzf files/sample.tar.gz -C {{ base_dir }}/guarded"
      args:
        creates: "{{ base_dir }}/guarded/sample.txt"

    - name: "2C. [MODULE CHUYÊN DỤNG] Bung file bằng unarchive (Tự động lũy đẳng)"
      ansible.builtin.unarchive:
        src: "files/sample.tar.gz"
        dest: "{{ base_dir }}/module"

    # -------------------------------------------------------------
    # PHẦN 4: Mẹo changed_when: false cho lệnh chỉ đọc (Read-only)
    # -------------------------------------------------------------
    - name: "3A. Lệnh đọc thông tin CPU không có changed_when (Báo changed sai)"
      ansible.builtin.command:
        cmd: "uname -m"

    - name: "3B. Lệnh đọc thông tin CPU có changed_when: false (Chuẩn ok)"
      ansible.builtin.command:
        cmd: "uname -m"
      changed_when: false

    # -------------------------------------------------------------
    # PHẦN 5: Pattern stat + register + when
    # -------------------------------------------------------------
    - name: "4A. Kiểm tra xem file cờ khởi tạo đã tồn tại chưa"
      ansible.builtin.stat:
        path: "{{ base_dir }}/app_initialized.flag"
      register: init_flag

    - name: "4B. Chỉ chạy lệnh khởi tạo nặng nếu file cờ CHƯA tồn tại"
      ansible.builtin.shell:
        cmd: |
          echo "Khởi tạo database/hệ thống lần đầu..."
          touch "{{ base_dir }}/app_initialized.flag"
      when: not init_flag.stat.exists

    # -------------------------------------------------------------
    # PHẦN 6: Module lineinfile kết hợp Handlers (Minh họa chuẩn IaC)
    # -------------------------------------------------------------
    - name: "5. [MODULE CHUYÊN DỤNG] Quản lý cấu hình với lineinfile + notify Handler"
      ansible.builtin.lineinfile:
        path: "{{ base_dir }}/conf/app.ini"
        create: true
        line: "max_connections = 100"
        state: present
        mode: "0644"
      notify: "Gia lap Handler khoi dong lai service"

  handlers:
    - name: "Gia lap Handler khoi dong lai service"
      ansible.builtin.debug:
        msg: "[HANDLER ĐƯỢC KÍCH HOẠT] File cấu hình có thay đổi thực sự -> Tiến hành restart service an toàn!"


```

### 6.1 Kiểm tra "Cái bẫy" Redirect: `command` vs `shell`

Trong playbook `demo_shell_vs_module.yml`, ta có 2 task đối chiếu trực tiếp (sử dụng biến `base_dir: "/tmp/ansible_demo_task2"`):

```yaml
- name: "1A. [BẪY DEMO] Command với redirect >> (Không tạo được file!)"
  ansible.builtin.command:
    cmd: "echo 'Dòng này không vào file' >> /tmp/ansible_demo_task2/command_trap.txt"

- name: "1B. [SHELL ĐÚNG] Shell với redirect >> (Chạy qua /bin/sh thành công)"
  ansible.builtin.shell:
    cmd: "echo 'Dòng này vào file thật' >> /tmp/ansible_demo_task2/shell_success.txt"
```

**Kiểm tra thực tế trong thư mục `/tmp/ansible_demo_task2/` sau khi chạy:**
```bash
$ ls -la /tmp/ansible_demo_task2/
total 144
drwxr-xr-x  6 hungj2020 hungj2020   4096 Oct  2 23:12 .
drwxrwxrwt 30 root      root      118784 Oct  2 23:12 ..
-rw-rw-r--  1 hungj2020 hungj2020      0 Oct  2 23:12 app_initialized.flag
drwxr-xr-x  2 hungj2020 hungj2020   4096 Oct  2 23:12 conf
drwxr-xr-x  2 hungj2020 hungj2020   4096 Oct  2 23:12 guarded
drwxr-xr-x  2 hungj2020 hungj2020   4096 Oct  2 23:12 module
drwxr-xr-x  2 hungj2020 hungj2020   4096 Oct  2 23:12 naive
-rw-rw-r--  1 hungj2020 hungj2020     28 Oct  2 23:12 shell_success.txt
```

**Phân tích:**
1. **Hoàn toàn KHÔNG có file `command_trap.txt`:** Do `command` không gọi `/bin/sh`, ký tự `>>` và đường dẫn file bị xem là đối số chuỗi truyền vào cho lệnh `echo`, chuỗi đó bị in thẳng ra terminal (`stdout`) thay vì tạo file chuyển hướng.
2. **File `shell_success.txt` được tạo với kích thước 28 byte:** Chuỗi ký tự `'Dòng này vào file thật\n'` được mã hóa UTF-8 tiếng Việt:
   - Các nguyên âm có dấu chiếm nhiều byte: `ò` (2 bytes), `à` (2 bytes), `à` (2 bytes), `ậ` (3 bytes) = 9 bytes.
   - 18 ký tự ASCII không dấu và khoảng trắng = 18 bytes.
   - 1 ký tự xuống dòng `\n` = 1 byte.
   - **Tổng cộng:** $9 + 18 + 1 = 28$ bytes chính xác tuyệt đối!

---

### 6.2 Lần chạy 1 vs Lần chạy 2 (Bản Log Terminal Đầy Đủ 100%)

#### A. Lần chạy 1 (Khởi tạo mới từ đầu):
Lệnh chạy: `ansible-playbook demo_shell_vs_module.yml`

```text
PLAY [Playbook So Sánh: Module Chuyên Dụng vs Shell/Command & Kỹ Thuật Thuần Hóa] ***

TASK [0. Chuẩn bị các thư mục làm việc] ****************************************
changed: [localhost] => (item=/tmp/ansible_demo_task2/naive)
changed: [localhost] => (item=/tmp/ansible_demo_task2/guarded)
changed: [localhost] => (item=/tmp/ansible_demo_task2/module)
changed: [localhost] => (item=/tmp/ansible_demo_task2/conf)

TASK [1A. [BẪY DEMO] Command với redirect >> (Không tạo được file!)] ***********
changed: [localhost]

TASK [1B. [SHELL ĐÚNG] Shell với redirect >> (Chạy qua /bin/sh thành công)] ****
changed: [localhost]

TASK [2A. [NAIVE SHELL] Bung file tar.gz (Không lũy đẳng - Luôn changed)] ******
changed: [localhost]

TASK [2B. [GUARDED SHELL] Bung file dùng tham số 'creates' (Đã lũy đẳng)] ******
changed: [localhost]

TASK [2C. [MODULE CHUYÊN DỤNG] Bung file bằng unarchive (Tự động lũy đẳng)] ****
changed: [localhost]

TASK [3A. Lệnh đọc thông tin CPU không có changed_when (Báo changed sai)] ******
changed: [localhost]

TASK [3B. Lệnh đọc thông tin CPU có changed_when: false (Chuẩn ok)] ************
ok: [localhost]

TASK [4A. Kiểm tra xem file cờ khởi tạo đã tồn tại chưa] ***********************
ok: [localhost]

TASK [4B. Chỉ chạy lệnh khởi tạo nặng nếu file cờ CHƯA tồn tại] ****************
changed: [localhost]

TASK [5. [MODULE CHUYÊN DỤNG] Quản lý cấu hình với lineinfile + notify Handler] ***
changed: [localhost]

RUNNING HANDLER [Gia lap Handler khoi dong lai service] ************************
ok: [localhost] => {
    "msg": "[HANDLER ĐƯỢC KÍCH HOẠT] File cấu hình có thay đổi thực sự -> Tiến hành restart service an toàn!"
}

PLAY RECAP *********************************************************************
localhost                  : ok=12   changed=9    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

> **Giải mã phép cộng PLAY RECAP Lần 1:**
> - **9 task `changed`:** Task 0 (tạo 4 thư mục), Task 1A (command), Task 1B (shell), Task 2A (tar naive), Task 2B (tar guarded), Task 2C (unarchive), Task 3A (uname), Task 4B (shell init), Task 5 (lineinfile).
> - **3 task `ok` không thay đổi:** Task 3B (uname có `changed_when: false`), Task 4A (stat kiểm tra cờ), RUNNING HANDLER (chỉ in debug thông báo).
> - **Tổng `ok`:** $9 + 3 = 12$ hoàn toàn khớp!

---

#### B. Lần chạy 2 (Giữ nguyên hiện trạng - Không xóa thư mục tạm):
Lệnh chạy: `ansible-playbook demo_shell_vs_module.yml`

```text
PLAY [Playbook So Sánh: Module Chuyên Dụng vs Shell/Command & Kỹ Thuật Thuần Hóa] ***

TASK [0. Chuẩn bị các thư mục làm việc] ****************************************
ok: [localhost] => (item=/tmp/ansible_demo_task2/naive)
ok: [localhost] => (item=/tmp/ansible_demo_task2/guarded)
ok: [localhost] => (item=/tmp/ansible_demo_task2/module)
ok: [localhost] => (item=/tmp/ansible_demo_task2/conf)

TASK [1A. [BẪY DEMO] Command với redirect >> (Không tạo được file!)] ***********
changed: [localhost]

TASK [1B. [SHELL ĐÚNG] Shell với redirect >> (Chạy qua /bin/sh thành công)] ****
changed: [localhost]

TASK [2A. [NAIVE SHELL] Bung file tar.gz (Không lũy đẳng - Luôn changed)] ******
changed: [localhost]

TASK [2B. [GUARDED SHELL] Bung file dùng tham số 'creates' (Đã lũy đẳng)] ******
ok: [localhost]

TASK [2C. [MODULE CHUYÊN DỤNG] Bung file bằng unarchive (Tự động lũy đẳng)] ****
ok: [localhost]

TASK [3A. Lệnh đọc thông tin CPU không có changed_when (Báo changed sai)] ******
changed: [localhost]

TASK [3B. Lệnh đọc thông tin CPU có changed_when: false (Chuẩn ok)] ************
ok: [localhost]

TASK [4A. Kiểm tra xem file cờ khởi tạo đã tồn tại chưa] ***********************
ok: [localhost]

TASK [4B. Chỉ chạy lệnh khởi tạo nặng nếu file cờ CHƯA tồn tại] ****************
skipping: [localhost]

TASK [5. [MODULE CHUYÊN DỤNG] Quản lý cấu hình với lineinfile + notify Handler] ***
ok: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=10   changed=4    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
```

> **Giải mã phép cộng PLAY RECAP Lần 2:**
> - **4 task vẫn `changed` (Không lũy đẳng):** Task 1A (command), Task 1B (shell), Task 2A (naive shell bung file), Task 3A (lệnh đọc uname không có changed_when).
> - **6 task đạt `ok` (Đã lũy đẳng):** Task 0 (thư mục đã có), Task 2B (shell có `creates:` thấy file đã có), Task 2C (module `unarchive` nhận biết file đã bung), Task 3B (nhờ `changed_when: false`), Task 4A (stat), Task 5 (`lineinfile` thấy dòng cấu hình đã có sẵn).
> - **1 task `skipped`:** Task 4B (nhờ pattern `stat` + `when: not init_flag.stat.exists` bỏ qua).
> - **HANDLER KHÔNG BỊ GỌI LẠI:** Vì Task 5 báo `ok` (cấu hình không đổi), handler tự động không chạy.
> - **Tổng `ok`:** $4 (\text{changed}) + 6 (\text{không đổi}) = 10$ hoàn toàn khớp!

---

### 6.3 Kết Luận Thực Nghiệm

| Nhóm Giải Pháp | Đại Diện | Kết Quả Lần 1 | Kết Quả Lần 2 | Đánh Giá Thực Tế |
| :--- | :--- | :---: | :---: | :--- |
| **Shell Ngây Thơ (Naive Shell)** | Task 2A, Task 3A | `changed` | `changed` | **Tệ:** Luôn làm nhiễu báo cáo PLAY RECAP và không an toàn cho CI/CD. |
| **Shell Thuần Hóa (Guarded Shell)** | Task 2B (`creates`), Task 4B (`stat+when`) | `changed` | **`ok` / `skipping`** | **Tốt:** Giải pháp bắt buộc khi không có module chuyên dụng. |
| **Module Chuyên Dụng (Dedicated)** | Task 2C (`unarchive`), Task 5 (`lineinfile`) | `changed` | **`ok`** | **Xuất sắc:** Lũy đẳng tự nhiên, code ngắn gọn, tích hợp mượt mà với Handlers. |

---

## 7. Workflow Trực Quan Các Quá Trình
### Workflow 1: Cây Quyết Định Lựa Chọn Module Thực Thi

```text
                           [Bắt đầu tác vụ tự động hóa]
                                         │
                                         ▼
                      Đã có Module chuyên dụng hỗ trợ?
                     (copy, template, apt, systemd...)
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼ CÓ                                        ▼ KHÔNG
       ┌────────────────────────┐                   Máy đích đã cài Python chưa?
       │  ƯU TIÊN HÀNG ĐẦU:     │                              │
       │  Dùng Module Chuyên    │             ┌────────────────┴────────────────┐
       │  Dụng                  │             ▼ CHƯA                            ▼ ĐÃ CÓ
       │  (Lũy đẳng tự nhiên,   │     Cần chạy lệnh đơn hay             Cần Pipe '|', Redirect '>',
       │   an toàn, hỗ trợ      │     File script dài có sẵn?           Wildcard '*' hay Biến Shell?
       │   check mode)          │             │                                 │
       └────────────────────────┘     ┌───────┴───────┐                 ┌───────┴───────┐
                                      ▼ LỆNH ĐƠN      ▼ FILE SCRIPT     ▼ KHÔNG         ▼ CÓ
                                  ┌───────┐       ┌────────┐        ┌─────────┐     ┌─────────┐
                                  │  raw  │       │ script │        │ command │     │  shell  │
                                  └───────┘       └────────┘        └─────────┘     └─────────┘
                                  (Bootstrap       (Chạy file       (An toàn,       (Thuần hóa
                                   qua SSH)         từ xa)           chống Shell     bằng creates,
                                                                     Injection)      changed_when)
```

---

### Workflow 2: So Sánh Cơ Chế Hoạt Động Giữa 3 Cách Viết

```text
┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
│  1. Module Chuyên Dụng  │  │   2. Shell Ngây Thơ     │  │   3. Shell Thuần Hóa    │
│     (unarchive, copy)   │  │   (tar, echo >> file)   │  │    (creates: file)      │
└────────────┬────────────┘  └────────────┬────────────┘  └────────────┬────────────┘
             │                            │                            │
             ▼                            ▼                            ▼
     Kiểm tra hiện trạng             Ansible gọi              Kiểm tra file chỉ định
     hệ thống trước                 /bin/sh -c                trong tham số creates:
             │                            │                            │
     ┌───────┴───────┐                    ▼                    ┌───────┴───────┐
     ▼               ▼            Lệnh chạy bên trong          ▼               ▼
  ĐÃ KHỚP        CHƯA KHỚP        "Hộp đen" (Black box)      ĐÃ TỒN TẠI       CHƯA CÓ
     │               │                    │                    │               │
     ▼               ▼                    ▼                    ▼               ▼
Giữ nguyên     Chỉ thay đổi         Luôn ghi đè lại        Hủy lệnh shell   Chạy lệnh shell
hệ thống       phần sai lệch        hệ thống                   │               │
     │               │                    │                    ▼               ▼
     ▼               ▼                    ▼                Báo trạng thái  Báo trạng thái
Báo trạng thái Báo trạng thái       LUÔN BÁO TRẠNG THÁI          "ok"          "changed"
    "ok"          "changed"             "changed"
```

---

### Workflow 3: Mô Hình "Trinh Sát & Cắm Cờ" (`stat` + `register` + `when`) Cho Tác Vụ Nặng

```text
                           [Bắt đầu tác vụ khởi tạo]
                                       │
                                       ▼
                   TASK 4A: Cử module "stat" đi trinh sát
                (Tìm xem file app_initialized.flag có chưa?)
                                       │
                                       ▼
                     Lưu kết quả vào biến sổ tay: "init_flag"
                                       │
                                       ▼
                   TASK 4B: Mệnh đề điều kiện kiểm tra
                     "when: not init_flag.stat.exists"
                                       │
                   ┌───────────────────┴───────────────────┐
                   ▼                                       ▼
             [ĐÃ CÓ CỜ]                               [CHƯA CÓ CỜ]
       (Hệ thống đã cài rồi)                      (Hệ thống mới tinh)
                   │                                       │
                   ▼                                       ▼
        Ansible tự động BỎ QUA                    1. Chạy script cài đặt nặng
        (Trạng thái SKIPPING)                     2. Cắm cờ hoàn thành:
        -> Bảo vệ dữ liệu cũ,                        touch app_initialized.flag
           không bị chạy đè!                      3. Báo trạng thái "changed"
                   │                                       │
                   └───────────────────┬───────────────────┘
                                       ▼
                                [Hoàn tất Play]
```

---

### Workflow 4: Cơ Chế Bảo Vệ Dịch Vụ Của Handlers (`lineinfile` + `notify`)

```text
                        TASK 5: Sửa cấu hình (lineinfile)
                                       │
                                       ▼
                     Quét Regex tìm dòng cấu hình trong file
                                       │
                   ┌───────────────────┴───────────────────┐
                   ▼ ĐÃ CÓ SẴN (Lần 2)                     ▼ CHƯA CÓ HOẶC SAI (Lần 1)
       ┌────────────────────────┐              ┌────────────────────────┐
       │ 1. Báo trạng thái "ok" │              │ 1. Chèn/sửa dòng mới   │
       │ 2. KHÔNG gửi tín hiệu  │              │ 2. Báo trạng thái      │
       │    notify              │              │    "changed"           │
       └───────────┬────────────┘              │ 3. Gửi tín hiệu        │
                   │                           │    "notify"            │
                   │                           └───────────┬────────────┘
                   │                                       │
                   ▼                                       ▼
       ┌────────────────────────┐              ┌────────────────────────┐
       │ Handler IM LẶNG        │              │ Handler KÍCH HOẠT      │
       │ Service KHÔNG restart  │              │ Restart Service an     │
       │ -> Không gián đoạn web!│              │ toàn DUY NHẤT 1 LẦN    │
       └────────────────────────┘              └────────────────────────┘
```



