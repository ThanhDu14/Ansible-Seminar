# Idempotence Trong Ansible

---

## 1. Định Nghĩa Idempotence 

### 1.1 Khái niệm toán học
Trong toán học, một phép toán $f$ được gọi là **lũy đẳng (idempotent)** nếu áp dụng nó nhiều lần cho cùng một đầu vào thì kết quả không bao giờ thay đổi sau lần đầu tiên:
$$f(f(x)) = f(x)$$

*Ví dụ:* 
- Hàm lấy giá trị tuyệt đối $|x|$: $|-5| = 5$, lấy tiếp $|5| = 5$.
- Phép nhân với số 1: $x \times 1 = x$.

### 1.2 Áp dụng vào Quản trị hệ thống và Ansible (IaC)
Trong quản trị cấu hình tự động Infrastructure as Code - IaC:
> **Một tác vụ (Task/Playbook) được gọi là Lũy đẳng Idempotent nếu việc thực thi nó 1 lần, 10 lần hay 100 lần trên cùng một máy chủ đều đưa hệ thống về đúng cùng một trạng thái mong muốn Desired State mà không gây ra tác dụng phụ ngoài ý muốn.**

---

## 2. Ví Dụ Trực Quan: Đời Thường & IT

### 2.1 Ví dụ đời thường
| Tác vụ | Lũy đẳng  | Không lũy đẳng  | Giải thích |
| :--- | :--- | :--- | :--- |
| **Thang máy** | Bấm nút số **5** | Bấm nút chuông báo động | Bấm nút tầng 5 một lần đèn sáng; bấm thêm 10 lần nữa thang máy vẫn đến tầng 5. Nút chuông báo động bấm bao nhiêu lần sẽ kêu bấy nhiêu lần. |
| **Bật/Tắt đèn** | Công tắc có vị trí cố định **ON** | Nút bấm chuyển trạng thái (**Toggle Switch**) | Bật công tắc sang ON: nếu đèn đang sáng, gạt tiếp vẫn sáng. Nút Toggle: mỗi lần bấm sẽ đảo ngược trạng thái (sáng $\rightarrow$ tắt $\rightarrow$ sáng). |
| **Máy điều hòa** | Bấm đặt nhiệt độ cố định **$25^\circ C$** | Bấm nút giảm **$1^\circ C$** | Đặt $25^\circ C$: chạy bao nhiêu lần nhiệt độ vẫn hướng về $25^\circ C$. Nút giảm $1^\circ C$: bấm liên tục sẽ làm phòng lạnh cóng. |

### 2.2 Ví dụ trong Quản trị hệ thống
| Tác vụ | Câu lệnh Lũy đẳng | Câu lệnh Không lũy đẳng | Hệ quả khi chạy lại lần 2 |
| :--- | :--- | :--- | :--- |
| **Tạo thư mục** | `mkdir -p /data/backup` | `mkdir /data/backup` | Lệnh `mkdir` thường văng lỗi: `File exists` (Exit code 1). Lệnh có `-p` sẽ bỏ qua nếu thư mục đã có. |
| **Ghi file** | `echo "PORT=8080" > app.env` | `echo "PORT=8080" >> app.env` | Toán tử `>` ghi đè nội dung nhất quán. Toán tử `>>` nối đuôi, khiến file phình to dần và trùng lặp cấu hình sau mỗi lần chạy. |
| **Quản lý User** | `ansible.builtin.user: name=deploy state=present` | `useradd deploy` | Lệnh `useradd` chạy lần 2 văng lỗi: `useradd: user 'deploy' already exists` (Exit code 9). Module của Ansible kiểm tra trước, nếu user đã có sẽ giữ nguyên. |
| **Biến số** | `flag=true` | `count=$((count + 1))` | Phép gán giá trị giữ nguyên trạng thái; phép cộng dồn biến đổi giá trị liên tục. |
| **Cơ sở dữ liệu** | `CREATE TABLE IF NOT EXISTS users (...)` | `CREATE TABLE users (...)` | `CREATE TABLE` không kiểm tra sẽ gây crash script SQL ở lần chạy thứ 2. |

---

## 3. Vì Sao Idempotence Là Nguyên Lý Sống Còn Trong Ansible?

### 3.1 Tư duy Khai báo vs Tư duy Mệnh lệnh

