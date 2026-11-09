# Outputs for security-group module

output "sg_web_id" {
  description = "Security Group ID for web nodes"
  value       = aws_security_group.web.id
}
