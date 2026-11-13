# Lệnh demo — Terraform dựng hạ tầng → tạo máy → Ansible cấu hình

> Mọi lệnh chạy từ thư mục gốc repo `Ansible-Seminar/` (trừ khi có `cd`).
> Host trong inventory do Terraform sinh có tên `web-1`, `web-2`, `web-3`.
> Ansible vào máy **qua AWS SSM** (không mở port 22, không cần khai báo IP).

## Tổng quan flow (~18 phút)

| Phần | Nội dung | Thời gian |
|---|---|---|
| **A** | Terraform — khái niệm nhanh, đọc code hạ tầng, `plan`, apply **mạng + quyền** (SG, IAM role SSM) | ~4 phút |
| **B** | Terraform — **tạo máy** EC2 + inventory tự sinh | ~4 phút (apply chạy nền, vừa đợi vừa nói) |
| **C** | Ansible — ping → Vault + deploy Nginx → idempotent/handler → shell vs `lineinfile` | ~10 phút |
| — | Dọn dẹp `terraform destroy` | sau buổi |

Mạch kể: *"có mạng & quyền" → "có máy" → "máy chạy đúng"*.

---

## 0. Chuẩn bị (làm 1 lần, trước ngày seminar)

```bash
# AWS credentials
aws configure
aws sts get-caller-identity          # kiểm tra đúng tài khoản

# Session Manager plugin (bắt buộc: SSH đi qua tunnel SSM)
session-manager-plugin --version     # chưa có → xem demo/terraform/README.md

# Key Pair có sẵn trên AWS + file .pem (xác thực SSH bên trong tunnel SSM)
aws ec2 describe-key-pairs --key-names ansible-controller --region ap-southeast-1
chmod 400 ~/Downloads/ansible-controller.pem

# Init môi trường demo
cd demo/terraform/environments/demo
cp terraform.tfvars.example terraform.tfvars
terraform init
```

**Tổng duyệt 1 lần trọn flow** (A → B → C → destroy) và **quay video dự phòng**.

---

## 1. Trước giờ demo (~10 phút trước, KHÔNG làm trên sân khấu)

```bash
cd demo/terraform/environments/demo
terraform state list                 # phải RỖNG (đã destroy sau lần tổng duyệt)
terraform plan | tail -1             # "Plan: 15 to add" → credentials + provider OK

# Xoá vault cũ để tạo lại trực tiếp trên sân khấu (Phần C)
cd ../../../ansible
rm -f group_vars/webservers/vault.yml .vault_pass
export EDITOR=nano                   # ansible-vault create mở nano thay vì vi
```

Mở sẵn 3 tab terminal:

| Tab | Thư mục |
|---|---|
| 1 — Terraform | `demo/terraform/environments/demo` |
| 2 — Ansible | `demo/ansible` |
| 3 — Kiểm tra | `demo/ansible` (dùng cho `curl` / `cat`) |

> **Phương án B (mạng yếu / thiếu giờ):** chạy sẵn `terraform apply` trước giờ demo.
> Trên sân khấu Phần A/B chỉ *đọc code* + `terraform state list` + `terraform output`, bỏ các lệnh apply.

---

## Phần A — Terraform: hạ tầng mạng & quyền (~4 phút)

**Tab 1** (`demo/terraform/environments/demo`).

### A0. Terraform là gì? (~1 phút, nói trước khi gõ lệnh)

> Nói: "Terraform là công cụ **Infrastructure as Code**: thay vì bấm tạo máy trên AWS Console,
> mình **viết file mô tả hạ tầng mong muốn** (máy, mạng, quyền), Terraform tự gọi API của AWS để tạo cho đúng.
> Cũng **khai báo** giống Ansible, nhưng khác phạm vi: Terraform lo *có cái gì* trên cloud, Ansible lo *bên trong máy chạy gì*."

Vài khái niệm sẽ gặp ngay trong demo (mỗi khái niệm gắn với 1 file/lệnh để chỉ vào):