- **Mệnh lệnh (Imperative - Shell Script truyền thống):**
  - Trả lời câu hỏi: *"Làm như thế nào? (How)"*
  - Hướng dẫn máy tính từng bước cụ thể: Bước 1 tạo folder, Bước 2 tải file, Bước 3 sửa dòng 5...
  - **Nhược điểm:** Nếu hệ thống đã hoàn thành bước 1 mà gặp lỗi ở bước 2, khi chạy lại script sẽ gặp lỗi ngay từ bước 1 (như lỗi thư mục đã tồn tại).
- **Khai báo (Declarative / Desired State - Ansible):**
  - Trả lời câu hỏi: *"Trạng thái cuối cùng cần đạt là gì? (What)"*
  - Bạn chỉ cần mô tả: *"Tôi muốn thư mục `/data` tồn tại với quyền `0755` và service `nginx` ở trạng thái `running`"*.
  - **Cách Ansible xử lý:**
    1. Kiểm tra trạng thái hiện tại của hệ thống.
    2. So sánh với trạng thái khai báo trong Playbook.
    3. Nếu **đã đúng** $\rightarrow$ Bỏ qua, không làm gì cả (`ok`).
    4. Nếu **chưa đúng** $\rightarrow$ Chỉ thực hiện đúng phần thay đổi cần thiết (`changed`).

```text
[Trạng thái hiện tại] ───(So sánh)─── [Desired State trong Playbook]
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
            Đã khớp                        Chưa khớp
      (Không làm gì - ok)            (Thay đổi vừa đủ - changed)
```

### 3.2 Lợi ích thực tiễn trong vận hành
1. **Khả năng tự sửa lỗi lệch cấu hình:** Nếu ai đó lỡ tay đổi quyền file trên server, chỉ cần chạy lại playbook, Ansible sẽ tự phát hiện và sửa lại đúng chuẩn.
2. **An toàn khi chạy lại:** Playbook đang chạy dở bị rớt mạng, bạn chỉ việc gõ lệnh chạy lại mà không sợ tạo ra dữ liệu rác hay lỗi trùng lặp.
3. **Tích hợp CI/CD tự động:** Pipeline triển khai có thể chạy định kỳ mỗi giờ để đảm bảo 100 cụm máy chủ luôn đồng nhất cấu hình.

---

## 4. Các Trạng Thái Thực Thi & Cách Đọc PLAY RECAP

Khi thực thi Playbook, Ansible sẽ báo cáo chi tiết từng task và bảng tổng kết **PLAY RECAP** ở cuối phiên chạy.

### 4.1 Ý nghĩa chi tiết từng chỉ số

| Chỉ số | Ý nghĩa | Trạng thái có can thiệp hệ thống không? |
| :--- | :--- | :--- |
| **`ok`** | **Tổng số task thành công** trên host đó. Bao gồm cả các task giữ nguyên trạng thái, các task vừa thay đổi (`changed`), và task `Gathering Facts`. | Tùy task |
| **`changed`** | Số task phát hiện có sự sai lệch so với Desired State và **đã thực hiện thay đổi** trên host. | **CÓ** |
| **`skipped`** | Số task bị bỏ qua do điều kiện `when:` trả về `false`. | KHÔNG |
| **`failed`** | Số task gặp lỗi thực thi (exit code khác 0). Mặc định Ansible sẽ **dừng ngay** Playbook trên host bị lỗi. | Gặp lỗi |
| **`unreachable`** | Không thể thiết lập kết nối tới host (sai IP, timeout, rớt mạng, từ chối SSH key). Ansible dừng ngay mọi task tiếp theo trên host này. | Không kết nối được |
| **`ignored`** | Số task bị lỗi nhưng có khai báo `ignore_errors: true` nên playbook vẫn tiếp tục chạy tiếp. | Lỗi nhưng bỏ qua |
| **`rescued`** | Số task lỗi được xử lý và cứu nguy thành công trong khối `block - rescue`. | Đã khắc phục lỗi |

> **Công thức cần nhớ:** 
> - Cột `ok` là tổng số tác vụ đã hoàn thành tốt (bao gồm cả các task được đánh dấu `changed`).
> - Task `Gathering Facts` ngầm định ở đầu mỗi Play được tính là **1 `ok`**.
> - Vì vậy, nếu Playbook có 2 task thay đổi và 1 task facts: terminal sẽ báo `ok=3 changed=2`.

---

## 5. Cờ Kiểm Tra An Toàn `--check` Và `--diff` cùng giới hạn cốt lõi

