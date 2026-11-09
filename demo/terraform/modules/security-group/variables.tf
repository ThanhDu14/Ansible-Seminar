# Variables for security-group module

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where Security Groups are created"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "List of admin CIDRs (Ansible Control Node) allowed to SSH into web nodes"
}
