# The example wires every module together: this plan (AWS mocked) proves the wiring and the
# per-environment choices without an account.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"] }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
}

run "dev" {
  command = plan

  assert {
    condition     = length(module.vpc.private_subnet_ids) == 3 && length(module.vpc.database_subnet_ids) == 3
    error_message = "3 AZs of private and database subnets"
  }
  assert {
    condition     = length(module.vpc.nat_public_ips) == 1
    error_message = "dev: a single NAT gateway"
  }
}

run "prod_differs_only_where_intended" {
  command = plan
  variables {
    env = "prod"
  }

  assert {
    condition     = length(module.vpc.nat_public_ips) == 3
    error_message = "prod: one NAT gateway per AZ"
  }
}
