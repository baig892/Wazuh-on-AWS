# Client VPN for secure admin access to the private Wazuh resources.
# No public SSH access is required.

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${var.name_prefix} admin access to Wazuh dashboard/management"
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  vpc_id                 = var.vpc_id
  split_tunnel           = true
  transport_protocol     = "udp"

  # Use client certificates for VPN authentication.
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.client_root_certificate_arn
  }

  # VPN connection logs - who connected, when, from where. Feeds the
  # CloudWatch log group created by the monitoring module.
  connection_log_options {
    enabled              = var.connection_log_group != null
    cloudwatch_log_group = var.connection_log_group
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-client-vpn"
  })
}

# Associate the VPN with private subnets in each AZ.
resource "aws_ec2_client_vpn_network_association" "this" {
  count                  = length(var.private_subnet_ids)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.private_subnet_ids[count.index]
}

# Allow VPN clients to access resources inside the VPC.
resource "aws_ec2_client_vpn_authorization_rule" "to_vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
}
