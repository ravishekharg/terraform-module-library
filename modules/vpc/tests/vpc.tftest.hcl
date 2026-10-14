# Offline: the AWS provider is mocked, so these runs plan without credentials or an account.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-west-1a", "eu-west-1b", "eu-west-1c", "eu-west-1d"] }
  }
}

variables {
  name = "test"
  cidr = "10.20.0.0/16"
}

run "three_tiers_across_three_azs" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.private) == 3 && length(aws_subnet.database) == 3
    error_message = "expected 3 public, 3 private and 3 database subnets"
  }
  assert {
    condition     = [for s in aws_subnet.public : s.cidr_block] == ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"] && [for s in aws_subnet.private : s.cidr_block] == ["10.20.64.0/20", "10.20.80.0/20", "10.20.96.0/20"] && [for s in aws_subnet.database : s.cidr_block] == ["10.20.128.0/20", "10.20.144.0/20", "10.20.160.0/20"]
    error_message = "subnet plan changed: public 0-3, private 4-7, database 8-11"
  }
  assert {
    condition     = [for s in aws_subnet.private : s.availability_zone] == ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    error_message = "subnets must spread over the first three AZs"
  }
  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "public subnets must not hand out public IPs"
  }
}

run "nat_per_az_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 3 && length(aws_route.private_nat) == 3
    error_message = "per_az: one NAT gateway and one default route per AZ"
  }
}

run "single_nat" {
  command = plan
  variables {
    nat_gateway_mode = "single"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_route.private_nat) == 3
    error_message = "single: one NAT gateway, every private route table points at it"
  }
}

run "no_nat_means_no_egress" {
  command = plan
  variables {
    nat_gateway_mode = "none"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_route.private_nat) == 0 && length(aws_eip.nat) == 0
    error_message = "none: no NAT gateways, no EIPs, no default route from private subnets"
  }
}

run "database_tier_is_isolated" {
  command = plan

  assert {
    condition     = length(aws_route_table.database) == 1 && length(aws_route_table_association.database) == 3
    error_message = "database subnets share one route table"
  }
  # "no route besides local" is only known after apply: checked in tests/localstack
}

run "explicit_azs" {
  command = plan
  variables {
    azs = ["eu-west-1b", "eu-west-1d"]
  }

  assert {
    condition     = [for s in aws_subnet.private : s.availability_zone] == ["eu-west-1b", "eu-west-1d"]
    error_message = "explicit azs must be used as given"
  }
}

run "flow_logs_on_by_default" {
  command = plan

  assert {
    condition     = length(aws_flow_log.this) == 1 && aws_flow_log.this[0].traffic_type == "ALL" && aws_cloudwatch_log_group.flow[0].retention_in_days == 365
    error_message = "flow logs: all traffic, one year retention"
  }
}

run "rejects_one_az" {
  command = plan
  variables {
    az_count = 1
  }
  expect_failures = [var.az_count]
}

run "rejects_bad_cidr" {
  command = plan
  variables {
    cidr = "10.20.0.0/8"
  }
  expect_failures = [var.cidr]
}

run "rejects_subnets_too_small" {
  command = plan
  variables {
    cidr           = "10.20.0.0/24"
    subnet_newbits = 6
  }
  expect_failures = [var.subnet_newbits]
}
