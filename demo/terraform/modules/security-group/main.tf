# Security Group: sg-web (SSH từ Control Node cho Ansible, HTTP cho Nginx)

# ----- sg-web -----
resource "aws_security_group" "web" {
  # checkov:skip=CKV2_AWS_5: "Attached to web instances in environments/demo via module output sg_web_id"
  name        = "${var.project_name}-${var.environment}-sg-web"
  description = "Security group for web nodes: SSH from admin IPs, HTTP from Internet"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg-web"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_in_ssh" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "Allow SSH from Ansible Control Node"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "web_in_http" {
  # checkov:skip=CKV_AWS_260: "Public web demo; Nginx must accept HTTP from Internet"
  security_group_id = aws_security_group.web.id
  description       = "Allow HTTP from Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "web_out_http" {
  security_group_id = aws_security_group.web.id
  description       = "Allow HTTP out for apt"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "web_out_https" {
  security_group_id = aws_security_group.web.id
  description       = "Allow HTTPS out for apt"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}