| Khái niệm | Hiểu nhanh | Chỉ vào đâu trong demo |
|---|---|---|
| **Provider** | "Driver" để Terraform nói chuyện với 1 nền tảng (AWS, GCP, …) | `providers.tf` — `provider "aws"`, region |
| **Resource** | 1 thứ cần tạo: máy EC2, security group, IAM role | `resource "aws_instance"`, `resource "aws_security_group"` |
| **Data source** | *Đọc* thứ có sẵn, không tạo mới | `data "aws_vpc" "default"`, `data "aws_ami" "ubuntu"` |
| **Variable / Output** | Tham số đầu vào / giá trị trả ra sau khi tạo | `variables.tf` (`instance_count = 3`), `terraform output` |
| **Module** | Gói nhiều resource thành 1 khối dùng lại, giống **role** của Ansible | `modules/ec2`, `modules/security-group` |
| **State** | File Terraform ghi nhớ "mình đã tạo những gì, ID là gì" | `terraform.tfstate`, `terraform state list` |
| **plan / apply / destroy** | Xem trước thay đổi / thực hiện / xoá sạch | Giống `--check --diff` rồi chạy thật của Ansible |

> Nói: "Vòng đời chỉ có 3 bước: **viết code → `plan` xem trước → `apply` làm thật**. Xong việc thì `destroy`."

### A1. Cấu trúc code: module + environment

```bash
tree ../..  -I '.terraform'          # hoặc: find ../.. -name '*.tf' | sort
cat providers.tf                     # [Provider] dùng AWS, region ap-southeast-1
cat main.tf                          # [Data source] đọc default VPC; [Module] gọi 3 khối: security_group, ssm_role, web
```

> Nói: "Code chia 2 tầng: `modules/` là các khối dùng lại được — giống role bên Ansible —
> còn `environments/demo` chỉ ghép module lại và truyền biến vào.
> Thêm môi trường `staging` thì chỉ cần một thư mục mới gọi lại các module này."

### A2. Hai khối hạ tầng nền

```bash
cat ../../modules/security-group/main.tf   # [Resource] chỉ inbound 80; outbound 80/443 cho apt + SSM — KHÔNG có port 22
cat ../../modules/ssm-role/main.tf         # [Resource] IAM role + instance profile AmazonSSMManagedInstanceCore
```

> Nói: "**Security group** là tường lửa của máy trên AWS: chỉ cho vào cổng 80, không mở cổng SSH 22.
> **IAM role** là 'giấy phép' gắn cho máy: ở đây cho phép SSM Agent trong máy tự kết nối ra AWS qua 443.
> Nhờ vậy lát nữa Ansible vẫn SSH được qua đường hầm SSM mà không cần mở port 22."

### A3. Plan rồi apply riêng phần hạ tầng

```bash
terraform plan                       # "Plan: 15 to add" — toàn bộ: hạ tầng + 3 máy + inventory
```

> Nói: "`plan` so sánh **code** với **state** (hiện đang rỗng) → còn thiếu 15 thứ, dấu `+` là sẽ tạo mới.
> Chưa có gì bị tạo, giống `--check` bên Ansible."

```bash
# Chỉ dựng mạng & quyền trước (~40 giây, gồm 30s đợi IAM lan truyền)
terraform apply -target=module.security_group -target=module.ssm_role    # gõ yes
# → "8 added". Cảnh báo "Resource targeting is in effect" là bình thường (cố ý apply từng phần)

terraform state list                 # 8 resource: SG + 3 rule, IAM role/attachment/profile, time_sleep
```

> Nói: "Terraform lưu **state** — nó biết chính xác mình đã tạo gì. Lần `plan` sau nó chỉ tính phần còn thiếu.
> Đây là thứ Ansible không có, và là lý do việc tạo/xoá hạ tầng giao cho Terraform."

---

## Phần B — Terraform: tạo máy (~4 phút)

### B1. Code module EC2

```bash
sed -n '/resource "aws_instance"/,/^}/p' ../../modules/ec2/main.tf   # AMI Ubuntu 22.04, gắn SG + instance profile
cat inventory.tf                                                     # template sinh inventory cho Ansible
ls ../../../ansible/inventory-terraform                              # "No such file" — chưa có máy thì chưa có inventory
```

### B2. Apply phần còn lại

```bash
terraform plan | tail -1             # "Plan: 7 to add" — hạ tầng nền đã có, chỉ còn 3 máy + 3 bước đợi + inventory
```

> Nói: "Lần này `plan` chỉ còn 7 vì state đã ghi nhận 8 resource hạ tầng — Terraform không tạo lại cái đã có."

```bash
terraform apply                      # gõ yes, ~3 phút
```

