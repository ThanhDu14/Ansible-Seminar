# IAM role + instance profile cho EC2 dùng AWS Systems Manager (Session Manager)
# → vào máy qua SSM, không cần mở port 22 / không cần admin_cidrs.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.project_name}-${var.environment}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssm-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Policy AWS quản lý: cho SSM Agent đăng ký và nhận session
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-${var.environment}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# IAM eventual consistency: instance profile vừa tạo cần ~10-30s mới dùng được.
# Nếu EC2 boot ngay, SSM Agent xin credentials bị từ chối rồi backoff vài phút.
# → đợi 30s rồi mới trả output, EC2 (phụ thuộc output này) sẽ được tạo sau.
resource "time_sleep" "iam_propagation" {
  create_duration = "30s"

  triggers = {
    instance_profile = aws_iam_instance_profile.ssm.name
  }

  depends_on = [aws_iam_role_policy_attachment.ssm_core]
}
