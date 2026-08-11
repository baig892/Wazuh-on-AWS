output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "availability_zones" {
  value = local.azs
}

output "vpc_endpoints_sg_id" {
  value = try(aws_security_group.vpc_endpoints[0].id, null)
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}
