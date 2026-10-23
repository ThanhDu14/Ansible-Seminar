output "web_ips" {
  value = aws_instance.web[*].public_ip
}

output "web_urls" {
  value = [for ip in aws_instance.web[*].public_ip : "http://${ip}"]
}
