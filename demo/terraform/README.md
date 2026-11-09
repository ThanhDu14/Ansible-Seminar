# Demo: Terraform dựng máy, Ansible cấu hình

Terraform tạo N máy EC2 (mặc định 3) và tự sinh file `demo/ansible/inventory-terraform`.
Sau đó Ansible dùng lại `site.yml` + role `nginx` ở thư mục `demo/ansible/` để cài Nginx lên tất cả các máy.

```
terraform apply  ->  N máy EC2 + IP  ->  ansible/inventory-terraform  ->  ansible-playbook  ->  N web Nginx
```

## Cấu trúc

```
demo/terraform/
├── modules/
│   ├── security-group/        # sg-web: SSH từ admin_cidrs, HTTP từ Internet
│   └── ec2/                   # 1 máy Ubuntu 22.04 + đợi cloud-init xong
└── environments/
    └── demo/                  # providers.tf, main.tf (gọi module), inventory.tf, ...

demo/ansible/inventory-terraform   # do environments/demo/inventory.tf sinh ra (gitignore)
```

Mỗi module gồm `main.tf` / `variables.tf` / `outputs.tf`. `environments/demo/main.tf` chỉ
gọi module (đánh số 1, 2); `providers.tf` chứa block `terraform` + `provider`.
State lưu local trong `environments/demo/terraform.tfstate` (đã gitignore).

## Chuẩn bị (làm 1 lần)

1. AWS credentials: `aws configure` (hoặc biến môi trường `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).
2. SSH key: dùng Key Pair có sẵn trên AWS (mặc định `ansible-controller`, file `~/Downloads/ansible-controller.pem`).
   Key Pair phải cùng region với `aws_region`; file `.pem` cần quyền `chmod 400`.
3. Khai báo IP được phép SSH và init môi trường demo:
   ```bash
   cd demo/terraform/environments/demo
   cp terraform.tfvars.example terraform.tfvars
   # sửa admin_cidrs thành ["<IP của bạn>/32"]  (xem IP: curl -s ifconfig.me)
   terraform init
   ```

## Chạy demo

```bash
cd demo/terraform/environments/demo
terraform apply                 # ~2-3 phút: tạo máy + đợi SSH và cloud-init xong
cat ../../../ansible/inventory-terraform   # inventory do Terraform tự sinh

cd ../../../ansible             # về thư mục demo/ansible/
ansible-playbook -i inventory-terraform site.yml --ask-vault-pass
```

Mở các URL trong `terraform output web_urls` để thấy trang Nginx.

Muốn thêm máy: `terraform apply -var instance_count=5`, rồi chạy lại playbook.
Máy cũ báo `ok`, chỉ máy mới báo `changed` (idempotent).

## Dọn dẹp (quan trọng, tránh mất tiền)

```bash
cd demo/terraform/environments/demo
terraform destroy
```

Không xoá file `terraform.tfstate` khi máy còn đang chạy — mất file này Terraform sẽ không biết máy nào để destroy.

## Lưu ý

- Không commit `*.tfvars`, `*.tfstate`, `ansible/inventory-terraform` (đã có trong `.gitignore`).
- Nên quay video dự phòng trước buổi seminar, phòng khi mạng lỗi.
