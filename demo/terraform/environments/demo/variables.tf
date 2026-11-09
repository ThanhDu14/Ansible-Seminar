# Variables for demo environment

variable "aws_region" {
  type        = string
  description = "AWS region for provisioning demo resources"
  default     = "ap-southeast-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix used for all resource names"
  default     = "ansible-seminar"
}

variable "environment" {
  type        = string
  description = "Environment label applied to tags"
  default     = "demo"
}

variable "instance_count" {
  type        = number
  description = "Number of web nodes to create"
  default     = 3

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count phải từ 1 đến 10 (demo seminar, tránh tốn tiền)."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for web nodes"
  default     = "t3.micro"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to SSH into web nodes — the Ansible Control Node (xem IP: curl -s ifconfig.me)"

  validation {
    condition     = length(var.admin_cidrs) >= 1
    error_message = "admin_cidrs phải có ít nhất 1 CIDR."
  }

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Mỗi phần tử admin_cidrs phải là CIDR hợp lệ (vd 1.2.3.4/32) và không được là 0.0.0.0/0."
  }
}

variable "key_name" {
  type        = string
  description = "Tên EC2 Key Pair đã có sẵn trên AWS (cùng region), tải .pem khi tạo trên Console"
  default     = "ansible-controller"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Đường dẫn file .pem của key_name; dùng để đợi cloud-init và ghi vào Ansible inventory"
  default     = "~/Downloads/ansible-controller.pem"
}
