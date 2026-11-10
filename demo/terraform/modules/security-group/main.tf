# Security Group: sg-web (chỉ HTTP cho Nginx — KHÔNG mở port 22, Ansible vào qua SSM)

# ----- sg-web -----
resource "aws_security_group" "web" {
  # checkov:skip=CKV2_AWS_5: "Attached to web instances in environments/demo via module output sg_web_id"
  name_prefix = "${var.project_name}-${var.environment}-sg-web-"
  description = "Security group for web nodes: HTTP from Internet, no SSH (access via SSM)"
  vpc_id      = var.vpc_id

  # Đổi description/name buộc thay SG: tạo SG mới, gắn vào máy, rồi mới xoá SG cũ
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg-web"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
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
  description       = "Allow HTTPS out for apt and SSM Agent"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}
