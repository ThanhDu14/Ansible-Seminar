# Ubuntu 22.04 moi nhat cua Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "ansible" {
  key_name   = "ansible-seminar"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_security_group" "web" {
  name        = "ansible-seminar-web"
  description = "SSH cho Ansible, HTTP cho Nginx"

  ingress {
    description = "SSH tu Control Node"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ansible.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name = "ansible-web-${count.index + 1}"
  }

  # Doi SSH len va cloud-init chay xong (tranh loi apt bi khoa khi Ansible cai Nginx)
  provisioner "remote-exec" {
    inline = ["cloud-init status --wait > /dev/null"]

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(pathexpand(var.private_key_path))
    }
  }
}

# Terraform tu sinh inventory cho Ansible -> khong ai ghi IP bang tay
resource "local_file" "inventory" {
  filename        = "${path.module}/inventory"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    ips              = aws_instance.web[*].public_ip
    private_key_path = var.private_key_path
  })
}