### 5.1 Chế độ Dry-run (`--check`) và Xem sai khác (`--diff`)
- **`--check` (Check Mode / Dry-Run):** Ansible chỉ mô phỏng việc thực thi mà không áp bất kỳ thay đổi nào lên hệ thống thật. Nó dự đoán xem nếu chạy thật thì những task nào sẽ báo `changed`.
- **`--diff` (Diff Mode):** Hiển thị chi tiết dòng bị xóa/thêm/thay thế (tương tự `git diff`), đặc biệt hữu dụng khi quản lý file cấu hình qua `copy`, `template`, `lineinfile`.
- **Kết hợp:** `ansible-playbook playbook.yml -C -D` (viết tắt của `--check --diff`) để review kỹ trước khi áp dụng vào môi trường Production.

### 5.2 Ba Giới hạn cốt lõi của Check Mode
1. **Module `command` và `shell` mặc định bị `skipped`:**
   Vì Ansible coi lệnh shell là một "hộp đen", Ansible không thể đoán trước câu lệnh shell của bạn sẽ làm gì nếu không thực sự chạy nó. Do đó, trong check mode, Ansible buộc phải bỏ qua task shell để đảm bảo an toàn.
2. **`--diff` vô tác dụng với `command`/`shell`:**
   Ansible chỉ diff được nội dung văn bản khi dùng các module quản lý file chuyên dụng như `copy`, `template`, `lineinfile`. Với `command`/`shell`, Ansible không thể hiển thị diff trước và sau.
3. **Nguy cơ lỗi dây chuyền với biến `register`:**
   Nếu Task B phụ thuộc vào một biến được tạo từ kết quả `register` của Task A, nhưng Task A bị Check Mode bỏ qua hoặc không ghi dữ liệu thật, thì Task B có thể bị crash khi đánh giá điều kiện `when`.

---

## 6. Bảng Tổng Hợp Ví Dụ: Idempotent vs Không Idempotent

| Ngữ cảnh | Thao tác | Cách viết Lũy Đẳng | Cách viết Không Lũy Đẳng |
| :--- | :--- | :--- | :--- |
| **Tạo thư mục** | Đảm bảo thư mục `/var/www/site` tồn tại | `ansible.builtin.file:`<br>`  path: /var/www/site`<br>`  state: directory` | `ansible.builtin.shell:`<br>`  cmd: mkdir /var/www/site`<br>*(Lần 2 sẽ báo lỗi directory exists)* |
| **Ghi cấu hình** | Cập nhật tham số vào file config | `ansible.builtin.lineinfile:`<br>`  path: /etc/sysctl.conf`<br>`  line: "net.ipv4.ip_forward = 1"`<br>`  state: present` | `ansible.builtin.shell:`<br>`  cmd: 'echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf'`<br>*(Chạy bao nhiêu lần thêm bấy nhiêu dòng trùng lặp)* |
| **Quản lý Package**| Cài đặt web server Nginx | `ansible.builtin.apt:`<br>`  name: nginx`<br>`  state: present` | `ansible.builtin.shell:`<br>`  cmd: apt-get install -y nginx`<br>*(Luôn chạy apt-get và luôn báo changed dù gói đã có)* |
| **Tải & Giải nén** | Bung gói mã nguồn | `ansible.builtin.unarchive:`<br>`  src: code.tar.gz`<br>`  dest: /opt/app` | `ansible.builtin.shell:`<br>`  cmd: tar -xzf code.tar.gz -C /opt/app`<br>*(Lần nào cũng ghi đè lại toàn bộ và báo changed)* |

---

## 7. Thực Hành & Phân Tích Kết Quả Terminal 

