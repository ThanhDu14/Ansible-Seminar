# Outputs for ec2 module

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance (empty if associate_public_ip = false)"
  value       = aws_instance.this.public_ip

  # Chỉ trả IP khi cloud-init đã xong → inventory sinh ra là dùng được ngay
  depends_on = [terraform_data.wait_cloud_init]
}