> Nói: "Terraform tự hiểu **thứ tự phụ thuộc**: máy EC2 tham chiếu tới security group và IAM role,
> nên nó luôn tạo 2 thứ đó trước rồi mới tạo máy. 3 máy không phụ thuộc nhau nên được tạo **song song**."

Trong lúc đợi (~3 phút), nói:

> "Mỗi máy có 1 bước `wait_cloud_init`: Terraform SSH qua SSM vào máy, đợi cloud-init xong,
> để lát nữa Ansible chạy `apt` không bị khoá. Bạn sẽ thấy dòng *'Đợi SSM Agent ... online'* lặp lại vài lần — đó là máy đang boot.
> Khi xong, `local_file` ghi ra inventory: dùng **instance ID** làm `ansible_host`, SSH đi qua `ProxyCommand aws ssm start-session`."

### B3. Kết quả

```bash
terraform output                     # web_instance_ids, web_public_ips, web_urls
cat ../../../ansible/inventory-terraform    # inventory Terraform tự sinh, không ai gõ IP bằng tay
```

> Nói: "Terraform xong việc: **có máy**. Từ đây Ansible lo **máy chạy đúng**."

Mở thử 1 URL trong `web_urls` → chưa có gì (chưa cài Nginx) — để lát so sánh.

---

## Phần C — Ansible cấu hình

### C1. Kiểm tra kết nối (~1 phút)

**Tab 2** (`demo/ansible`):

```bash
# "pong" = SSH (qua SSM) + Python OK, không cài agent
ansible webservers -i inventory-terraform -m ping

# Cấu trúc: role + group_vars (lúc này chưa có group_vars/webservers/vault.yml)
tree roles/nginx group_vars          # hoặc: find roles/nginx group_vars -type f
cat group_vars/webservers/vars.yml   # admin_password: "{{ vault_admin_password }}"
```

### C2. Tạo Vault → chạy playbook Nginx → curl (~4 phút)

**Tab 2** — tạo secret bằng Vault:

```bash
# Nhập mật khẩu Vault 2 lần, nano mở ra → gõ nội dung bên dưới, Ctrl+O, Enter, Ctrl+X
ansible-vault create group_vars/webservers/vault.yml
```

Nội dung gõ trong nano:

```yaml
vault_admin_password: "admin"
```

```bash
# File nằm trong repo nhưng chỉ thấy $ANSIBLE_VAULT;1.1;AES256 + chuỗi mã hoá
cat group_vars/webservers/vault.yml

# Chạy KHÔNG có mật khẩu → lỗi ngay đầu play khi nạp group_vars, CHƯA đụng tới server
ansible-playbook -i inventory-terraform site.yml

# Chạy có mật khẩu → deploy lần 1: nhiều task "changed", handler Restart Nginx chạy
# Task htpasswd hiện "censored" nhờ no_log → mật khẩu không lộ ra output
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

**Tab 3** — curl thử (IP lấy từ `terraform output web_public_ips`):

```bash
curl http://<IP-web-1>                                     # trang chào mừng (công khai)
curl -i http://<IP-web-1>/admin/                           # 401 Unauthorized
curl -u admin:<mật-khẩu-admin> http://<IP-web-1>/admin/    # 200 — vào được

# Trên server chỉ có HASH, không có mật khẩu gốc
ansible web-1 -i inventory-terraform -b -a "cat /etc/nginx/.htpasswd"
```

Refresh URL đã mở ở B3 → giờ đã có trang Nginx (thử `/admin/` → trình duyệt hỏi mật khẩu).

> Nói: "Secret được mã hoá ngay khi tạo, commit lên Git vẫn an toàn. Chỉ lúc chạy trên máy control mới giải mã, và xuống server chỉ còn hash."

### C3. Idempotent & Handler (~2 phút)

**Tab 2**:

```bash
# Chạy lại y hệt: toàn "ok", PLAY RECAP changed=0, handler KHÔNG chạy vì config không đổi
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

Đổi biến `server_name` (KHÔNG đổi `http_port` — security group chỉ mở cổng 80):

