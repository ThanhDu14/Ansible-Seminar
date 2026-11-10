# environments/demo/main.tf
# Demo seminar: N máy web EC2 trong default VPC, Ansible cài Nginx lên sau.
# Dựng trước buổi demo, terraform destroy ngay sau khi xong.

# Default VPC của tài khoản (demo không cần VPC riêng)
data "aws_vpc" "default" {
  default = true
}

# 1. Security Group Module
module "security_group" {
  source = "../../modules/security-group"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = data.aws_vpc.default.id
}

# 2. SSM Role Module — IAM role + instance profile cho Session Manager (thay cho mở port 22)
module "ssm_role" {
  source = "../../modules/ssm-role"

  project_name = var.project_name
  environment  = var.environment
}

# 3. EC2 Module — web-1..web-N (Ansible vào qua SSM, đợi cloud-init xong)
module "web" {
  source   = "../../modules/ec2"
  for_each = toset([for i in range(var.instance_count) : "web-${i + 1}"])

  project_name         = var.project_name
  environment          = var.environment
  name                 = each.key
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_group_ids   = [module.security_group.sg_web_id]
  iam_instance_profile = module.ssm_role.instance_profile_name
  aws_region           = var.aws_region
  ssh_private_key_path = var.ssh_private_key_path
}
