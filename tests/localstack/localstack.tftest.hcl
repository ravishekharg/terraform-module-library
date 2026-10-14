# Integration test: real apply and destroy against LocalStack (community edition).
#   docker run -d -p 4566:4566 localstack/localstack:4.4
#   cd tests/localstack && terraform init && terraform test
# The provider (pointed at LocalStack) is configured in providers.tf of both configurations.

run "apply" {
  command = apply

  assert {
    condition     = length(output.private_subnet_ids) == 2 && length(output.database_subnet_ids) == 2
    error_message = "two AZs: two private and two database subnets"
  }
}

run "verify" {
  command = apply # read-only data sources; nothing is created
  module {
    source = "./verify"
  }
  variables {
    name               = "itest"
    vpc_id             = run.apply.vpc_id
    private_subnet_ids = run.apply.private_subnet_ids
    app_sg_id          = run.apply.app_sg_id
    bucket             = run.apply.bucket
  }

  assert {
    condition     = output.database_subnet_count == 2
    error_message = "the database tier exists, tagged tier=database"
  }
  assert {
    condition     = length([for r in output.database_routes : r if r.cidr_block == "0.0.0.0/0"]) == 0
    error_message = "the database route table must have no default route"
  }
  assert {
    condition     = output.private_default_routes_via_nat == [1, 1]
    error_message = "each private route table sends 0.0.0.0/0 to the NAT gateway"
  }
  assert {
    condition     = [for s in output.app_ingress_sources : reverse(split("/", s))[0]] == [run.apply.lb_sg_id] # referenced groups may read back as "account/sg-id"
    error_message = "the app group admits traffic only from the load balancer group"
  }
  assert {
    condition     = output.bucket_policy.Statement[0].Condition.Bool["aws:SecureTransport"] == "false" && output.bucket_policy.Statement[0].Effect == "Deny"
    error_message = "the bucket policy denies non-TLS requests"
  }
}
