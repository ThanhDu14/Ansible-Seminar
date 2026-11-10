# EC2 instance (Ubuntu 22.04) + tuỳ chọn đợi cloud-init xong trước khi Ansible chạy

# Data source: Ubuntu 22.04 LTS AMI (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# EC2 instance
resource "aws_instance" "this" {
  # checkov:skip=CKV_AWS_88: "Default VPC has no NAT; public IP is needed for HTTP demo and for SSM Agent to reach AWS endpoints (no port 22 open)"
  # checkov:skip=CKV_AWS_135: "EBS optimization enabled by default on t3 family"
  # checkov:skip=CKV_AWS_126: "Detailed monitoring (1-min) costs extra; not needed for a short-lived seminar demo"
  # checkov:skip=CKV_AWS_189: "Root volume encrypted with AWS-managed key; KMS CMK incurs unnecessary cost for demo"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.iam_instance_profile # SSM Agent (có sẵn trên AMI Ubuntu) dùng role này
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-${var.name}-root"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.name}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # AMI lấy theo most_recent: không thay máy mỗi khi Canonical ra AMI mới.
  # Muốn lên AMI mới thì chủ động: terraform apply -replace='module.web["<tên>"].aws_instance.this'
  lifecycle {
    ignore_changes = [ami]
  }
}

# Đợi SSM Agent online rồi đợi cloud-init chạy xong (tránh lỗi apt bị khoá khi Ansible cài Nginx).
# Không SSH thẳng vào public IP: SSH đi qua tunnel SSM (AWS-StartSSHSession), port 22 vẫn đóng.
# Cần trên máy chạy Terraform: AWS CLI v2 + session-manager-plugin.
resource "terraform_data" "wait_cloud_init" {
  count = var.wait_for_cloud_init ? 1 : 0

  triggers_replace = [aws_instance.this.id]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      SSH="ssh -i ${pathexpand(var.ssh_private_key_path)} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 \
        -o ProxyCommand='aws ssm start-session --region ${var.aws_region} --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p'"
      for i in $(seq 1 30); do
        if eval "$SSH ubuntu@${aws_instance.this.id} true" 2>/dev/null; then break; fi
        echo "Đợi SSM Agent của ${aws_instance.this.id} online... ($i/30)"; sleep 10
      done
      eval "$SSH ubuntu@${aws_instance.this.id} 'cloud-init status --wait > /dev/null'"
    EOT
  }
}
