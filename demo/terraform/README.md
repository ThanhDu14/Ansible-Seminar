# Demo: Terraform dựng máy, Ansible cấu hình

Terraform tạo N máy EC2 (mặc định 3) và tự sinh file `inventory`. Sau đó Ansible dùng
lại `site.yml` + role `nginx` ở thư mục `demo/` để cài Nginx lên tất cả các máy.

```
terraform apply  ->  N máy EC2 + IP  ->  terraform/inventory  ->  ansible-playbook  ->  N web Nginx
```

## Chuẩn bị (làm 1 lần)

1. AWS credentials: `aws configure` (hoặc biến môi trường `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).
2. SSH key (nếu chưa có): `ssh-keygen -t ed25519 -f ~/.ssh/ansible_lab`
3. Khai báo IP được phép SSH:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # sửa ssh_cidr thành "<IP của bạn>/32"  (xem IP: curl -s ifconfig.me)
   terraform init
   ```

## Chạy demo

```bash
cd demo/terraform
terraform apply                 # ~2-3 phút: tạo máy + đợi SSH và cloud-init xong
cat inventory                   # inventory do Terraform tự sinh

cd ..
ansible-playbook -i terraform/inventory site.yml --ask-vault-pass
```

Mở các URL trong `terraform output web_urls` để thấy trang Nginx.

Muốn thêm máy: `terraform apply -var instance_count=5`, rồi chạy lại playbook.
Máy cũ báo `ok`, chỉ máy mới báo `changed` (idempotent).

## Dọn dẹp (quan trọng, tránh mất tiền)

```bash
terraform destroy
```

## Lưu ý

- Không commit `terraform.tfvars`, `*.tfstate`, `inventory` (đã có trong `.gitignore`).
- Nên quay video dự phòng trước buổi seminar, phòng khi mạng lỗi.
