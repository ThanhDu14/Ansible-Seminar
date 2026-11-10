# Lệnh demo — Terraform dựng máy, Ansible cấu hình

> Mọi lệnh đều chạy từ thư mục gốc repo `Ansible-Seminar/` (trừ khi có `cd`).
> Host trong inventory do Terraform sinh có tên `web-1`, `web-2`, `web-3`.

---

## 0. Chuẩn bị (làm 1 lần, trước ngày seminar)

```bash
# AWS credentials
aws configure
aws sts get-caller-identity          # kiểm tra đã đăng nhập đúng tài khoản

# SSH key: dùng Key Pair có sẵn trên AWS (ansible-controller) + file .pem
aws ec2 describe-key-pairs --key-names ansible-controller --region ap-southeast-1
chmod 400 ~/Downloads/ansible-controller.pem

# Khai báo IP được phép SSH + init môi trường demo
cd demo/terraform/environments/demo
cp terraform.tfvars.example terraform.tfvars
curl -s ifconfig.me                  # lấy IP, sửa admin_cidrs = ["<IP>/32"] trong terraform.tfvars
terraform init
```

---

## 1. Trước giờ demo (~15 phút trước, KHÔNG làm trên sân khấu)

```bash
cd demo/terraform/environments/demo

# IP có thể đổi nếu đổi mạng (wifi trường) → cập nhật admin_cidrs nếu cần
curl -s ifconfig.me

terraform plan
terraform apply                      # ~2-3 phút, gõ yes

# Kiểm tra máy đã sẵn sàng (chỉ ping, KHÔNG chạy playbook)
cd ../../../ansible
ansible webservers -i inventory-terraform -m ping

# Xoá vault cũ để tạo lại trực tiếp trên sân khấu (Demo 2)
rm -f roles/nginx/vars/vault.yml .vault_pass
export EDITOR=nano                   # ansible-vault create sẽ mở nano thay vì vi
```

Mở sẵn 3 tab terminal:

| Tab | Thư mục |
|---|---|
| 1 — Terraform | `demo/terraform/environments/demo` |
| 2 — Ansible | `demo/ansible` |
| 3 — Kiểm tra | `demo/ansible` (dùng cho `curl` / `cat`) |

---

## Demo 0 — Terraform dựng máy (~1,5 phút)

**Tab 1** (`demo/terraform/environments/demo`):

```bash
terraform output web_public_ips      # 3 máy EC2 Terraform đã tạo
terraform output web_urls
cat ../../../ansible/inventory-terraform   # inventory Terraform tự sinh
```

> Nói: "Terraform lo **tạo máy**, Ansible lo **cấu hình bên trong máy**. Inventory được sinh tự động, không ai gõ IP bằng tay."

---

## Demo 1 — Kiểm tra kết nối (~1 phút)

**Tab 2** (`demo/ansible`):

```bash
# Thấy "pong" = SSH key + Python OK, không cần cài agent
ansible webservers -i inventory-terraform -m ping

# Xem cấu trúc role (lúc này chưa có vars/vault.yml)
tree roles/nginx                     # hoặc: find roles/nginx -type f
```

---

## Demo 2 — Tạo Vault → chạy playbook Nginx → curl (~4 phút)

**Tab 2** — tạo secret bằng Vault:

```bash
# Nhập mật khẩu Vault 2 lần, nano mở ra → gõ nội dung bên dưới, Ctrl+O, Enter, Ctrl+X
ansible-vault create roles/nginx/vars/vault.yml
```

Nội dung gõ trong nano:

```yaml
vault_admin_password: "admin"
```

```bash
# File nằm trong repo nhưng chỉ thấy $ANSIBLE_VAULT;1.1;AES256 + chuỗi mã hoá
cat roles/nginx/vars/vault.yml

# Chạy KHÔNG có mật khẩu → lỗi ngay khi nạp vars_files, CHƯA đụng tới server
ansible-playbook -i inventory-terraform site.yml

# Chạy có mật khẩu → deploy lần 1: nhiều task "changed", handler Restart Nginx chạy
# Task htpasswd hiện "censored" nhờ no_log → mật khẩu không lộ ra output
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

**Tab 3** — curl thử:

```bash
curl http://<IP-web-1>                                     # trang chào mừng (công khai)
curl -i http://<IP-web-1>/admin/                           # 401 Unauthorized
curl -u admin:<mật-khẩu-admin> http://<IP-web-1>/admin/    # 200 — vào được

