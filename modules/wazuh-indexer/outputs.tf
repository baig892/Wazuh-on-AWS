output "instance_ids" {
  value = aws_instance.indexer[*].id
}

output "private_ips" {
  value = aws_instance.indexer[*].private_ip
}
