output "instance_ids" {
  value = aws_instance.manager[*].id
}

output "private_ips" {
  value = aws_instance.manager[*].private_ip
}

output "master_instance_id" {
  value = aws_instance.manager[0].id
}

output "worker_instance_ids" {
  value = slice(aws_instance.manager[*].id, 1, length(aws_instance.manager))
}

output "iam_role_arn" {
  value = aws_iam_role.manager.arn
}
