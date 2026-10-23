variable "region" {
  description = "Region AWS (Singapore giong lab hien tai)"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_count" {
  description = "So may web can tao"
  type        = number
  default     = 3
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "public_key_path" {
  description = "Public key day len EC2 (tao bang ssh-keygen -t ed25519 -f ~/.ssh/ansible_lab)"
  type        = string
  default     = "~/.ssh/ansible_lab.pub"
}

variable "private_key_path" {
  description = "Private key tuong ung, dung cho Terraform cho SSH san sang va cho Ansible"
  type        = string
  default     = "~/.ssh/ansible_lab"
}

variable "ssh_cidr" {
  description = "IP duoc phep SSH vao, vd 1.2.3.4/32 (xem bang: curl -s ifconfig.me)"
  type        = string
}