```bash
sed -i 's/demo.ansible.lab/seminar.ansible.lab/' roles/nginx/defaults/main.yml
cat roles/nginx/defaults/main.yml

# Xem trước thay đổi, chưa áp dụng
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass --check --diff

# Chạy thật: chỉ task template + /etc/hosts "changed", handler restart đúng 1 lần mỗi máy
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

**Tab 3** — xác nhận config trên máy đã đổi:

```bash
ansible webservers -i inventory-terraform -a "grep server_name /etc/nginx/sites-available/default"

# /etc/hosts: dòng cũ được SỬA thành tên mới (không thêm dòng trùng)
ansible webservers -i inventory-terraform -a "grep 'managed by ansible' /etc/hosts"
ansible webservers -i inventory-terraform -a "curl -s -o /dev/null -w '%{http_code}' http://seminar.ansible.lab"
```

### C4. Shell vs `lineinfile` (~1,5 phút)

Playbook riêng `idempotency-demo.yml` (không cần vault): 1 task `shell` append, 1 task `lineinfile`.

**Tab 2** — chạy 3 lần liên tiếp:

```bash
# Lần nào task [NON-IDEMPOTENT] cũng "changed"; task [IDEMPOTENT] chỉ "changed" ở lần 1
for i in 1 2 3; do ansible-playbook -i inventory-terraform idempotency-demo.yml; done
```

**Tab 3**:

```bash
ansible web-1 -i inventory-terraform -a "cat /tmp/idempotency_demo.txt"        # shell: 3 dòng trùng
ansible web-1 -i inventory-terraform -a "cat /tmp/idempotency_demo_fixed.txt"  # lineinfile: 1 dòng
ansible webservers -i inventory-terraform -a "wc -l /tmp/idempotency_demo.txt /tmp/idempotency_demo_fixed.txt"
```

> Nói: "Đây là khác biệt giữa 'chạy lệnh' và 'khai báo trạng thái'."

### Demo phụ — Scale thêm máy (chỉ khi dư thời gian, ~4 phút)

Nối lại 2 công cụ: Terraform thêm máy, Ansible chỉ cấu hình máy mới.

```bash
# Tab 1
terraform apply -var instance_count=4      # "1 máy mới + inventory đổi", hạ tầng nền giữ nguyên

# Tab 2: 3 máy cũ "ok", chỉ web-4 "changed"
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

---

## Sau demo — Dọn dẹp (BẮT BUỘC, tránh mất tiền)

```bash
# Trả lại biến đã sửa ở C3 và file vault bản trong repo (bỏ bản tạo trên sân khấu)
git checkout demo/ansible/roles/nginx/defaults/main.yml demo/ansible/group_vars/webservers/vault.yml

# Xoá toàn bộ EC2, security group, IAM role
cd demo/terraform/environments/demo
terraform destroy                    # nếu đã scale: terraform destroy -var instance_count=4
terraform state list                 # rỗng = sạch
```

State lưu local ở `demo/terraform/environments/demo/terraform.tfstate` — không xoá file này trước khi `terraform destroy` xong.

---

## Xử lý sự cố nhanh

| Triệu chứng | Lệnh xử lý |
|---|---|
| `apply` lặp "Đợi SSM Agent ... online" quá 30 lần | IAM chưa lan truyền → đợi 1-2 phút rồi `terraform apply` lại (máy đã tạo sẽ giữ nguyên) |
| `SessionManagerPlugin is not found` | Cài session-manager-plugin (xem `demo/terraform/README.md`) |
| `ping` báo `UNREACHABLE` | `aws ssm describe-instance-information --region ap-southeast-1` xem máy đã `Online` chưa; kiểm tra `aws sts get-caller-identity` |
| Lỗi `Permission denied (publickey)` | `ls -l ~/Downloads/ansible-controller.pem` (quyền `-r--------`), kiểm tra `ansible_ssh_private_key_file` trong `inventory-terraform` |
| Không có file `inventory-terraform` | Mới apply bằng `-target` → chạy `terraform apply` (không `-target`) |
| `ERROR! Attempting to decrypt but no vault secrets found` | Quên `--ask-vault-pass` (đúng như demo cố ý) — thêm cờ này |
| Gõ sai mật khẩu lúc tạo vault | `rm group_vars/webservers/vault.yml` rồi `ansible-vault create` lại |
| Muốn xem chi tiết lỗi | thêm `-vvv` vào lệnh `ansible` / `ansible-playbook` |
| Mạng hỏng hoàn toàn | Chiếu video dự phòng |
