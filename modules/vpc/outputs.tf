output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability Zones used, in subnet order."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs, one per AZ."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per AZ."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Database subnet IDs, one per AZ (empty when create_database_subnets is false)."
  value       = aws_subnet.database[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs, one per AZ (for gateway endpoints)."
  value       = aws_route_table.private[*].id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways (for partners that allow-list your egress)."
  value       = aws_eip.nat[*].public_ip
}