Cấu hình file demo_idempotent.yml
```bash
---
- name: "Play 1: Minh họa Idempotence và các trạng thái OK, CHANGED, SKIPPED, FAILED/IGNORED"
  hosts: local
  gather_facts: true
  tasks:
    - name: "1. [Lũy đẳng] Tạo thư mục ứng dụng (file module)"
      ansible.builtin.file:
        path: "/tmp/ansible_demo_idempotent"
        state: directory
        mode: "0755"

    - name: "2. [Lũy đẳng] Quản lý nội dung file cấu hình (copy module)"
      ansible.builtin.copy:
        dest: "/tmp/ansible_demo_idempotent/app.conf"
        content: |
          # File cấu hình mẫu cho Seminar Ansible
          server_name=demo.ansible.local
          port=8080
          environment=seminar
        mode: "0644"

    - name: "3. [KHÔNG Lũy đẳng] Shell ghi nối tiếp file log (shell module)"
      ansible.builtin.shell:
        cmd: 'echo "Execution timestamp: $(date)" >> /tmp/ansible_demo_idempotent/access.log'

    - name: "4. [SKIPPED] Task có điều kiện không thỏa mãn (when)"
      ansible.builtin.debug:
        msg: "Thông báo này chỉ xuất hiện trên hệ điều hành RedHat/CentOS"
      when: ansible_facts['os_family'] == "RedHat"

    - name: "5. [FAILED -> IGNORED] Lệnh trả về exit code khác 0 kèm ignore_errors"
      ansible.builtin.command:
        cmd: "/bin/false"
      ignore_errors: true

- name: "Play 2: Minh họa trạng thái UNREACHABLE trên máy đích không thể kết nối"
  hosts: ghost
  gather_facts: false
  tasks:
    - name: "6. [UNREACHABLE] Thử kết nối tới IP không tồn tại trong mạng"
      ansible.builtin.ping:

```

Cấu hình inventory.ini
```bash
# Inventory phục vụ Seminar Ansible - Demo Idempotence
[local]
localhost ansible_connection=local ansible_python_interpreter=/home/hungj2020/.venv/bin/python

[ghost]
ghost_server ansible_host=192.0.2.1 ansible_connection=ssh ansible_ssh_common_args='-o ConnectTimeout=2 -o ConnectionAttempts=1'

```

### 7.1 Lần chạy thứ nhất với Hạ tầng mới - Chưa cấu hình
Lệnh thực hiện:
```bash
ansible-playbook -i inventory.ini demo_idempotence.yml
```
**Kết quả terminal thực tế:**
```text
PLAY [Play 1: Minh họa Idempotence và các trạng thái OK, CHANGED, SKIPPED, FAILED/IGNORED] ***

TASK [Gathering Facts] *********************************************************
ok: [localhost]

TASK [1. [Lũy đẳng] Tạo thư mục ứng dụng (file module)] ************************
changed: [localhost]

TASK [2. [Lũy đẳng] Quản lý nội dung file cấu hình (copy module)] **************
changed: [localhost]

TASK [3. [KHÔNG Lũy đẳng] Shell ghi nối tiếp file log (shell module)] **********
changed: [localhost]

TASK [4. [SKIPPED] Task có điều kiện không thỏa mãn (when)] ********************
skipping: [localhost]

TASK [5. [FAILED -> IGNORED] Lệnh trả về exit code khác 0 kèm ignore_errors] ***
fatal: [localhost]: FAILED! => {"changed": true, "cmd": ["/bin/false"], "rc": 1, ...}
...ignoring

PLAY [Play 2: Minh họa trạng thái UNREACHABLE trên máy đích không thể kết nối] ***

TASK [6. [UNREACHABLE] Thử kết nối tới IP không tồn tại trong mạng] ************
fatal: [ghost_server]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh...", "unreachable": true}

PLAY RECAP *********************************************************************
ghost_server               : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
localhost                  : ok=5    changed=4    unreachable=0    failed=0    skipped=1    rescued=0    ignored=1   
```
**Phân tích Lần 1:**
- `ghost_server`: Không thể kết nối SSH tới IP `192.0.2.1` $\rightarrow$ Thể hiện rõ trạng thái **`unreachable=1`**.
  > **Lưu ý kỹ thuật về `gather_facts: false` ở Play 2:**
  > Mặc định trong Ansible, mỗi Play đều tự động chạy task `Gathering Facts` đầu tiên để thu thập thông tin host. Nếu Play 2 không tắt `gather_facts: false`, Ansible sẽ cố kết nối SSH và văng lỗi `UNREACHABLE` **ngay tại bước gom facts**, khiến Playbook dừng trước khi kịp đến Task 6! Do đó, việc chủ động cấu hình `gather_facts: false` là kỹ thuật cần thiết để bỏ qua gom facts và cho phép chạy thẳng vào task kiểm tra kết nối cụ thể (`ping`).
