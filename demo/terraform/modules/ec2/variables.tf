# Variables for ec2 module

variable "project_name" {
  type        = string
  description = "Project name prefix used for resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. demo)"
}

variable "name" {
  type        = string
  description = "Short name for this instance (e.g. web-1). Used in resource Name tag."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type (e.g. t3.micro)"
  default     = "t3.micro"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to launch the instance into (null = default subnet of the default VPC)"
  default     = null
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name; SSH goes through the SSM tunnel, not port 22"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of Security Group IDs to attach to the instance"
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name (with AmazonSSMManagedInstanceCore) so the instance can be reached via SSM"
}

variable "aws_region" {
  type        = string
  description = "AWS region, used by aws ssm start-session when waiting for cloud-init"
}

variable "associate_public_ip" {
  type        = bool
  description = "Whether to assign a public IP (default VPC has no NAT: needed for HTTP demo and SSM Agent outbound)"
  default     = true
}

variable "wait_for_cloud_init" {
  type        = bool
  description = "Wait (SSH over SSM) until cloud-init finishes, so Ansible can run apt right after apply"
  default     = true
}

variable "ssh_private_key_path" {
  type        = string
  description = "Local path to the private key of key_name (used only when wait_for_cloud_init = true)"
  default     = ""
}
