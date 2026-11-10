# Outputs for ssm-role module

output "instance_profile_name" {
  description = "IAM instance profile name to attach to EC2 instances"
  value       = time_sleep.iam_propagation.triggers["instance_profile"]
}