# Trên server chỉ có HASH, không có mật khẩu gốc
ansible web-1 -i inventory-terraform -b -a "cat /etc/nginx/.htpasswd"
```

Mở các URL trong `terraform output web_urls` trên trình duyệt (thử `/admin/` → trình duyệt hỏi mật khẩu).

> Nói: "Secret được mã hoá ngay khi tạo, commit lên Git vẫn an toàn. Chỉ lúc chạy trên máy control mới giải mã, và xuống server chỉ còn hash."

---

## Demo 3 — Idempotent & Handler (~2 phút)

**Tab 2**:

```bash
# Chạy lại y hệt: toàn "ok", PLAY RECAP changed=0,
# handler KHÔNG chạy vì config không đổi
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

Đổi biến `server_name` (KHÔNG đổi `http_port` — security group chỉ mở cổng 80/443):

```bash
sed -i 's/demo.ansible.lab/seminar.ansible.lab/' roles/nginx/defaults/main.yml
cat roles/nginx/defaults/main.yml

# Xem trước thay đổi, chưa áp dụng (Slide 20)
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass --check --diff

# Chạy thật: chỉ task template + /etc/hosts "changed", handler restart đúng 1 lần mỗi máy
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

**Tab 3** — xác nhận config trên máy đã đổi:

```bash
ansible webservers -i inventory-terraform -a "grep server_name /etc/nginx/sites-available/default"

# /etc/hosts: dòng cũ được SỬA thành tên mới (không thêm dòng trùng) → curl theo tên chạy được
ansible webservers -i inventory-terraform -a "grep 'managed by ansible' /etc/hosts"
ansible webservers -i inventory-terraform -a "curl -s -o /dev/null -w '%{http_code}' http://seminar.ansible.lab"
```

---

## Demo 4 — Shell vs `lineinfile` (~1,5 phút)

Playbook riêng `idempotency-demo.yml` (không cần vault): 1 task `shell` append, 1 task `lineinfile`.

**Tab 2** — chạy 3 lần liên tiếp:

```bash
# Lần nào task [NON-IDEMPOTENT] cũng "changed"; task [IDEMPOTENT] chỉ "changed" ở lần 1
for i in 1 2 3; do ansible-playbook -i inventory-terraform idempotency-demo.yml; done
```

**Tab 3**:

```bash
# File ghi bằng shell (echo >>): nhiều dòng trùng
ansible web-1 -i inventory-terraform -a "cat /tmp/idempotency_demo.txt"

# File ghi bằng lineinfile: chỉ 1 dòng
ansible web-1 -i inventory-terraform -a "cat /tmp/idempotency_demo_fixed.txt"

# Đếm số dòng 2 file trên cả 3 máy
ansible webservers -i inventory-terraform -a "wc -l /tmp/idempotency_demo.txt /tmp/idempotency_demo_fixed.txt"
```

> Nói: "Đây là khác biệt giữa 'chạy lệnh' và 'khai báo trạng thái'."

---

## Demo phụ — Scale thêm máy (chỉ làm nếu dư thời gian, ~3 phút)

```bash
# Tab 1
terraform apply -var instance_count=4

# Tab 2: 3 máy cũ "ok", chỉ web-4 "changed"
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

---

## Sau demo — Dọn dẹp (BẮT BUỘC, tránh mất tiền)

```bash
# Trả lại biến đã sửa ở Demo 3 và file vault bản trong repo (bỏ bản tạo trên sân khấu)
git checkout demo/ansible/roles/nginx/defaults/main.yml demo/ansible/roles/nginx/vars/vault.yml

# Xoá toàn bộ EC2, key pair, security group
cd demo/terraform/environments/demo
terraform destroy                    # nếu đã scale: terraform destroy -var instance_count=4
```

State lưu local ở `demo/terraform/environments/demo/terraform.tfstate` — không xoá file này trước khi `terraform destroy` xong.

---

## Xử lý sự cố nhanh

| Triệu chứng | Lệnh xử lý |
|---|---|
| `ping` báo `UNREACHABLE` (timeout) | IP mạng đổi → `curl -s ifconfig.me`, sửa `admin_cidrs` trong `terraform.tfvars`, `terraform apply` |
| Lỗi `Permission denied (publickey)` | `ls -l ~/Downloads/ansible-controller.pem` (quyền phải là `-r--------`), kiểm tra `ansible_ssh_private_key_file` trong `inventory-terraform` |
| Không có file `inventory-terraform` | `cd demo/terraform/environments/demo && terraform apply` |
| `ERROR! Attempting to decrypt but no vault secrets found` | Quên `--ask-vault-pass` (đúng như demo cố ý) — thêm cờ này vào |
| Gõ sai mật khẩu lúc tạo vault | `rm roles/nginx/vars/vault.yml` rồi `ansible-vault create` lại |
| Muốn xem chi tiết lỗi | thêm `-vvv` vào lệnh `ansible` / `ansible-playbook` |
| Mạng hỏng hoàn toàn | Chiếu video dự phòng |
