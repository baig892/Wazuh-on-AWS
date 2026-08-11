output "instance_ids" {
  value = aws_instance.dashboard[*].id
}

output "private_ips" {
  value = aws_instance.dashboard[*].private_ip
}
