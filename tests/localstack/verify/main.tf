# Reads back what the apply created, through the AWS API (LocalStack), so the assertions check the
# real resources and not just Terraform's view of them.
variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_sg_id" { type = string }
variable "bucket" { type = string }

data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = { tier = "database" }
}

data "aws_route_table" "database" {
  vpc_id = var.vpc_id
  tags   = { Name = "${var.name}-database" }
}

data "aws_route_table" "private" {
  count     = length(var.private_subnet_ids)
  subnet_id = var.private_subnet_ids[count.index]
}

data "aws_vpc_security_group_rules" "app" {
  filter {
    name   = "group-id"
    values = [var.app_sg_id]
  }
}

data "aws_vpc_security_group_rule" "app" {
  for_each               = toset(data.aws_vpc_security_group_rules.app.ids)
  security_group_rule_id = each.value
}

data "aws_s3_bucket_policy" "this" {
  bucket = var.bucket
}

output "database_subnet_count" {
  value = length(data.aws_subnets.database.ids)
}

output "database_routes" {
  value = data.aws_route_table.database.routes
}

output "private_default_routes_via_nat" {
  value = [for rt in data.aws_route_table.private : length([for r in rt.routes : r if r.cidr_block == "0.0.0.0/0" && r.nat_gateway_id != ""])]
}

output "app_ingress_sources" {
  value = [for r in data.aws_vpc_security_group_rule.app : r.referenced_security_group_id if !r.is_egress]
}

output "bucket_policy" {
  value = jsondecode(data.aws_s3_bucket_policy.this.policy)
}