- `localhost`:
  - `ok=5`: Bao gồm Facts (1) + Task 1 (1) + Task 2 (1) + Task 3 (1) + Task 5 (được ignore xem như xong 1).
  - `changed=4`: Thư mục mới tạo, file mới tạo, lệnh shell đã chạy, và lệnh command báo changed.
  - `skipped=1`: Task 4 kiểm tra điều kiện `os_family == 'RedHat'` bị false trên Ubuntu.
  - `ignored=1`: Task 5 chạy `/bin/false` lỗi nhưng có `ignore_errors: true`.

---

### 7.2 Lần chạy thứ hai với hạ tầng đã có sẵn sau lần chạy thứ nhất
Chạy lại cùng câu lệnh trên (thực thi trên cả 2 host `local` và `ghost`):
```bash
ansible-playbook -i inventory.ini demo_idempotence.yml
```

**Kết quả terminal thực tế:**
```text
PLAY [Play 1: Minh họa Idempotence và các trạng thái OK, CHANGED, SKIPPED, FAILED/IGNORED] ***

TASK [Gathering Facts] *********************************************************
ok: [localhost]

TASK [1. [Lũy đẳng] Tạo thư mục ứng dụng (file module)] ************************
ok: [localhost]

TASK [2. [Lũy đẳng] Quản lý nội dung file cấu hình (copy module)] **************
ok: [localhost]

TASK [3. [KHÔNG Lũy đẳng] Shell ghi nối tiếp file log (shell module)] **********
changed: [localhost]

TASK [4. [SKIPPED] Task có điều kiện không thỏa mãn (when)] ********************
skipping: [localhost]

TASK [5. [FAILED -> IGNORED] Lệnh trả về exit code khác 0 kèm ignore_errors] ***
fatal: [localhost]: FAILED! => {"changed": true, "cmd": ["/bin/false"], "rc": 1, ...}
...ignoring

PLAY [Play 2: Minh họa trạng thái UNREACHABLE trên máy đích không thể kết nối] ***

TASK [6. [UNREACHABLE] Thử kết nối tới IP không tồn tại trong mạng] ************
fatal: [ghost_server]: UNREACHABLE! => {"changed": false, "msg": "Task failed: Failed to connect to the host via ssh...", "unreachable": true}

PLAY RECAP *********************************************************************
ghost_server               : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
localhost                  : ok=5    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=1   
```
**Phân tích sự khác biệt (Lũy đẳng vs Không lũy đẳng):**
- **Task 1 `file` và Task 2 `copy` đã chuyển từ `changed` sang `ok`!** Vì thư mục đã có quyền `0755` và file đã có nội dung khớp 100% với Desired State, Ansible không chạm vào hệ thống nữa. Đây chính là **Tính lũy đẳng**.
- **Task 3 `shell` vẫn tiếp tục báo `changed`!** Lệnh shell không có cơ chế kiểm tra trạng thái nên mỗi lần chạy nó lại ghi thêm một dòng vào file log, gây thay đổi liên tục.
- **`ghost_server` vẫn giữ nguyên trạng thái `unreachable=1`:** Vì Play 2 vẫn chạy qua host này trong inventory chung.

---

### 7.3 Chạy thử nghiệm `--check` và `--diff`
Khi cố tình chèn thêm một dòng `port=9090` vào file cấu hình trên server, sau đó chạy lệnh kiểm tra trước:
```bash
ansible-playbook -i inventory.ini demo_idempotence.yml --limit local --check --diff
```
**Kết quả terminal thực tế:**
```diff
TASK [1. [Lũy đẳng] Tạo thư mục ứng dụng (file module)] ************************
ok: [localhost]

TASK [2. [Lũy đẳng] Quản lý nội dung file cấu hình (copy module)] **************
--- before: /tmp/ansible_demo_idempotent/app.conf
+++ after: /tmp/ansible_demo_idempotent/app.conf
@@ -2,4 +2,3 @@
 server_name=demo.ansible.local
 port=8080
 environment=seminar
-port=9090

changed: [localhost]

TASK [3. [KHÔNG Lũy đẳng] Shell ghi nối tiếp file log (shell module)] **********
skipping: [localhost]

TASK [5. [FAILED -> IGNORED] Lệnh trả về exit code khác 0 kèm ignore_errors] ***
skipping: [localhost]
```
**Nhận xét:**
1. `--diff` hiển thị chính xác dòng `-port=9090` sẽ bị loại bỏ để đưa file về đúng Desired State của Playbook.
2. `--check` tự động **`skipping` Task 3 và Task 5** với các module `shell`/`command`, minh chứng cho giới hạn của check mode đối với lệnh shell.

