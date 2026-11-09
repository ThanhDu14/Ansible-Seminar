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
  # checkov:skip=CKV_AWS_88: "Demo has no Bastion; Ansible Control Node SSHes straight to the public IP (SSH restricted to admin_cidrs)"
  # checkov:skip=CKV_AWS_135: "EBS optimization enabled by default on t3 family"
  # checkov:skip=CKV_AWS_126: "Detailed monitoring (1-min) costs extra; not needed for a short-lived seminar demo"
  # checkov:skip=CKV_AWS_189: "Root volume encrypted with AWS-managed key; KMS CMK incurs unnecessary cost for demo"
  # checkov:skip=CKV2_AWS_41: "Web nodes do not call AWS APIs; no IAM role needed"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = var.security_group_ids
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

# Đợi SSH lên và cloud-init chạy xong (tránh lỗi apt bị khoá khi Ansible cài Nginx)
resource "terraform_data" "wait_cloud_init" {
  count = var.wait_for_cloud_init ? 1 : 0

  triggers_replace = [aws_instance.this.id]

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait > /dev/null"]

    connection {
      type        = "ssh"
      host        = aws_instance.this.public_ip
      user        = "ubuntu"
      private_key = file(pathexpand(var.ssh_private_key_path))
    }
  }
}
